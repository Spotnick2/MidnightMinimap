<#
    run.ps1 - Syntax-check the addon and run every tests\test_*.lua under Lua 5.1,
    through WowTestKit's runner at the commit tests\kit.pin names (its README).

    Usage:
        pwsh tests/run.ps1
        pwsh tests/run.ps1 -Lua "C:\path\to\lua5.1.exe"
        pwsh tests/run.ps1 -KitDev      # the ..\WowTestKit working copy, not the pin
#>

param(
    [string]$Lua = "C:\Program Files (x86)\Lua\5.1\lua.exe",
    [switch]$KitDev
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

# The TOC is the list of addon files (the kit's -Toc); the tests are checked too.
$testFiles = @(Get-ChildItem (Join-Path $PSScriptRoot "*.lua") | ForEach-Object { "tests\$($_.Name)" })

. (Join-Path $PSScriptRoot "kit.ps1")
$kit = Get-WowTestKit -RepoRoot $RepoRoot -KitDev:$KitDev
& (Join-Path $kit "scripts\run.ps1") -RepoRoot $RepoRoot -Toc "MidnightMinimap.toc" -Extra $testFiles -Lua $Lua
exit $LASTEXITCODE
