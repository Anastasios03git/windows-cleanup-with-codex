#Requires -Version 7.0
param([Parameter(Mandatory)][string]$TestRoot)
$ErrorActionPreference='Stop'
$testBase=[IO.Path]::GetFullPath($TestRoot)
if(Test-Path -LiteralPath $testBase){throw 'Choose a new test directory.'}
New-Item -ItemType Directory -Path $testBase | Out-Null
$testMock=Join-Path $testBase 'Mock Stop.ps1'
Set-Content -LiteralPath $testMock -Value @'
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
function Emit($v){[Console]::Out.WriteLine(($v | ConvertTo-Json -Depth 25 -Compress))}
if($args[0] -eq 'exec'){$i=[array]::IndexOf($args,'--output-last-message');Set-Content -LiteralPath $args[$i+1] -Value 'SIMULATED plan only.';exit 0}
while($null -ne ($line=[Console]::ReadLine())){
 $m=$line | ConvertFrom-Json -AsHashtable
 switch($m.method){
  'initialize' {Emit @{id=$m.id;result=@{}}}
  'thread/start' {Emit @{id=$m.id;result=@{thread=@{id='t'}}}}
  'turn/start' {
   Emit @{id=$m.id;result=@{turn=@{id='u';status='inProgress'}}}
   Emit @{method='turn/started';params=@{threadId='t';turn=@{id='u';status='inProgress'}}}
   $command=if($env:CLEANUP_STOP_CASE -in @('servicing','pending')){'DISM /Online /Cleanup-Image /StartComponentCleanup /NoRestart'}else{'Get-Process -Name msedge,dism; SIMULATED read-only path loop'}
   Emit @{method='item/started';params=@{threadId='t';item=@{id='cmd';type='commandExecution';command=$command}}}
   if($env:CLEANUP_STOP_CASE -eq 'auto'){Emit @{method='item/commandExecution/outputDelta';params=@{threadId='t';delta=('Split-Path: error'+"`n")*20}}}
   if($env:CLEANUP_STOP_CASE -eq 'servicing'){
    Start-Sleep -Seconds 2
    Emit @{method='item/completed';params=@{threadId='t';item=@{id='cmd';type='commandExecution';status='completed';exitCode=0}}}
   }
   if($env:CLEANUP_STOP_CASE -eq 'pending'){
    Emit @{id=10;method='item/commandExecution/requestApproval';params=@{threadId='t';turnId='u';itemId='cmd';command=$command}}
   }
  }
  'turn/interrupt' {
   Emit @{id=$m.id;result=@{}}
   Emit @{method='turn/completed';params=@{threadId='t';turn=@{id='u';status='interrupted'}}}
  }
 }
 if($m.id -eq 10){
  if($m.result.decision -eq 'accept'){throw 'Stop must not grant an approval.'}
  Emit @{method='item/completed';params=@{threadId='t';item=@{id='cmd';type='commandExecution';status='declined'}}}
 }
}
'@
$testOld=$env:CLEANUP_STOP_CASE
try{
 foreach($case in @('manual','auto','servicing','pending')){
  $env:CLEANUP_STOP_CASE=$case
  . (Join-Path (Split-Path $PSScriptRoot) 'Start-WindowsCleanupApp.ps1') -ValidateOnly -CodexPath $testMock -RunRoot (Join-Path $testBase $case)
  $script:timer.Interval=[timespan]::FromMilliseconds(75);$script:timer.Start()
  function Pump{$script:window.Dispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background);Start-Sleep -Milliseconds 50}
  Start-Agent 'Inspect';$deadline=[datetime]::UtcNow.AddSeconds(20)
  while($script:job -and [datetime]::UtcNow -lt $deadline){Pump}
  if($script:job){throw 'Mock inspection timed out.'}
  $run=$script:current;$script:ui.Reviewed.IsChecked=$true;$script:ui.Confirmation.Text='CLEAN'
  Start-Agent 'Clean';$bridge=$script:job.Bridge
  if(-not $script:ui.Stop.IsEnabled){throw 'Stop is unavailable during Clean.'}
  $deadline=[datetime]::UtcNow.AddSeconds(20);$requested=$false
  while($script:job -and [datetime]::UtcNow -lt $deadline){
   Pump
   if($case -ne 'auto' -and -not $requested -and (Test-Path -LiteralPath (Join-Path $bridge 'live.log'))){
    if((Get-Content -LiteralPath (Join-Path $bridge 'live.log') -Raw) -match 'Command:'){
     Stop-AppClean;$requested=$true
     if($script:ui.Stop.IsEnabled){throw 'Duplicate Stop requests are enabled.'}
    }
   }
  }
  $script:timer.Stop()
  if($script:job){throw "Stop timed out: $case"}
  $state=Get-Content -LiteralPath (Join-Path $run 'run.json') -Raw | ConvertFrom-Json
  if($state.Status -ne 'session_needs_review'){throw 'Interrupted run was reported as successful.'}
  if(-not $script:ui.Inspect.IsEnabled -or $script:ui.Stop.IsEnabled -or $script:ui.Clean.IsEnabled){throw 'UI did not recover safely.'}
  $log=Get-Content -LiteralPath (Join-Path $bridge 'live.log') -Raw
  if($case -in @('servicing','pending') -and $log -notmatch 'Waiting for the current Windows servicing'){throw 'Servicing deferral was not exercised.'}
  if($case -eq 'manual' -and $log -match 'Waiting for the current Windows servicing'){throw 'A process-list read was misclassified as servicing.'}
  if($case -eq 'auto' -and $log -notmatch 'Automatic stop requested'){throw 'Repeated-error guard did not run.'}
  "PASS: $case interruption; UI recovered; no real cleanup or servicing executed."
 }
}finally{if($script:timer){$script:timer.Stop()};$env:CLEANUP_STOP_CASE=$testOld}
