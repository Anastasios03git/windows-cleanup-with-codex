# Compatibility entry point.
param([switch]$ValidateOnly)
& (Join-Path $PSScriptRoot 'Show-Setup.ps1') -ValidateOnly:$ValidateOnly
