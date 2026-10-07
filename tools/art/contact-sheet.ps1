# Tiles the PNG files of a folder into one overview picture (device screenshots of a long scrolling screen, in order).
param([string]$Folder, [string]$Out, [int]$Columns = 7, [int]$TileWidth = 300)
Add-Type -AssemblyName System.Drawing
$files = Get-ChildItem $Folder -Filter *.png | Sort-Object Name
$first = [System.Drawing.Image]::FromFile($files[0].FullName)
$th = [int]($TileWidth * $first.Height / $first.Width); $first.Dispose()
$rows = [Math]::Ceiling($files.Count / $Columns)
$bmp = New-Object System.Drawing.Bitmap ($Columns * $TileWidth), ($rows * $th)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = 'HighQualityBicubic'
$g.Clear([System.Drawing.Color]::White)
for ($i = 0; $i -lt $files.Count; $i++) {
  $img = [System.Drawing.Image]::FromFile($files[$i].FullName)
  $g.DrawImage($img, ($i % $Columns) * $TileWidth, [Math]::Floor($i / $Columns) * $th, $TileWidth, $th)
  $img.Dispose()
}
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "Wrote $Out"
