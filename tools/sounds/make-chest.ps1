# Synthesizes the treasure chest opening sound: a low creak-thump and then a sparkling rising arpeggio, as a WAV file. Plain maths,
# nothing to license. Run again to regenerate mobile/kids_english_app/assets/audio/ui/chest-open.wav.
param([string]$Out = (Join-Path $PSScriptRoot '..\..\mobile\kids_english_app\assets\audio\ui\chest-open.wav'))
$rate = 22050
$total = 1.5
$samples = New-Object 'double[]' ([int]($rate * $total))
function Add-Tone($start, $len, $f, $amp, $decayRate, $octave) {
  $s0 = [int]($start * $rate); $n = [int]($len * $rate)
  for ($i = 0; $i -lt $n -and ($s0 + $i) -lt $samples.Length; $i++) {
    $t = $i / $rate
    $env = [Math]::Min(1.0, $i / ($rate * 0.008)) * [Math]::Exp(-$decayRate * $i / $n)
    $v = [Math]::Sin(2 * [Math]::PI * $f * $t) + $octave * [Math]::Sin(4 * [Math]::PI * $f * $t)
    $samples[$s0 + $i] += $v * $env * $amp
  }
}
# the creak: a short falling tone, and the thump of the lid
for ($i = 0; $i -lt [int]($rate * 0.35); $i++) {
  $t = $i / $rate; $f = 140 - 90 * ($t / 0.35)
  $samples[$i] += [Math]::Sin(2 * [Math]::PI * $f * $t) * [Math]::Exp(-4 * $t / 0.35) * 0.30 * (0.7 + 0.3 * [Math]::Sin(60 * $t))
}
Add-Tone 0.30 0.25 70 0.35 6 0
# the sparkle: C5 E5 G5 C6 E6 G6
$notes = 523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0
for ($k = 0; $k -lt $notes.Length; $k++) { Add-Tone (0.40 + 0.10 * $k) 0.45 $notes[$k] 0.16 5 0.3 }
$pcm = New-Object 'int16[]' $samples.Length
for ($i = 0; $i -lt $samples.Length; $i++) { $pcm[$i] = [int16][Math]::Max(-32768, [Math]::Min(32767, [int]($samples[$i] * 32767))) }
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$ms = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter($ms)
$dataLen = $pcm.Length * 2
$w.Write([Text.Encoding]::ASCII.GetBytes('RIFF')); $w.Write([int](36 + $dataLen)); $w.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
$w.Write([Text.Encoding]::ASCII.GetBytes('fmt ')); $w.Write([int]16); $w.Write([int16]1); $w.Write([int16]1)
$w.Write([int]$rate); $w.Write([int]($rate * 2)); $w.Write([int16]2); $w.Write([int16]16)
$w.Write([Text.Encoding]::ASCII.GetBytes('data')); $w.Write([int]$dataLen)
foreach ($s in $pcm) { $w.Write([int16]$s) }
$w.Flush()
[IO.File]::WriteAllBytes($Out, $ms.ToArray())
Write-Output "Wrote $Out ($($ms.Length) bytes)"
