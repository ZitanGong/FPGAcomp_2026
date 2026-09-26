param([string]$Gowin='E:\Program Files\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe')
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot)
& $Gowin scripts/build.tcl
if($LASTEXITCODE) { throw 'Gowin build failed' }
python scripts/check_reports.py
if($LASTEXITCODE) { throw 'Resource/timing/verification check failed' }
