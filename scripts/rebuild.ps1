param(
    [string]$Vivado='D:\Vivado\Vivado\2024.2\bin',
    [string]$Gowin='E:\Program Files\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe'
)
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot)
python scripts/gen_rom.py
if($LASTEXITCODE) { throw 'ROM generation failed' }
& "$PSScriptRoot\sim_xsim.ps1" -Vivado $Vivado
& "$PSScriptRoot\build.ps1" -Gowin $Gowin
& "$PSScriptRoot\clean.ps1"
Write-Host 'Ready for SRAM download: impl/pnr/synth21.fs'
