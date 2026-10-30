#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RunDirectory,
    [Parameter(Mandatory)][string]$RequestId,
    [switch]$IncludeDrivers
)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows is required.' }
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'This diagnostics helper requires administrator rights.' }
$taskRoot = (Resolve-Path -LiteralPath $RunDirectory).Path
$taskPart = $taskRoot
while ($taskPart) {
    if ((Get-Item -LiteralPath $taskPart -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Diagnostic output paths must not contain reparse points.' }
    $taskPart = [IO.Path]::GetDirectoryName($taskPart.TrimEnd('\'))
}
foreach ($taskName in @('system-diagnostics.json','system-dism-analysis.log')) {
    if (Test-Path -LiteralPath (Join-Path $taskRoot $taskName)) { throw 'Diagnostics never overwrite existing output files.' }
}
$taskData = [ordered]@{SchemaVersion=1;RequestId=$RequestId;Computer=$env:COMPUTERNAME;StartedUtc=[datetime]::UtcNow.ToString('o');IncludeDrivers=[bool]$IncludeDrivers;Checks=[ordered]@{};Errors=@()}
function Read-Diagnostic([string]$taskName,[scriptblock]$taskRead) {
    try { $taskData.Checks[$taskName] = & $taskRead }
    catch { $taskData.Errors += [pscustomobject]@{Check=$taskName;Error=$_.Exception.Message} }
}
Read-Diagnostic 'OS' {
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,WindowsDirectory,SystemDrive,LastBootUpTime
}
Read-Diagnostic 'Volumes' {
    @([IO.DriveInfo]::GetDrives() | Where-Object {$_.IsReady -and $_.DriveType -eq 'Fixed'} | ForEach-Object {
        [pscustomobject]@{Drive=$_.Name;TotalBytes=$_.TotalSize;FreeBytes=$_.TotalFreeSpace;AvailableBytes=$_.AvailableFreeSpace}
    })
}
Read-Diagnostic 'Services' {
    @(Get-Service -Name wuauserv,bits,DoSvc,TrustedInstaller,msiserver | Select-Object Name,@{n='Status';e={$_.Status.ToString()}},@{n='StartType';e={$_.StartType.ToString()}})
}
Read-Diagnostic 'ActiveWork' {
    @(Get-Process | Where-Object {$_.ProcessName -match '^(dism|TiWorker|TrustedInstaller|MoUsoCoreWorker|msiexec|setup|setuphost|msedge|chrome|firefox|arduino.*)$'} | Group-Object ProcessName | Select-Object Name,Count)
}
Read-Diagnostic 'RestartMarkers' {
    [pscustomobject]@{CBS=(Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending');WindowsUpdate=(Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')}
}
Read-Diagnostic 'DeliveryOptimization' {
    $taskJobs = @(Get-DeliveryOptimizationStatus -ErrorAction Stop | Select-Object FileId,@{n='Status';e={$_.Status.ToString()}},FileSizeInCache,IsPinned)
    [pscustomobject]@{JobCount=$taskJobs.Count;Jobs=$taskJobs}
}
Read-Diagnostic 'PresentDeviceStatus' {
    $taskDevices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop)
    [pscustomobject]@{Total=$taskDevices.Count;ByStatus=@($taskDevices | Group-Object Status | Select-Object Name,Count);NonOK=@($taskDevices | Where-Object Status -ne 'OK' | Select-Object FriendlyName,Class,Status)}
}
if ($IncludeDrivers) {
    Read-Diagnostic 'SignedDrivers' {
        @(Get-CimInstance Win32_PnPSignedDriver | Where-Object {$_.InfName -like 'oem*'} | Select-Object DeviceName,DeviceID,InfName,DriverVersion,DriverProviderName,DeviceClass)
    }
    Read-Diagnostic 'DriverPackages' {
        $taskOutput = & "$env:windir\System32\pnputil.exe" /enum-drivers 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "Driver inventory failed with exit code $LASTEXITCODE." }
        $taskOutput
    }
}
Read-Diagnostic 'ComponentStore' {
    $taskBusy = @(Get-Process dism,TiWorker,TrustedInstaller,MoUsoCoreWorker,msiexec,setup,setuphost -ErrorAction SilentlyContinue)
    $taskRestart = (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    if ($taskBusy.Count -or $taskRestart) {
        [pscustomobject]@{Status='Skipped';Reason='Servicing/installation is active or a restart is pending.'}
    } else {
        $taskDetail = Join-Path $taskRoot 'system-dism-analysis.log'
        $taskOutput = & "$env:windir\System32\dism.exe" /Online /Cleanup-Image /AnalyzeComponentStore /English "/LogPath:$taskDetail" 2>&1 | Out-String
        $taskExit = $LASTEXITCODE
        [pscustomobject]@{Status=if($taskExit -eq 0){'Completed'}else{'Failed'};ExitCode=$taskExit;Output=$taskOutput}
        if ($taskExit -ne 0) { $taskData.Errors += [pscustomobject]@{Check='ComponentStore';Error="DISM analysis exit code $taskExit"} }
    }
}
$taskData.FinishedUtc = [datetime]::UtcNow.ToString('o')
$taskData.Status = if ($taskData.Errors.Count) {'partial'} else {'completed'}
$taskJson = $taskData | ConvertTo-Json -Depth 8
$taskOutputPath = Join-Path $taskRoot 'system-diagnostics.json'
# CreateNew and a validated plain directory prevent overwriting an existing destination.
$taskStream = [IO.File]::Open($taskOutputPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try {
    $taskBytes = [Text.Encoding]::UTF8.GetBytes($taskJson)
    $taskStream.Write($taskBytes,0,$taskBytes.Length)
} finally { $taskStream.Dispose() }
