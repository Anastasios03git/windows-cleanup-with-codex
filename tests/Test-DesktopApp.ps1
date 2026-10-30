#Requires -Version 7.0
param([Parameter(Mandatory)][string]$TestRoot)
$ErrorActionPreference='Stop'
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Use pwsh -STA -File.' }
$testRootPath=[IO.Path]::GetFullPath($TestRoot)
if(Test-Path -LiteralPath $testRootPath){throw 'Choose a new test directory.'}
New-Item -ItemType Directory -Path $testRootPath | Out-Null
$testMock=Join-Path $testRootPath 'Mock Codex.ps1'
Set-Content -LiteralPath $testMock -Value @'
$index=[array]::IndexOf($args,'--output-last-message')
if($index -lt 0){throw 'This mock does not permit Clean.'}
Start-Sleep -Seconds 2
Set-Content -LiteralPath $args[$index+1] -Value 'GUI TEST ONLY: simulated inspection. No computer inspection or cleanup performed.'
exit 0
'@
. (Join-Path (Split-Path $PSScriptRoot) 'Start-WindowsCleanupApp.ps1') -ValidateOnly -CodexPath $testMock -RunRoot (Join-Path $testRootPath 'runs')
$script:ui.Diagnostics.IsChecked=$false
Start-Agent 'Inspect'
if(-not $script:job){throw 'Inspection did not start.'}
if($script:ui.Inspect.IsEnabled){throw 'Duplicate inspections must be disabled.'}
$testRun=$script:job.Run
$script:timer.Start()
try {
 $deadline=[datetime]::UtcNow.AddSeconds(30)
 while($script:job -and [datetime]::UtcNow -lt $deadline){
  $script:window.Dispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background)
  Start-Sleep -Milliseconds 100
 }
 if($script:job){throw 'Mock inspection timed out.'}
 $state=Get-Content -LiteralPath (Join-Path $testRun 'run.json') -Raw | ConvertFrom-Json
 if($state.Status -ne 'review_required'){throw 'Wrong final inspection state.'}
 if($script:ui.Report.Text -notmatch 'GUI TEST ONLY'){throw 'Report not displayed.'}
 if($script:current -ne $testRun){throw 'New run not selected in history.'}
 if($script:ui.Clean.IsEnabled){throw 'Clean enabled without report review.'}
 $script:ui.Reviewed.IsChecked=$true
 Update-Controls
 if(-not $script:ui.Clean.IsEnabled){throw 'Clean not enabled after review.'}
 Show-Report 'cleanup-report.md'
 if($script:ui.Clean.IsEnabled){throw 'Result view must not authorize a plan.'}
 'PASS: asynchronous mock inspection, duplicate-launch prevention, report/history display and review gates; no real inspection or cleanup.'
} finally { $script:timer.Stop() }
