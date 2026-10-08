# Prepares the folders the hosted API serves next to its files: only the newest version of every content pack (packs/) and the
# printable parent cards (cards/). Upload the two folders to the root of the site (next to KidsEnglish.Api.dll) after publishing.
#   scripts/prepare-host-content.ps1            -> dist/host-content/packs and dist/host-content/cards
param([string]$Out = (Join-Path $PSScriptRoot '..\dist\host-content'))
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $Out 'packs'), (Join-Path $Out 'cards') | Out-Null
$count = 0
foreach ($trackDir in Get-ChildItem (Join-Path $root 'packs') -Directory) {
    $indexFile = Join-Path $trackDir.FullName 'index.json'
    if (-not (Test-Path $indexFile)) { continue }
    $dest = Join-Path $Out "packs\$($trackDir.Name)"
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item $indexFile $dest
    foreach ($pack in (Get-Content $indexFile -Raw | ConvertFrom-Json).packs) {
        $versionDir = Split-Path (Join-Path $trackDir.FullName $pack.manifest) -Parent   # packs/<track>/<unit>/v<N>
        $rel = $versionDir.Substring($trackDir.FullName.Length).TrimStart('\')
        Copy-Item $versionDir (Join-Path $dest $rel) -Recurse -Force
        $count++
    }
}
Copy-Item (Join-Path $root 'cards\*') (Join-Path $Out 'cards') -Recurse -Force
$size = [math]::Round(((Get-ChildItem $Out -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1)
Write-Host "Prepared $count packs and the cards in $Out ($size MB). Upload the 'packs' and 'cards' folders to the site root."
