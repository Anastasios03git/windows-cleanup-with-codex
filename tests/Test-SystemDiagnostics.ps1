#Requires -Version 7.0
param([Parameter(Mandatory)][string]$TestRoot)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $TestRoot) { throw 'Choose a new test directory.' }
New-Item -ItemType Directory -Path $TestRoot | Out-Null
$taskLauncher = Join-Path (Split-Path $PSScriptRoot) 'Start-WindowsCleanup.ps1'
$taskMock = Join-Path $TestRoot 'Mock Codex.ps1'
Set-Content -LiteralPath $taskMock -Value @'
$taskArgs = @($args)
@{Arguments=$taskArgs} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $env:WINDOWS_CLEANUP_DIAGNOSTICS_TEST_LOG
$taskIndex = [array]::IndexOf($taskArgs,'--output-last-message')
Set-Content -LiteralPath $taskArgs[$taskIndex+1] -Value 'Simulated inspection; no system access or cleanup.'
'@
$taskOldStart = Get-Item Function:\global:Start-Process -ErrorAction SilentlyContinue
$taskOldLog = $env:WINDOWS_CLEANUP_DIAGNOSTICS_TEST_LOG
$global:WindowsCleanupDiagnosticsScenario = 'ok'
function Assert($value,$message) { if(-not $value){throw $message} }
function global:Start-Process {
    param($FilePath,$Verb,$WindowStyle,$ArgumentList,[switch]$PassThru,$ErrorAction)
    if ($Verb -ne 'RunAs' -or $WindowStyle -ne 'Hidden') { throw 'Expected a hidden RunAs helper.' }
    if ($global:WindowsCleanupDiagnosticsScenario -eq 'declined') { throw [ComponentModel.Win32Exception]::new(1223) }
    $taskArgs = @($ArgumentList)
    $taskOutput = $taskArgs[[array]::IndexOf($taskArgs,'-RunDirectory')+1].Trim('"')
    $taskRequest = $taskArgs[[array]::IndexOf($taskArgs,'-RequestId')+1]
    if ($global:WindowsCleanupDiagnosticsScenario -eq 'invalid') { $taskRequest='another-request' }
    if ($global:WindowsCleanupDiagnosticsScenario -ne 'missing') {
        @{SchemaVersion=1;RequestId=$taskRequest;Computer=$env:COMPUTERNAME;Status=if($global:WindowsCleanupDiagnosticsScenario -eq 'partial'){'partial'}else{'completed'};Checks=@{Volumes=@(@{Drive='C:';FreeBytes=123})};Errors=@()} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskOutput 'system-diagnostics.json')
    }
    $taskProcess = [pscustomobject]@{}
    $taskProcess | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {param($milliseconds) return $true}
    $taskProcess | Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
    return $taskProcess
}
try {
    $env:WINDOWS_CLEANUP_DIAGNOSTICS_TEST_LOG = Join-Path $TestRoot 'invocation.json'
    foreach ($taskCase in @('ok','partial','declined','missing','invalid')) {
        $global:WindowsCleanupDiagnosticsScenario = $taskCase
        $taskRun = Join-Path $TestRoot $taskCase
        & $taskLauncher -Mode Inspect -CodexPath $taskMock -RunDirectory $taskRun -SystemDiagnostics | Out-Null
        $taskState = Get-Content -LiteralPath (Join-Path $taskRun 'run.json') -Raw | ConvertFrom-Json
        $taskExpected = @{ok='completed';partial='partial';declined='declined';missing='failed';invalid='failed'}[$taskCase]
        Assert ($taskState.DiagnosticsStatus -eq $taskExpected) "Incorrect status for $taskCase"
        Assert ($taskState.Status -eq 'review_required') 'Basic inspection should remain available.'
        $taskCall = Get-Content -LiteralPath $env:WINDOWS_CLEANUP_DIAGNOSTICS_TEST_LOG -Raw | ConvertFrom-Json
        Assert ($taskCall.Arguments -contains 'read-only') 'Agent sandbox was changed.'
        if ($taskCase -eq 'ok') {
            Assert ([bool]$taskState.DiagnosticsHash) 'Missing diagnostics integrity hash.'
            Assert ($taskCall.Arguments[-1] -match 'pre-collected fixed system diagnostics') 'Snapshot not passed to agent.'
            Add-Content -LiteralPath (Join-Path $taskRun 'system-diagnostics.json') -Value 'modified'
            $taskRejected=$false
            try { & $taskLauncher -Mode Clean -CodexPath $taskMock -RunDirectory $taskRun | Out-Null } catch { $taskRejected=$_.Exception.Message -match 'diagnostics were modified' }
            Assert $taskRejected 'Modified diagnostics were accepted for cleanup.'
        }
    }
    Write-Output 'PASS: successful diagnostics, UAC cancellation, missing report, sandbox preservation, and modified snapshot rejection'
} finally {
    $env:WINDOWS_CLEANUP_DIAGNOSTICS_TEST_LOG = $taskOldLog
    Remove-Variable WindowsCleanupDiagnosticsScenario -Scope Global -ErrorAction SilentlyContinue
    if ($taskOldStart) {Set-Item Function:\global:Start-Process $taskOldStart.ScriptBlock} else {Remove-Item Function:\global:Start-Process -ErrorAction SilentlyContinue}
}
