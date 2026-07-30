$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path "$root/FactoryForge/Assets")) {
  $root = Resolve-Path (Join-Path $PSScriptRoot "../..")
}
$src = Join-Path $root "FactoryForge/Assets"
$dst = Join-Path $root "web/public/assets"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Path "$src/*.png" -Destination $dst -Force
$names = Get-ChildItem $dst -Filter *.png | ForEach-Object { $_.BaseName } | Sort-Object
$names | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $dst "manifest.json")
Write-Host "Synced $($names.Count) PNGs to web/public/assets"
