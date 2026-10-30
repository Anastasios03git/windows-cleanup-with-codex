#Requires -Version 7.0
[CmdletBinding()]
param([string]$CodexPath, [string]$RunRoot = (Join-Path $PSScriptRoot 'runs'), [switch]$ValidateOnly)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows is required.' }
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Start with pwsh -STA or use Open-WindowsCleanup.cmd.' }
Add-Type -AssemblyName PresentationFramework
trap { [void][Windows.MessageBox]::Show($_.Exception.Message,'Windows Cleanup — startup error'); exit 1 }
$script:repo = $PSScriptRoot
$script:runs = [IO.Path]::GetFullPath($RunRoot)
$script:pwsh = Join-Path $PSHOME 'pwsh.exe'
 . (Join-Path $script:repo 'scripts/Find-Dependencies.ps1')
$script:codex = if ($CodexPath) { (Get-Command $CodexPath -CommandType Application,ExternalScript -ErrorAction Stop | Select-Object -First 1).Source } else { Find-CleanupCodex }
$reader = [Xml.XmlReader]::Create((Join-Path $script:repo 'app/MainWindow.xaml'))
try { $script:window = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Dispose() }
$script:ui = @{}
foreach ($name in @('Diagnostics','Runtime','Inspect','Refresh','History','InspectionReport','CleanupReport','Report','Reviewed','Clean','Progress','Status','ApprovalPanel','ApprovalDetails','Questions','Approve','Reject','Confirmation','Stop')) { $script:ui[$name] = $script:window.FindName($name) }
$script:job = $null
$script:current = $null
$script:reportKind = 'inspection.md'
function Show-AppError($message) { [void][Windows.MessageBox]::Show($script:window,[string]$message,'Windows Cleanup','OK','Error') }
function Format-ElapsedTime([timespan]$elapsed) {
    '{0} min {1:00} sec' -f [long][math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
}
function Update-Controls {
    $busy = $null -ne $script:job
    $script:ui.Inspect.IsEnabled = -not $busy -and [bool]$script:codex
    $script:ui.Diagnostics.IsEnabled = -not $busy
    $script:ui.History.IsEnabled = -not $busy
    $script:ui.Refresh.IsEnabled = -not $busy
    $script:ui.Progress.IsIndeterminate = $busy
    $script:ui.Stop.IsEnabled = $busy -and $script:job.Mode -eq 'Clean' -and -not $script:job.StopRequested
    $eligible = $false
    if ($script:current -and -not $busy) {
        try {
            $state = Get-Content -LiteralPath (Join-Path $script:current 'run.json') -Raw | ConvertFrom-Json
            $eligible = $state.Status -eq 'review_required'
        } catch { }
    }
    $script:ui.Clean.IsEnabled = $eligible -and [bool]$script:codex -and $script:ui.Reviewed.IsChecked -eq $true -and $script:reportKind -eq 'inspection.md'
    $script:ui.InspectionReport.IsEnabled = [bool]$script:current -and -not $busy
    $script:ui.CleanupReport.IsEnabled = -not $busy -and [bool]$script:current -and (Test-Path -LiteralPath (Join-Path $script:current 'cleanup-report.md'))
}
function Show-Report([string]$kind) {
    $script:reportKind = $kind
    $script:ui.Reviewed.IsChecked = $false
    $script:ui.Confirmation.Text = ''
    if ($script:current) {
        $path = Join-Path $script:current $kind
        $script:ui.Report.Text = if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw } else { 'No report is available yet. The inspection may be running or may have failed. Check the logs in the run folder.' }
        $script:ui.Report.ScrollToHome()
    }
    Update-Controls
}
function Refresh-History([string]$selectPath) {
    $items = @(Get-ChildItem -LiteralPath $script:runs -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | ForEach-Object {
        $manifest = Join-Path $_.FullName 'run.json'
        if (Test-Path -LiteralPath $manifest) {
            try {
                $state = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
                $displayTime = $_.Name
                try {
                    $created = if ($state.CreatedUtc -is [datetime]) { [datetimeoffset]$state.CreatedUtc } else { [datetimeoffset]::Parse([string]$state.CreatedUtc, [Globalization.CultureInfo]::InvariantCulture) }
                    $displayTime = $created.ToLocalTime().ToString('dd/MM/yyyy HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
                } catch { }
                [pscustomobject]@{Label=($displayTime+'  ·  '+$state.Status);Path=$_.FullName}
            } catch { }
        }
    })
    $script:ui.History.ItemsSource = $items
    $chosen = $items | Where-Object Path -eq $selectPath | Select-Object -First 1
    if ($chosen) { $script:ui.History.SelectedItem=$chosen } elseif ($items.Count) { $script:ui.History.SelectedIndex=0 }
    Update-Controls
}
function Start-Agent([string]$mode) {
    if ($script:job) { return }
    if ($mode -eq 'Clean' -and $script:ui.Confirmation.Text -cne 'CLEAN') { $script:ui.Status.Text='Type CLEAN after reading the inspection report.'; return }
    $process = $null
    $outStream = $null
    $errStream = $null
    $logDir = $null
    try {
        $run = if ($mode -eq 'Inspect') { Join-Path $script:runs ((Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)) } else { $script:current }
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $script:pwsh
        $start.WorkingDirectory = $script:repo
        $arguments = @('-NoProfile')
        $bridge = if ($mode -eq 'Clean') { Join-Path $run ('app-server-'+[guid]::NewGuid().ToString('N')) } else { $null }
        $arguments += @('-ExecutionPolicy','RemoteSigned','-File',(Join-Path $script:repo 'Start-WindowsCleanup.ps1'),'-CodexPath',$script:codex,'-Mode',$mode,'-RunDirectory',$run)
        if ($mode -eq 'Clean') { $arguments += @('-AppServer','-BridgeDirectory',$bridge,'-Confirmation','CLEAN') }
        if ($mode -eq 'Inspect' -and $script:ui.Diagnostics.IsChecked) { $arguments += '-SystemDiagnostics' }
        foreach ($argument in $arguments) { $start.ArgumentList.Add($argument) }
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $start
        if ($mode -in @('Inspect','Clean')) {
            $logDir = Join-Path $script:runs ('app-logs/'+[guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            $start.RedirectStandardOutput = $true
            $start.RedirectStandardError = $true
            $outStream = [IO.File]::Open((Join-Path $logDir 'launcher.log'),'CreateNew','Write','Read')
            $errStream = [IO.File]::Open((Join-Path $logDir 'launcher-errors.log'),'CreateNew','Write','Read')
        }
        if (-not $process.Start()) { throw 'Could not start the agent.' }
        $script:job = @{Process=$process;Mode=$mode;Run=$run;Timer=[Diagnostics.Stopwatch]::StartNew();Out=$outStream;Err=$errStream;LogDir=$logDir;Bridge=$bridge}
        if ($mode -in @('Inspect','Clean')) {
            $script:job.CopyOut = $process.StandardOutput.BaseStream.CopyToAsync($outStream)
            $script:job.CopyErr = $process.StandardError.BaseStream.CopyToAsync($errStream)
            $script:ui.Report.Text = if($mode -eq 'Clean'){'Starting Clean. Agent messages and approval requests will appear here.'}else{'Inspection started without deleting anything. Keep this window open while the agent works.'}
        }
        $script:ui.Status.Text = if ($mode -eq 'Clean') { 'Clean is running here. Requested actions will appear with Approve / Reject controls.' } else { 'Inspection started. If diagnostics are enabled, wait for the Windows administrator approval request.' }
        Update-Controls
    } catch {
        if ($outStream) { $outStream.Dispose() }; if ($errStream) { $errStream.Dispose() }; if ($process) { $process.Dispose() }
        $script:job=$null
        Show-AppError $_.Exception.Message
        Update-Controls
    }
}
$script:request=$null
$script:answerFields=@{}
function Update-CleanView {
    $job=$script:job
    $live=Join-Path $job.Bridge 'live.log'
    if(Test-Path -LiteralPath $live){$script:ui.Report.Text=(Get-Content -LiteralPath $live -Tail 180) -join "`n";$script:ui.Report.ScrollToEnd()}
    if($script:request -and -not (Test-Path -LiteralPath $script:request.Path)){
        $script:request=$null;$script:ui.ApprovalPanel.Visibility='Collapsed'
    }
    if(-not $script:request -and -not $job.StopRequested){
        $file=Get-ChildItem -LiteralPath $job.Bridge -Filter '*.request.json' -File -ErrorAction SilentlyContinue | Where-Object { -not (Test-Path -LiteralPath ($_.FullName.Replace('.request.json','.response.json'))) } | Sort-Object LastWriteTime | Select-Object -First 1
        if($file){
            $data=Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable
            $script:request=@{Path=$file.FullName;Data=$data}
            $p=$data.Params
            $description=switch($data.Method){
                'mcpServer/elicitation/request' {
                    $meta=$p._meta
                    "Allow this tool request`n"+$p.message+"`nTool: "+$(if($meta.connector_name){$meta.connector_name}else{$p.serverName})+$(if($meta.tool_params){"`nRequested action: "+($meta.tool_params | ConvertTo-Json -Depth 20)})+"`nThis approval applies to this request only."
                }
                'item/commandExecution/requestApproval' {
                    "Run command`n"+$p.reason+"`nWorking directory: "+$p.cwd+"`n"+$(if($p.command){$p.command}else{$data.Item.command})+$(if($p.networkApprovalContext){"`nNetwork access: "+($p.networkApprovalContext | ConvertTo-Json -Depth 15)})
                }
                'item/fileChange/requestApproval' {"Allow file changes`n"+$p.reason+"`n"+($data.Item.changes | ConvertTo-Json -Depth 25)+$(if($p.grantRoot){"`nRequested write access: "+$p.grantRoot})}
                'item/permissions/requestApproval' {"Allow requested access for this turn`n"+$p.reason+"`n"+($p.permissions | ConvertTo-Json -Depth 25)}
                'item/tool/requestUserInput' {'Answer the questions below. Enter an option label or your own answer.'}
            }
            $script:ui.ApprovalDetails.Text=$description
            $script:ui.Questions.Children.Clear();$script:answerFields=@{}
            foreach($q in $data.Params.questions){
                $label=[Windows.Controls.TextBlock]::new();$label.Text=$q.question
                if($q.options){$label.Text+="`nOptions: "+(($q.options | ForEach-Object {$_.label}) -join ' / ')}
                $label.TextWrapping='Wrap';[void]$script:ui.Questions.Children.Add($label)
                $field=[Windows.Controls.TextBox]::new();$field.Margin='0,4,0,8'
                [void]$script:ui.Questions.Children.Add($field);$script:answerFields[$q.id]=$field
            }
            $script:ui.Approve.Content=if($data.Method -eq 'item/tool/requestUserInput'){'Submit answer'}else{'Approve this request'}
            $script:ui.ApprovalPanel.Visibility='Visible'
        }
    }
    $script:ui.Status.Text=if($job.StopRequested){'Stop requested. Waiting for Codex; Windows servicing is allowed to finish.'}elseif($script:request){'Codex is waiting for your response. Review the full request below.'}else{'Clean in progress · '+(Format-ElapsedTime $job.Timer.Elapsed)}
}
function Stop-AppClean {
    if(-not $script:job -or $script:job.Mode -ne 'Clean' -or $script:job.StopRequested){return}
    Set-Content -LiteralPath ($script:job.Bridge+'.stop.request') -Value 'User requested interruption.'
    $script:job.StopRequested=$true
    $script:ui.ApprovalPanel.Visibility='Collapsed'
    $script:request=$null
    Update-Controls
}
function Send-AppDecision([bool]$approve){
    if(-not $script:job -or $script:job.StopRequested -or -not $script:request -or $script:job.Process.HasExited){return}
    $request=$script:request
    if(-not (Test-Path -LiteralPath $request.Path)){$script:request=$null;return}
    $answers=@{}
    foreach($key in $script:answerFields.Keys){$answers[$key]=@{answers=@($script:answerFields[$key].Text)}}
    $response=$request.Path.Replace('.request.json','.response.json')
    @{Token=$request.Data.Token;Approve=$approve;Answers=$answers} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath ($response+'.tmp') -Encoding utf8
    Move-Item -LiteralPath ($response+'.tmp') -Destination $response
    $script:request=$null;$script:ui.ApprovalPanel.Visibility='Collapsed'
}
$script:ui.Runtime.Text = if ($script:codex) { 'Codex detected · PowerShell '+$PSVersionTable.PSVersion } else { 'Codex CLI was not found. Install it, sign in, and reopen the app.' }
$script:ui.Inspect.Add_Click({ Start-Agent 'Inspect' })
$script:ui.Clean.Add_Click({ Start-Agent 'Clean' })
$script:ui.Approve.Add_Click({ Send-AppDecision $true })
$script:ui.Reject.Add_Click({ Send-AppDecision $false })
$script:ui.Stop.Add_Click({ Stop-AppClean })
$script:ui.Refresh.Add_Click({ Refresh-History $script:current })
$script:ui.History.Add_SelectionChanged({
    $script:current = if ($script:ui.History.SelectedItem) { $script:ui.History.SelectedItem.Path } else { $null }
    Show-Report 'inspection.md'
})
$script:ui.InspectionReport.Add_Click({ Show-Report 'inspection.md' })
$script:ui.CleanupReport.Add_Click({ Show-Report 'cleanup-report.md' })
$script:ui.Reviewed.Add_Checked({ Update-Controls })
$script:ui.Reviewed.Add_Unchecked({ Update-Controls })
$script:timer = [Windows.Threading.DispatcherTimer]::new()
$script:timer.Interval = [timespan]::FromSeconds(1)
$script:timer.Add_Tick({
    if (-not $script:job) { return }
    try {
        $job = $script:job
        if ($job.Mode -eq 'Clean') { Update-CleanView }
        if (-not $job.Process.HasExited) {
            if ($job.Mode -eq 'Inspect') {
                $elapsed = Format-ElapsedTime $job.Timer.Elapsed
                $log = Get-Item -LiteralPath (Join-Path $job.Run 'inspection-errors.log') -ErrorAction SilentlyContinue
                $activity = if ($log) { ' · Last log update '+$log.LastWriteTime.ToString('HH:mm:ss') } else { ' · Preparing / collecting diagnostics' }
                $script:ui.Status.Text = "Inspection running · $elapsed$activity · No deletions"
            }
            return
        }
        if (-not $job.CopyOut.IsCompleted -or -not $job.CopyErr.IsCompleted) { return }
        $exitCode = $job.Process.ExitCode
        if ($job.Out) { [void]$job.CopyOut.GetAwaiter().GetResult(); [void]$job.CopyErr.GetAwaiter().GetResult() }
        if ($job.Out) { $job.Out.Dispose(); $job.Err.Dispose() }
        $job.Process.Dispose()
        $script:job=$null
        $script:request=$null
        $script:ui.ApprovalPanel.Visibility='Collapsed'
        Refresh-History $job.Run
        if ($job.Mode -eq 'Clean') {
            Show-Report 'cleanup-report.md'
            if($job.StopRequested -and -not (Test-Path -LiteralPath (Join-Path $job.Run 'cleanup-report.md'))){$script:ui.Report.Text='Clean was interrupted before a final report was saved. Review the saved logs. Actions completed before interruption are not undone.'}
            $script:ui.Status.Text = $(if($exitCode -eq 0){'Clean session completed. Review actual removals, skips, and errors in the report.'}else{'Clean did not complete successfully. Review the report and logs: '+$job.LogDir})
        } elseif ($exitCode -eq 0) {
            $script:ui.Status.Text = 'Inspection completed without deletions. Read the report before continuing.'
        } else {
            $script:ui.Status.Text = 'Inspection failed. Logs: '+$job.LogDir
            Show-AppError ('Inspection did not complete. Check the logs: '+$job.LogDir)
        }
        Update-Controls
    } catch {
        if ($script:job) {
            if ($script:job.Out) { $script:job.Out.Dispose(); $script:job.Err.Dispose() }
            $script:job.Process.Dispose(); $script:job=$null
        }
        $script:ui.Status.Text = 'Review the logs before trying again.'
        Update-Controls
        Show-AppError $_.Exception.Message
    }
})
$script:window.Add_Closing({ param($sender,$eventArgs)
    if ($script:job) { $eventArgs.Cancel=$true; Show-AppError 'A session is still running. Wait for it to finish. Respond to any pending approval in the app.' }
})
Refresh-History
if ($ValidateOnly) { 'PASS: WPF loaded, controls bound, runtime discovery and history initialized.'; return }
$script:timer.Start()
try { [void]$script:window.ShowDialog() } finally { $script:timer.Stop() }
