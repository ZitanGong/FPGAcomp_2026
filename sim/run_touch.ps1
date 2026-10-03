param(
    [string]$ModelSim='D:\altera\14.1\modelsim_ase\win32aloem',
    [string]$Gowin='E:\Program Files\Gowin\Gowin_V1.9.12.03_x64\IDE',
    [switch]$Board
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    New-Item -ItemType Directory -Force sim_out | Out-Null
    & "$ModelSim\vlib.exe" sim_out/work
    if($LASTEXITCODE) { throw 'vlib failed' }
    $rtl=(Get-ChildItem src -Recurse -Filter *.v).FullName
    $tb=@('sim/mpr_model.sv','sim/hc165.sv','sim/tb_touch.sv','sim/tb_touch_map.sv','sim/tb_touch_speed.sv')
    if($Board) { $tb+=@('sim/tb_board.sv',"$Gowin/simlib/gw5a/prim_sim.v") }
    & "$ModelSim\vlog.exe" -sv -timescale '1ns/1ps' -work sim_out/work @rtl @tb
    if($LASTEXITCODE) { throw 'vlog failed' }
    $names=@('tb_touch','tb_touch_first1','tb_touch_map','tb_touch_speed')
    if($Board) { $names+='tb_board' }
    foreach($name in $names) {
        & "$ModelSim\vsim.exe" -c -lib sim_out/work $name -l "sim_out/$name.log" -do 'run -all; quit -f'
        $log=Get-Content "sim_out/$name.log" -Raw
        if($LASTEXITCODE -or $log -notmatch "PASS $name" -or $log -match '\*\* (Fatal|Error):') {
            throw "$name failed; inspect sim_out/$name.log"
        }
    }
} finally { Pop-Location }
