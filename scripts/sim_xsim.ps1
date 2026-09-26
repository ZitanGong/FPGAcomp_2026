param([string]$Vivado='D:\Vivado\Vivado\2024.2\bin', [string[]]$Tests=@('tb_key','tb_map','tb_env','tb_mix','tb_i2s','tb_synth','tb_core','tb_pt','tb_div','tb_pt_core','tb_board','tb_key_fault','tb_quality'))
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot)
New-Item -ItemType Directory -Force reports | Out-Null
$files = Get-ChildItem src/key,src/synth,src/audio -Filter *.v | ForEach-Object FullName
$testFiles = Get-ChildItem sim -Filter *.sv | ForEach-Object FullName
& "$Vivado\xvlog.bat" @files src/audio_core.v
if($LASTEXITCODE) { throw 'RTL compile failed' }
& "$Vivado\xvlog.bat" 'E:\Program Files\Gowin\Gowin_V1.9.12.03_x64\IDE\simlib\gw5a\prim_sim.v' src/clock/reset_sync.v src/top.v
if($LASTEXITCODE) { throw 'Board RTL compile failed' }
& "$Vivado\xvlog.bat" --sv @testFiles
if($LASTEXITCODE) { throw 'test compile failed' }
foreach($tb in $Tests) {
    & "$Vivado\xelab.bat" --timescale 1ns/1ps --debug typical "work.$tb" -s $tb
    if($LASTEXITCODE) { throw "$tb elaboration failed" }
    & "$Vivado\xsim.bat" $tb -tclbatch sim/run.tcl -log "reports/$tb.log"
    if($LASTEXITCODE -or !(Select-String -LiteralPath "reports/$tb.log" -Pattern "PASS $tb" -Quiet)) { throw "$tb failed" }
}
if($Tests -contains 'tb_synth') {
    python scripts/check_audio.py
    if($LASTEXITCODE) { throw 'spectrum check failed' }
}

if($Tests -contains 'tb_quality') {
    python scripts/check_quality.py
    if($LASTEXITCODE) { throw 'Quality check failed' }
}
