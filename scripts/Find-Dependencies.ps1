# Compatible with Windows PowerShell 5.1. Discovery never installs or changes settings.
function Find-CleanupPowerShell {
    $command=Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    foreach($path in @($command.Source,"$env:ProgramFiles\PowerShell\7\pwsh.exe","$env:USERPROFILE\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe")){
        if($path -and (Test-Path -LiteralPath $path -PathType Leaf) -and [Diagnostics.FileVersionInfo]::GetVersionInfo($path).FileMajorPart -ge 7){return $path}
    }
    if(Get-Command Get-AppxPackage -ErrorAction SilentlyContinue){
        foreach($package in @(Get-AppxPackage -Name 'Microsoft.PowerShell*' -ErrorAction SilentlyContinue | Sort-Object Version -Descending)){
            $path=Join-Path $package.InstallLocation 'pwsh.exe'
            if((Test-Path -LiteralPath $path -PathType Leaf) -and [Diagnostics.FileVersionInfo]::GetVersionInfo($path).FileMajorPart -ge 7){return $path}
        }
    }
}
function Find-CleanupCodex {
    $command=Get-Command codex.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if($command){return $command.Source}
    $path="$env:LOCALAPPDATA\Programs\OpenAI\Codex\bin\codex.exe"
    if(Test-Path -LiteralPath $path -PathType Leaf){return $path}
    foreach($root in @("$env:LOCALAPPDATA\OpenAI\Codex\bin","$env:APPDATA\npm\node_modules\@openai")){
        $file=Get-ChildItem -LiteralPath $root -Filter codex.exe -Recurse -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if($file){return $file.FullName}
    }
}
