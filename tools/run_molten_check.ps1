param([string]$Name='import',[string]$Script='',[int]$Fps=60,[switch]$Native,[string]$Extra='', [string]$Movie='', [switch]$VerboseEngine,[string]$Resolution='')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$env:APPDATA=Join-Path $projectRoot 'reports/temp/appdata'
$env:LOCALAPPDATA=Join-Path $projectRoot 'reports/temp/local'
$env:TEMP=Join-Path $projectRoot 'reports/temp/molten'
$env:TMP=$env:TEMP
$arguments="--path $projectRoot --disable-vsync --fixed-fps $Fps"
if ($Resolution) { $arguments+=" --resolution $Resolution" }
if ($VerboseEngine) { $arguments+=' --verbose' }
if ($Script) { $arguments+=" --script res://tests/$Script" } else { $arguments+=' --editor --import --headless' }
if (-not $Native -and $Script) { $arguments+=' --headless' }
if ($Movie) { $arguments+=" --write-movie $projectRoot/reports/temp/molten/$Movie.avi" }
if ($Extra) { $arguments+=' -- '+$Extra }
$stdout=Join-Path $projectRoot "reports/evidence/molten/$Name.log"
$stderr=Join-Path $projectRoot "reports/evidence/molten/$Name-errors.log"
$process=Start-Process -FilePath (Join-Path $projectRoot 'reports/temp/engine/godot.windows.opt.tools.64.exe') -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -Wait -PassThru
"$Name exit=$($process.ExitCode)"
Get-Content -LiteralPath $stdout -Tail 8
if ((Get-Item -LiteralPath $stderr).Length) { Get-Content -LiteralPath $stderr -Tail 25 }
exit $process.ExitCode
