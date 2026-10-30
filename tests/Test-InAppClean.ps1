#Requires -Version 7.0
param([Parameter(Mandatory)][string]$TestRoot)
$ErrorActionPreference='Stop'
$testRootPath=[IO.Path]::GetFullPath($TestRoot)
if(Test-Path -LiteralPath $testRootPath){throw 'Choose a new test directory.'}
New-Item -ItemType Directory -Path $testRootPath | Out-Null
$testMock=Join-Path $testRootPath 'Mock app server.ps1'
$testCapture=Join-Path $testRootPath 'wire.jsonl'
$oldCapture=$env:CLEANUP_APP_TEST_CAPTURE
$env:CLEANUP_APP_TEST_CAPTURE=$testCapture
Set-Content -LiteralPath $testMock -Value @'
$ErrorActionPreference='Stop'
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
function Emit($value){[Console]::Out.WriteLine(($value | ConvertTo-Json -Depth 30 -Compress))}
if($args[0] -eq 'exec'){
 $i=[array]::IndexOf($args,'--output-last-message')
 Set-Content -LiteralPath $args[$i+1] -Value 'SIMULATION ONLY: no cleanup targets; no real changes.'
 exit 0
}
$step=0
while($null -ne ($line=[Console]::ReadLine())){
 Add-Content -LiteralPath $env:CLEANUP_APP_TEST_CAPTURE -Value $line
 $m=$line | ConvertFrom-Json -AsHashtable
 switch($m.method){
  'initialize' {Emit @{id=$m.id;result=@{userAgent='mock'}};continue}
  'initialized' {continue}
  'thread/start' {
   if($m.params.sandbox -ne 'read-only' -or $m.params.approvalPolicy -ne 'on-request' -or $m.params.approvalsReviewer -ne 'user'){throw 'Unsafe thread configuration'}
   Emit @{id=$m.id;result=@{thread=@{id='thread-test'}}};continue
  }
  'turn/start' {
   Emit @{id=$m.id;result=@{turn=@{id='turn-test';status='inProgress'}}}
   Emit @{method='turn/started';params=@{threadId='thread-test';turn=@{id='turn-test'}}}
   Emit @{method='item/started';params=@{threadId='thread-test';item=@{id='item-test';type='commandExecution';command='SIMULATED command'}}}
   Emit @{id=10;method='item/commandExecution/requestApproval';params=@{threadId='thread-test';turnId='turn-test';itemId='item-test';command='SIMULATED command'}}
   continue
  }
 }
 if($m.id -eq 10){
  if($m.result.decision -ne 'accept'){throw 'Expected command approval'}
  Emit @{id=11;method='item/fileChange/requestApproval';params=@{threadId='thread-test';turnId='turn-test';itemId='item-test';reason='SIMULATED file change'}}
 }elseif($m.id -eq 11){
  if($m.result.decision -ne 'decline'){throw 'Expected file rejection'}
  Emit @{id=12;method='item/permissions/requestApproval';params=@{threadId='thread-test';turnId='turn-test';itemId='item-test';permissions=@{network=@{enabled=$true}}}}
 }elseif($m.id -eq 12){
  if($m.result.scope -ne 'turn' -or -not $m.result.permissions.network.enabled){throw 'Wrong permission scope'}
  Emit @{id=13;method='item/tool/requestUserInput';params=@{threadId='thread-test';turnId='turn-test';itemId='item-test';questions=@(@{id='choice';question='Simulation question';options=@(@{label='Skip';description='Retain data'})})}}
 }elseif($m.id -eq 13){
  if($m.result.answers.choice.answers[0] -ne 'Skip'){throw 'Answer not delivered'}
  Emit @{id=14;method='unknown/request';params=@{threadId='thread-test';turnId='turn-test'}}
 }elseif($m.id -eq 14){
  if(-not $m.error){throw 'Unknown request not rejected'}
  Emit @{id=15;method='item/commandExecution/requestApproval';params=@{threadId='wrong-thread';turnId='turn-test';itemId='x'}}
 }elseif($m.id -eq 15){
  if(-not $m.error){throw 'Foreign request not rejected'}
  Emit @{id=16;method='mcpServer/elicitation/request';params=@{threadId='thread-test';serverName='node_repl';mode='form';message='Allow tool access? Ω';_meta=@{connector_name='Computer Use';tool_params=@{app='cleanmgr.exe'}};requestedSchema=@{type='object';properties=@{}}}}
 }elseif($m.id -eq 16){
  if($m.result.action -ne 'accept' -or $null -eq $m.result.content -or $m.result.content.Count -ne 0){throw 'MCP approval not delivered'}
  Emit @{id=17;method='mcpServer/elicitation/request';params=@{threadId='thread-test';turnId='turn-test';serverName='node_repl';mode='form';message='Second tool access?';requestedSchema=@{type='object';properties=@{}}}}
 }elseif($m.id -eq 17){
  if($m.result.action -ne 'decline' -or $null -ne $m.result.content){throw 'MCP rejection not delivered'}
  Emit @{id=18;method='mcpServer/elicitation/request';params=@{threadId='thread-test';turnId='turn-test';serverName='test';mode='form';requestedSchema=@{type='object';properties=@{name=@{type='string'}};required=@('name')}}}
 }elseif($m.id -eq 18){
  if(-not $m.error){throw 'Unsupported fields were silently accepted'}
  Emit @{id=19;method='mcpServer/elicitation/request';params=@{threadId='thread-test';turnId='turn-test';serverName='test';mode='url';url='https://example.invalid'}}
 }elseif($m.id -eq 19){
  if(-not $m.error){throw 'Unsupported URL request was silently accepted'}
  Emit @{method='item/completed';params=@{threadId='thread-test';item=@{id='final' ;type='agentMessage';text='SIMULATION ONLY: report generated without any cleanup or computer changes.'}}}
  Emit @{method='turn/completed';params=@{threadId='thread-test';turn=@{id='turn-test';status='completed'}}}
 }
}
'@
try {
 . (Join-Path (Split-Path $PSScriptRoot) 'Start-WindowsCleanupApp.ps1') -ValidateOnly -CodexPath $testMock -RunRoot (Join-Path $testRootPath 'runs')
 function Pump {
  $script:window.Dispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background)
  Start-Sleep -Milliseconds 80
 }
 $script:timer.Interval=[timespan]::FromMilliseconds(100)
 $script:timer.Start()
 Start-Agent 'Inspect'
 $deadline=[datetime]::UtcNow.AddSeconds(25)
 while($script:job -and [datetime]::UtcNow -lt $deadline){Pump}
 if($script:job){throw 'Inspection timeout'}
 $run=$script:current
 $script:ui.Reviewed.IsChecked=$true
 Start-Agent 'Clean'
 if($script:job){throw 'Clean started without typed confirmation'}
 $script:ui.Confirmation.Text='CLEAN'
 Start-Agent 'Clean'
 if(-not $script:job){throw 'Clean did not start'}
 $deadline=[datetime]::UtcNow.AddSeconds(35)
 $seen=@{}
 $mcpCount=0
 while($script:job -and [datetime]::UtcNow -lt $deadline){
  Pump
  if($script:request){
   $method=$script:request.Data.Method
   $seen[$method]=$true
   if($method -eq 'item/tool/requestUserInput'){$script:answerFields.choice.Text='Skip'}
   $decision=$method -ne 'item/fileChange/requestApproval'
   if($method -eq 'mcpServer/elicitation/request'){$mcpCount++;$decision=$mcpCount -eq 1;if($mcpCount -eq 1 -and -not $script:ui.ApprovalDetails.Text.Contains([string][char]0x03A9)){throw 'Unicode request corrupted in the UI'}}
   Send-AppDecision $decision
  }
 }
 if($script:job){throw 'Clean timeout'}
 $state=Get-Content -LiteralPath (Join-Path $run 'run.json') -Raw | ConvertFrom-Json
 if($state.Status -ne 'session_completed_review_report'){throw ('Wrong cleanup state: '+$state.Status)}
 if($seen.Count -ne 5 -or $mcpCount -ne 2){throw 'Not all approval/question routes were displayed'}
 if($script:ui.Report.Text -notmatch 'SIMULATION ONLY'){throw 'Final report not displayed'}
 if($script:ui.Clean.IsEnabled){throw 'Completed plan can be replayed'}
 'PASS: in-app Clean, typed consent, command approval, file rejection, turn-scoped permissions, questions, MCP confirmation approval/rejection, unsupported form/URL/foreign request rejection, final report and replay prevention. No real cleanup.'
}finally{
 if($script:timer){$script:timer.Stop()}
 $env:CLEANUP_APP_TEST_CAPTURE=$oldCapture
}
