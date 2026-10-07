# Synthesizes the short "cheerful" tap sound (a rising three-note chime) as a WAV file. Plain maths, no sample library,
# nothing to license: run it again to regenerate mobile/kids_english_app/assets/audio/ui/cheer.wav.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\mobile\kids_english_app\assets\audio\ui\cheer.wav'))
$rate = 22050
$notes = @(@(523.25, 0.00, 0.22), @(659.25, 0.11, 0.24), @(783.99, 0.22, 0.40)) # frequency, start, length (seconds)
$total = 0.70
$samples = New-Object 'int16[]' ([int]($rate * $total))
foreach ($n in $notes) {
  $f = $n[0]; $start = [int]($n[1] * $rate); $len = [int]($n[2] * $rate)
  for ($i = 0; $i -lt $len -and ($start + $i) -lt $samples.Length; $i++) {
    $t = $i / $rate
    $attack = [Math]::Min(1.0, $i / ($rate * 0.01))
    $decay = [Math]::Exp(-7.0 * $i / $len)
    # a pure tone plus a soft octave on top: bell-like
    $v = ([Math]::Sin(2 * [Math]::PI * $f * $t) + 0.35 * [Math]::Sin(4 * [Math]::PI * $f * $t)) * $attack * $decay * 0.28
    $s = [int]($samples[$start + $i] + $v * 32767)
    $samples[$start + $i] = [int16][Math]::Max(-32768, [Math]::Min(32767, $s))
  }
}
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$ms = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter($ms)
$dataLen = $samples.Length * 2
$w.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $w.Write([int](36 + $dataLen)); $w.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
$w.Write([Text.Encoding]::ASCII.GetBytes('fmt ')); $w.Write([int]16); $w.Write([int16]1); $w.Write([int16]1)
$w.Write([int]$rate); $w.Write([int]($rate * 2)); $w.Write([int16]2); $w.Write([int16]16)
$w.Write([Text.Encoding]::ASCII.GetBytes('data')); $w.Write([int]$dataLen)
foreach ($s in $samples) { $w.Write([int16]$s) }
$w.Flush()
[IO.File]::WriteAllBytes($Out, $ms.ToArray())
Write-Output "Wrote $Out ($($ms.Length) bytes)"
