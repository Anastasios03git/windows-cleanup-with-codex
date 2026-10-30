#Requires -Version 7.0
param([Parameter(Mandatory)][string]$TestRoot)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $TestRoot) { throw 'Use a new test directory.' }
New-Item -ItemType Directory -Path $TestRoot | Out-Null
$taskRepo = Join-Path $TestRoot 'repo with spaces'
New-Item -ItemType Directory -Path $taskRepo | Out-Null
Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot) 'Start-WindowsCleanup.ps1') -Destination $taskRepo
Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot) 'skills') -Destination $taskRepo -Recurse
Copy-Item -LiteralPath (Join-Path (Split-Path $PSScriptRoot) 'scripts') -Destination $taskRepo -Recurse
$taskLauncher = Join-Path $taskRepo 'Start-WindowsCleanup.ps1'
$taskMock = Join-Path $TestRoot 'Mock Codex.ps1'
$taskMockSource = @'
$taskMockArgs = @($args)
@{Arguments=$taskMockArgs;Invocation=[guid]::NewGuid().ToString()} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $env:WINDOWS_CLEANUP_TEST_LOG
$global:LASTEXITCODE = 0
if ($env:WINDOWS_CLEANUP_TEST_FAILURE -eq 'yes') { exit 9 }
$taskOutputIndex = [Array]::IndexOf($taskMockArgs, '--output-last-message')
if ($taskOutputIndex -ge 0) {
    if ($env:WINDOWS_CLEANUP_TEST_STRESS -eq 'yes') {
        for ($taskI=0; $taskI -lt 20; $taskI++) {
            [Console]::Out.WriteLine(('raw-output-' + [char]0x03A9) * 8192)
            [Console]::Error.WriteLine(('raw-error-' + [char]0x03A9) * 8192)
        }
    }
    Set-Content -LiteralPath $taskMockArgs[$taskOutputIndex+1] -Value 'SIMULATION ONLY: no cleanup targets; no device inspection performed.'
} elseif ($env:WINDOWS_CLEANUP_TEST_NO_REPORT -ne 'yes') {
    $taskText = $taskMockArgs[-1]
    $taskMatch = [regex]::Match($taskText, '(?m)^Save the final factual report to: (.+)$')
    if (-not $taskMatch.Success) { throw 'Report destination not provided.' }
    Set-Content -LiteralPath $taskMatch.Groups[1].Value.Trim() -Value 'SIMULATION ONLY: no cleanup actions executed.'
}
'@
Set-Content -LiteralPath $taskMock -Value $taskMockSource
$taskOriginalLog = $env:WINDOWS_CLEANUP_TEST_LOG
$taskOriginalFailure = $env:WINDOWS_CLEANUP_TEST_FAILURE
$taskOriginalNoReport = $env:WINDOWS_CLEANUP_TEST_NO_REPORT
$taskOriginalStress = $env:WINDOWS_CLEANUP_TEST_STRESS
$taskExistingReadHost = Get-Item Function:\global:Read-Host -ErrorAction SilentlyContinue
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Inspect([string]$name) {
    $taskRun = Join-Path $TestRoot $name
    & $taskLauncher -Mode Inspect -CodexPath $taskMock -RunDirectory $taskRun | Out-Null
    return $taskRun
}
function Reject([scriptblock]$action) {
    $taskRejected = $false
    try { & $action | Out-Null } catch { $taskRejected = $true }
    Assert $taskRejected 'Expected rejection did not occur.'
}
function RejectWithoutLaunch([scriptblock]$action) {
    $taskPreviousCall = Get-Content -LiteralPath $env:WINDOWS_CLEANUP_TEST_LOG -Raw
    Reject $action
    Assert ((Get-Content -LiteralPath $env:WINDOWS_CLEANUP_TEST_LOG -Raw) -eq $taskPreviousCall) 'Rejected plan still launched Codex.'
}
try {
    $env:WINDOWS_CLEANUP_TEST_LOG = Join-Path $TestRoot 'invocation.json'
    $taskRun = Inspect 'normal'
    $taskCall = Get-Content -LiteralPath $env:WINDOWS_CLEANUP_TEST_LOG -Raw | ConvertFrom-Json
    Assert ($taskCall.Arguments[0] -eq 'exec') 'Inspection must use exec.'
    Assert ($taskCall.Arguments -contains 'read-only') 'Inspection must be read-only.'
    function global:Read-Host { return '' }
    & $taskLauncher -Mode Clean -CodexPath $taskMock -RunDirectory $taskRun | Out-Null
    Assert (-not (Test-Path -LiteralPath (Join-Path $taskRun 'cleanup-report.md'))) 'Cancelled run executed.'
    function global:Read-Host { return 'CLEAN' }
    & $taskLauncher -Mode Clean -CodexPath $taskMock -RunDirectory $taskRun | Out-Null
    $taskCall = Get-Content -LiteralPath $env:WINDOWS_CLEANUP_TEST_LOG -Raw | ConvertFrom-Json
    Assert ($taskCall.Arguments -contains 'on-request') 'Interactive approvals missing.'
    Assert ($taskCall.Arguments -contains 'read-only') 'Cleanup session must start read-only.'
    Assert (-not ($taskCall.Arguments -contains 'danger-full-access')) 'Unexpected full access.'
    Assert ((Get-Content -LiteralPath (Join-Path $taskRun 'run.json') -Raw | ConvertFrom-Json).Status -eq 'session_completed_review_report') 'Session status is wrong.'
    RejectWithoutLaunch { & $taskLauncher -Mode Clean -CodexPath $taskMock -RunDirectory $taskRun }
    Write-Output 'PASS: inspection, cancellation, approved interactive session, report, and replay rejection'
    $taskTampered = Inspect 'tampered'
    Add-Content -LiteralPath (Join-Path $taskTampered 'inspection.md') -Value 'altered'
    RejectWithoutLaunch { & $taskLauncher -Mode Clean -CodexPath $taskMock -RunDirectory $taskTampered }
    $taskStale = Inspect 'stale'
    $taskManifestFile = Join-Path $taskStale 'run.json'
    $taskManifest = Get-Content -LiteralPath $taskManifestFile -Raw | ConvertFrom-Json
    $taskManifest.CreatedUtc = [datetime]::UtcNow.AddDays(-2).ToString('o')
    $taskManifest | ConvertTo-Json | Set-Content -LiteralPath $taskManifestFile
    RejectWithoutLaunch { & $taskLauncher -Mode Clean -CodexPath $taskMock -RunDirectory $taskStale }
    $taskWrong = Inspect 'wrong-computer'
    $taskManifestFile = Join-Path $taskWrong 'run.json'
    $taskManifest = Get-Content -LiteralPath $taskManifestFile -Raw | ConvertFrom-Json
    $taskManifest.Computer = 'ANOTHER-COMPUTER'
    $taskManifest | ConvertTo-Json | Set-Content -LiteralPath $taskManifestFile
    RejectWithoutLaunch { & $taskLauncher -Mode Clean -CodexPath $taskMock -RunDirectory $taskWrong }
    Write-Output 'PASS: altered, expired, and foreign-computer plans rejected'
    $env:WINDOWS_CLEANUP_TEST_STRESS = 'yes'
    $taskLarge = Inspect 'large-native-output'
    Assert ((Get-Item -LiteralPath (Join-Path $taskLarge 'inspection-console.log')).Length -gt 1MB) 'Large stdout was not captured.'
    Assert ((Get-Item -LiteralPath (Join-Path $taskLarge 'inspection-errors.log')).Length -gt 1MB) 'Large stderr was not captured.'
    $env:WINDOWS_CLEANUP_TEST_STRESS = ''
    Write-Output 'PASS: simultaneous large Unicode stdout/stderr captured without blocking or console streaming'
    $env:WINDOWS_CLEANUP_TEST_FAILURE = 'yes'
    $taskFailed = Join-Path $TestRoot 'failed'
    Reject { & $taskLauncher -Mode Inspect -CodexPath $taskMock -RunDirectory $taskFailed }
    Assert ((Get-Content -LiteralPath (Join-Path $taskFailed 'run.json') -Raw | ConvertFrom-Json).Status -eq 'inspection_failed') 'Failed inspection marked successful.'
    Assert ((Get-Content -LiteralPath (Join-Path $taskFailed 'run.json') -Raw | ConvertFrom-Json).ErrorMessage -match 'exit code 9') 'Failure detail was not persisted.'
    Assert ((Get-Content -LiteralPath (Join-Path $taskFailed 'inspection-console.log') -Raw) -match 'exit code 9') 'Failure detail is missing from console log.'
    $env:WINDOWS_CLEANUP_TEST_FAILURE = ''
    $taskMissing = Inspect 'missing-report'
    $env:WINDOWS_CLEANUP_TEST_NO_REPORT = 'yes'
    Reject { & $taskLauncher -Mode Clean -CodexPath $taskMock -RunDirectory $taskMissing }
    Assert ((Get-Content -LiteralPath (Join-Path $taskMissing 'run.json') -Raw | ConvertFrom-Json).Status -eq 'session_needs_review') 'Missing report marked successful.'
    $env:WINDOWS_CLEANUP_TEST_NO_REPORT = ''
    $taskChangedSkill = Inspect 'changed-skill'
    Add-Content -LiteralPath (Join-Path $taskRepo 'skills/windows-cleanup/SKILL.md') -Value 'Changed after inspection'
    RejectWithoutLaunch { & $taskLauncher -Mode Clean -CodexPath $taskMock -RunDirectory $taskChangedSkill }
    Write-Output 'PASS: CLI failure and missing report surfaced; no real Codex or cleanup executed'
} finally {
    $env:WINDOWS_CLEANUP_TEST_LOG = $taskOriginalLog
    $env:WINDOWS_CLEANUP_TEST_FAILURE = $taskOriginalFailure
    $env:WINDOWS_CLEANUP_TEST_NO_REPORT = $taskOriginalNoReport
    $env:WINDOWS_CLEANUP_TEST_STRESS = $taskOriginalStress
    if ($taskExistingReadHost) { Set-Item Function:\global:Read-Host $taskExistingReadHost.ScriptBlock } else { Remove-Item Function:\global:Read-Host -ErrorAction SilentlyContinue }
}
