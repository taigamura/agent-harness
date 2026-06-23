param(
    [ValidateSet('base','small','large-v3-turbo')] [string]$Model = 'base'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $root

$dirs = @('bin','models','tmp','scripts')
foreach ($d in $dirs) {
    $p = Join-Path $projectRoot $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}

$binDir = Join-Path $projectRoot 'bin'
$whisperCli = Join-Path $binDir 'Release\whisper-cli.exe'
if (-not (Test-Path $whisperCli)) {
    Write-Host "Downloading whisper.cpp v1.9.1 (BLAS, x64)..."
    $zip = Join-Path $projectRoot 'tmp\whisper-blas.zip'
    Invoke-WebRequest -Uri 'https://github.com/ggml-org/whisper.cpp/releases/download/v1.9.1/whisper-blas-bin-x64.zip' -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $binDir -Force
    Remove-Item $zip
} else {
    Write-Host "whisper-cli already installed."
}

$ffmpegExe = Join-Path $binDir 'Release\ffmpeg.exe'
if (-not (Test-Path $ffmpegExe)) {
    Write-Host "ffmpeg not bundled. Run: winget install -e --id Gyan.FFmpeg"
    Write-Host "Then copy ffmpeg.exe into bin\Release\."
} else {
    Write-Host "ffmpeg already installed."
}

$modelFile = Join-Path $projectRoot ('models\ggml-{0}.bin' -f $Model)
if (-not (Test-Path $modelFile)) {
    $url = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-{0}.bin' -f $Model
    Write-Host "Downloading model $Model from $url..."
    Invoke-WebRequest -Uri $url -OutFile $modelFile
} else {
    Write-Host "Model $Model already present."
}

Write-Host ""
Write-Host "Setup complete. Test with:"
Write-Host "  powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\record-test.ps1"
Write-Host ""
Write-Host "Launch the push-to-talk daemon with:"
Write-Host "  .\start.bat"
