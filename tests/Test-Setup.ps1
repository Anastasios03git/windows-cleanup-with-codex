# Compatible with Windows PowerShell 5.1. No browser login or cleanup is performed.
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'scripts/Show-Setup.ps1') -ValidateOnly
$testPwsh=Find-CleanupPowerShell
if(-not $testPwsh){throw 'This test needs an installed PowerShell 7.'}
$testStart=${function:Start-SetupCommand}
function Assert($value,$message){if(-not $value){throw $message}}
function Wait-Check {
 $deadline=[datetime]::UtcNow.AddSeconds(15)
 $script:setupTimer.Start()
 while($script:probe -and [datetime]::UtcNow -lt $deadline){
  $script:setup.Dispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background)
  Start-Sleep -Milliseconds 50
 }
 $script:setupTimer.Stop()
 Assert (-not $script:probe) 'Status probe did not complete.'
}
try {
 function Find-CleanupPowerShell {return $null}
 function Find-CleanupCodex {return $null}
 Check-Setup
 Assert (-not $script:setupUi.OpenApp.IsEnabled) 'Missing dependencies enabled Open app.'
 Assert (-not $script:setupUi.SignIn.IsEnabled) 'Sign in enabled without Codex.'
 function Find-CleanupPowerShell {return $testPwsh}
 function Find-CleanupCodex {return $testPwsh}
 $script:testExit=1
 function Start-SetupCommand {param($path,$arguments); & $testStart $testPwsh ('-NoProfile -Command "exit '+$script:testExit+'"')}
 Check-Setup;Wait-Check
 Assert (-not $script:setupUi.OpenApp.IsEnabled) 'Signed-out account enabled Open app.'
 Assert $script:setupUi.SignIn.IsEnabled 'Sign in unavailable when Codex exists.'
 $script:testExit=0
 Check-Setup;Wait-Check
 Assert $script:setupUi.OpenApp.IsEnabled 'Ready dependencies did not enable Open app.'
 function Find-CleanupPowerShell {return $null}
 Check-Setup;Wait-Check
 Assert (-not $script:setupUi.OpenApp.IsEnabled) 'Missing PowerShell ignored after a successful login.'
 'PASS: missing dependencies, signed-out account, ready state, refresh, and missing PowerShell gate. No sign-in or cleanup performed.'
} finally {$script:setupTimer.Stop();Close-SetupCommand $script:probe}
