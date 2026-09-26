$ErrorActionPreference='Stop'
$projRoot=[System.IO.Path]::GetFullPath((Split-Path $PSScriptRoot))
$targets=@('xsim.dir','.Xil','impl/temp') | ForEach-Object { Join-Path $projRoot $_ }
$targets+=Get-ChildItem -LiteralPath $projRoot -File | Where-Object { $_.Extension -in @('.wdb','.jou','.pb','.log') } | ForEach-Object FullName
$targets+=Get-ChildItem -LiteralPath (Join-Path $projRoot 'reports') -File -Filter '*.backup.log' | ForEach-Object FullName
foreach($item in $targets) {
    $target=[System.IO.Path]::GetFullPath($item)
    if(!$target.StartsWith($projRoot+'\',[System.StringComparison]::OrdinalIgnoreCase)) { throw "Outside project: $target" }
    if(Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
}
Write-Host 'Simulation caches and temporary outputs removed; RTL, bitstream and reports retained.'
