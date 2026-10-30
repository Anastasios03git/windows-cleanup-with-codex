function Invoke-CodexAppServer {
    param([string]$Codex,[string]$Repo,[string]$Prompt,[string]$Bridge,[string]$Report,[switch]$HandshakeOnly)
    New-Item -ItemType Directory -Path $Bridge -ErrorAction Stop | Out-Null
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$Codex
    if([IO.Path]::GetExtension($Codex) -eq '.ps1'){
        $start.FileName=Join-Path $PSHOME 'pwsh.exe'
        foreach($a in @('-NoProfile','-File',$Codex)){$start.ArgumentList.Add($a)}
    }
    foreach($a in @('app-server','--stdio')){$start.ArgumentList.Add($a)}
    $start.WorkingDirectory=$Repo
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $start.RedirectStandardInput=$true; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
    $start.StandardInputEncoding=[Text.UTF8Encoding]::new($false)
    $start.StandardOutputEncoding=[Text.UTF8Encoding]::new($false)
    $start.StandardErrorEncoding=[Text.UTF8Encoding]::new($false)
    $process=[Diagnostics.Process]::new(); $process.StartInfo=$start
    $stderr=[IO.File]::Open((Join-Path $Bridge 'server-errors.log'),'CreateNew','Write','Read')
    $pending=@{}; $items=@{}; $thread=$null; $turn=$null; $final=''; $complete=$false
    $activeCommands=@{};$interruptSent=$false;$deferredLogged=$false;$pathErrors=0;$turnActive=$false
    function Send-Wire($value){$process.StandardInput.WriteLine(($value | ConvertTo-Json -Depth 60 -Compress));$process.StandardInput.Flush()}
    function Log-Live([string]$text){Add-Content -LiteralPath (Join-Path $Bridge 'live.log') -Value $text -Encoding utf8}
    try {
        if(-not $process.Start()){throw 'Could not start Codex App Server.'}
        $drain=$process.StandardError.BaseStream.CopyToAsync($stderr)
        Send-Wire @{id=1;method='initialize';params=@{clientInfo=@{name='windows_cleanup';title='Windows Cleanup';version='0.3.0'};capabilities=@{experimentalApi=$true}}}
        $read=$process.StandardOutput.ReadLineAsync()
        $clock=[Diagnostics.Stopwatch]::StartNew()
        while(-not $complete){
            if(-not $thread -and $clock.Elapsed.TotalSeconds -gt 60){throw 'Codex initialization timed out.'}
            $stopRequested=Test-Path -LiteralPath ($Bridge+'.stop.request')
            if($stopRequested -and -not $interruptSent -and $turnActive -and $thread -and $turn){
                $servicing=@($activeCommands.Values | Where-Object { $_ -match '(?i)\bdism(?:\.exe)?["'']?\s+/(?:Online|Image|Cleanup-Image)|/StartComponentCleanup\b|\bRepair-WindowsImage\b|\bsfc(?:\.exe)?\s+/' })
                if($servicing.Count){
                    if(-not $deferredLogged){Log-Live 'Stop requested. Waiting for the current Windows servicing command to finish; it will not be forcibly terminated.';$deferredLogged=$true}
                }else{
                    Send-Wire @{id=4;method='turn/interrupt';params=@{threadId=$thread;turnId=$turn}}
                    $interruptSent=$true
                    Log-Live 'Stop requested. Interrupt sent to Codex. Completed actions are not rolled back.'
                }
            }
            foreach($key in @($pending.Keys)){
                $entry=$pending[$key]
                if($stopRequested){
                    $result=switch($entry.Message.method){
                        'mcpServer/elicitation/request' {@{action='decline';content=$null}}
                        'item/permissions/requestApproval' {@{permissions=@{};scope='turn'}}
                        'item/tool/requestUserInput' {@{answers=@{}}}
                        default {@{decision='cancel'}}
                    }
                    Send-Wire @{id=$entry.Message.id;result=$result}
                    if($entry.Message.params.itemId){$activeCommands.Remove($entry.Message.params.itemId)}
                    Remove-Item -LiteralPath $entry.Path -ErrorAction SilentlyContinue
                    $pending.Remove($key)
                    continue
                }
                if(Test-Path -LiteralPath $entry.Response){
                    $answer=Get-Content -LiteralPath $entry.Response -Raw | ConvertFrom-Json -AsHashtable
                    if($answer.Token -ne $key){throw 'Approval response identity mismatch.'}
                    $accepted=$answer.Approve -eq $true -and -not $stopRequested
                    $result=switch($entry.Message.method){
                        'mcpServer/elicitation/request' { @{action=$(if($accepted){'accept'}else{'decline'});content=$(if($accepted){@{}}else{$null})} }
                        'item/permissions/requestApproval' { @{permissions=$(if($accepted){$entry.Message.params.permissions}else{@{}});scope='turn'} }
                        'item/tool/requestUserInput' { @{answers=$(if($accepted){$answer.Answers}else{@{}})} }
                        default { @{decision=$(if($accepted){'accept'}else{'decline'})} }
                    }
                    Send-Wire @{id=$entry.Message.id;result=$result}
                    Remove-Item -LiteralPath $entry.Path
                    $pending.Remove($key)
                    Log-Live $(if($accepted){'User approved this request.'}else{'User rejected this request.'})
                }
            }
            if(-not $read.Wait(50)){continue}
            $line=$read.GetAwaiter().GetResult()
            if($null -eq $line){throw 'Codex disconnected before completing the turn.'}
            $read=$process.StandardOutput.ReadLineAsync()
            $message=$line | ConvertFrom-Json -AsHashtable
            Add-Content -LiteralPath (Join-Path $Bridge 'events.jsonl') -Value $line -Encoding utf8
            if($message.ContainsKey('id') -and -not $message.method){
                if($message.id -eq 4 -and $message.error.message -match 'no active turn'){
                    Log-Live 'Codex reported no active turn; waiting for its lifecycle update.'
                    $turnActive=$false;$interruptSent=$false
                    continue
                }
                if($message.error){throw ($message.error | ConvertTo-Json -Compress)}
                switch([int]$message.id){
                    1 {
                        if($HandshakeOnly){$complete=$true;continue}
                        Send-Wire @{method='initialized';params=@{}}
                        Send-Wire @{id=2;method='thread/start';params=@{cwd=$Repo;sandbox='read-only';approvalPolicy='on-request';approvalsReviewer='user'}}
                    }
                    2 {
                        $thread=$message.result.thread.id
                        Send-Wire @{id=3;method='turn/start';params=@{threadId=$thread;input=@(@{type='text';text=$Prompt})}}
                    }
                    3 {$turn=$message.result.turn.id}
                }
                continue
            }
            $p=$message.params
            if($message.ContainsKey('id')){
                $supported=$message.method -in @('item/commandExecution/requestApproval','item/fileChange/requestApproval','item/permissions/requestApproval','item/tool/requestUserInput')
                $isMcp=$message.method -eq 'mcpServer/elicitation/request'
                if($isMcp){
                    # This UI supports confirmation-only forms. Do not silently accept fields or URL flows.
                    $schema=$p.requestedSchema
                    $supported=$p.mode -eq 'form' -and $schema.type -eq 'object' -and @($schema.properties.Keys).Count -eq 0 -and @($schema.required | Where-Object { $null -ne $_ }).Count -eq 0
                    if($schema){
                        $extra=@($schema.Keys | Where-Object { $_ -notin @('type','properties','required','additionalProperties','title','description') })
                        if($extra.Count){$supported=$false}
                    }
                }
                $wrongTurn=$turn -and $p.turnId -ne $turn
                if($isMcp -and -not $p.turnId){$wrongTurn=$false}
                if($stopRequested -or -not $supported -or $p.threadId -ne $thread -or $wrongTurn){
                    Send-Wire @{id=$message.id;error=@{code=-32601;message='Unsupported or inactive request; no approval granted.'}}
                    Log-Live ('Request refused: '+$message.method)
                    continue
                }
                $key=[guid]::NewGuid().ToString('N')
                $path=Join-Path $Bridge ($key+'.request.json')
                $request=@{Token=$key;Method=$message.method;Params=$p;Item=$(if($p.itemId){$items[$p.itemId]}else{$null})}
                $request | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath ($path+'.tmp') -Encoding utf8
                Move-Item -LiteralPath ($path+'.tmp') -Destination $path
                $pending[$key]=@{Path=$path;Response=(Join-Path $Bridge ($key+'.response.json'));Message=$message}
                Log-Live 'Waiting for your response in the app.'
                continue
            }
            if($p.threadId -and $thread -and $p.threadId -ne $thread){continue}
            switch($message.method){
                'turn/started' {$turn=$p.turn.id;$turnActive=$true}
                'item/started' {
                    $items[$p.item.id]=$p.item
                    if($p.item.type -eq 'commandExecution'){$activeCommands[$p.item.id]=$p.item.command}
                    if($p.item.command){Log-Live ('Command: '+$p.item.command)}
                }
                'item/agentMessage/delta' {[IO.File]::AppendAllText((Join-Path $Bridge 'live.log'),[string]$p.delta,[Text.Encoding]::UTF8)}
                'item/commandExecution/outputDelta' {
                    [IO.File]::AppendAllText((Join-Path $Bridge 'live.log'),[string]$p.delta,[Text.Encoding]::UTF8)
                    $pathErrors += [regex]::Matches([string]$p.delta,'(?i)Split-Path:').Count
                    if($pathErrors -ge 20 -and -not (Test-Path -LiteralPath ($Bridge+'.stop.request'))){
                        Set-Content -LiteralPath ($Bridge+'.stop.request') -Value 'Automatic stop: repeated path traversal errors.'
                        Log-Live 'Automatic stop requested: repeated Split-Path errors. No further actions will be approved.'
                    }
                }
                'item/completed' {
                    if($p.item.type -eq 'commandExecution'){$activeCommands.Remove($p.item.id)}
                    if($p.item.type -eq 'agentMessage'){$final=$p.item.text;Log-Live $final}
                    elseif($p.item.status){Log-Live ($p.item.type+': '+$p.item.status)}
                }
                'serverRequest/resolved' {
                    foreach($key in @($pending.Keys)){
                        if($pending[$key].Message.id -eq $p.requestId){Remove-Item -LiteralPath $pending[$key].Path -ErrorAction SilentlyContinue;$pending.Remove($key)}
                    }
                }
                'error' {Log-Live ('Codex error: '+$p.error.message)}
                'turn/completed' {
                    if($p.turn.id -ne $turn){continue}
                    $turnActive=$false
                    if($p.turn.status -ne 'completed'){throw ('Clean turn ended: '+$p.turn.status+' '+($p.turn.error | ConvertTo-Json -Compress))}
                    if(-not (Test-Path -LiteralPath $Report) -and $final){Set-Content -LiteralPath $Report -Value $final -Encoding utf8}
                    $complete=$true
                }
            }
        }
    } finally {
        foreach($entry in $pending.Values){Remove-Item -LiteralPath $entry.Path -ErrorAction SilentlyContinue}
        try { $process.StandardInput.Close(); if(-not $process.WaitForExit(3000)){$process.Kill($true)} } catch { }
        if($drain){try{[void]$drain.GetAwaiter().GetResult()}catch{}}
        $stderr.Dispose();$process.Dispose()
    }
}
