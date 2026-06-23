param(
    [Parameter(Mandatory = $true)] [string]$WavPath,
    [string]$ModelPath,
    [string]$WhisperCli,
    [string]$Language   = "auto",
    [int]$Threads       = 0
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSCommandPath
$projectRoot = Split-Path -Parent $root
if (-not $ModelPath)  { $ModelPath  = Join-Path $projectRoot 'models\ggml-base.bin' }
if (-not $WhisperCli) { $WhisperCli = Join-Path $projectRoot 'bin\Release\whisper-cli.exe' }

if (-not (Test-Path $WavPath))     { Write-Error "WAV not found: $WavPath"; exit 2 }
if (-not (Test-Path $ModelPath))   { Write-Error "Model not found: $ModelPath"; exit 2 }
if (-not (Test-Path $WhisperCli))  { Write-Error "whisper-cli not found: $WhisperCli"; exit 2 }

if ($Threads -le 0) { $Threads = [Math]::Max(4, [Environment]::ProcessorCount - 2) }

$args = @(
    '-m', $ModelPath,
    '-f', $WavPath,
    '-l', $Language,
    '-t', $Threads,
    '--no-prints',
    '--no-timestamps',
    '-nf',
    '--suppress-nst'
)

$prevPref = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$out = & $WhisperCli @args 2>$null
$rc = $LASTEXITCODE
$ErrorActionPreference = $prevPref
if ($rc -ne 0) { exit $rc }

$text = ($out -join "`n").Trim()

$text = $text -replace '\s*\[BLANK_AUDIO\]\s*', ''
$text = $text -replace '\s*\(.*?\)\s*', ''
$text = $text -replace '\s*\[.*?\]\s*', ''
$text = $text.Trim()

Write-Output $text
