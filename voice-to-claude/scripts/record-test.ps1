param(
    [int]$Seconds = 5,
    [string]$Device = "Microphone Array (Intel® Smart Sound Technology for Digital Microphones)"
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $root
$ffmpeg = Join-Path $projectRoot 'bin\Release\ffmpeg.exe'
$out    = Join-Path $projectRoot 'tmp\test-recording.wav'

if (-not (Test-Path (Split-Path $out))) { New-Item -ItemType Directory -Path (Split-Path $out) | Out-Null }

Write-Host "Recording $Seconds seconds from: $Device"
Write-Host "Speak now..."

$prevPref = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $ffmpeg -hide_banner -loglevel error -y `
    -f dshow -i "audio=$Device" `
    -ac 1 -ar 16000 -acodec pcm_s16le `
    -t $Seconds $out 2>&1 | Out-Null
$ErrorActionPreference = $prevPref

if (-not (Test-Path $out)) {
    Write-Error "Recording failed."
    exit 1
}

$size = (Get-Item $out).Length
Write-Host "Captured $size bytes -> $out"
Write-Host ""
Write-Host "Transcribing..."

& (Join-Path $root 'transcribe.ps1') -WavPath $out
