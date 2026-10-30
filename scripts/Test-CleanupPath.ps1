#Requires -Version 7.0
param([Parameter(Mandatory)][string]$LiteralPath)
$ErrorActionPreference='Stop'
try {
    $path=[IO.Path]::GetFullPath($LiteralPath)
    $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    for($depth=0;$depth -lt 128;$depth++){
        if(-not $seen.Add($path)){throw 'Parent traversal did not advance.'}
        $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if($item.PSProvider.Name -ne 'FileSystem'){throw 'Only filesystem paths are supported.'}
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Reparse point encountered: $path"}
        $parent=[IO.Directory]::GetParent($path)
        if($null -eq $parent){return [pscustomobject]@{Safe=$true;Path=[IO.Path]::GetFullPath($LiteralPath);Reason='Target and ancestors checked.'}}
        $path=$parent.FullName
    }
    throw 'Parent traversal exceeded 128 steps.'
}catch{[pscustomobject]@{Safe=$false;Path=$LiteralPath;Reason=$_.Exception.Message}}
