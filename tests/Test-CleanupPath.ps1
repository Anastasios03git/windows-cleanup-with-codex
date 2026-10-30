#Requires -Version 7.0
param([Parameter(Mandatory)][string]$TestRoot)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($TestRoot)
if(Test-Path -LiteralPath $root){throw 'Choose a new test directory.'}
New-Item -ItemType Directory -Path (Join-Path $root 'real') -Force | Out-Null
$helper=Join-Path (Split-Path $PSScriptRoot) 'scripts/Test-CleanupPath.ps1'
$result=& $helper -LiteralPath (Join-Path $root 'real')
if(-not $result.Safe){throw 'Normal path rejected.'}
$result=& $helper -LiteralPath (Join-Path $root 'missing')
if($result.Safe){throw 'Missing path accepted.'}
New-Item -ItemType Junction -Path (Join-Path $root 'junction') -Target (Join-Path $root 'real') | Out-Null
$result=& $helper -LiteralPath (Join-Path $root 'junction')
if($result.Safe -or $result.Reason -notmatch 'Reparse'){throw 'Junction not rejected.'}
'PASS: existing path accepted; missing path and junction rejected without traversal loops.'
