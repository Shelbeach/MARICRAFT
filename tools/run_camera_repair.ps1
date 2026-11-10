param([string]$Name='import',[string]$Script='', [int]$Fps=60, [string]$Extra='', [switch]$Editor,[string]$Pack='',[string]$Stage='camera-repair')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$env:APPDATA=Join-Path $projectRoot 'reports/temp/appdata'
$env:LOCALAPPDATA=Join-Path $projectRoot 'reports/temp/local'
$env:TEMP=Join-Path $projectRoot "reports/temp/$Stage"
$env:TMP=$env:TEMP
New-Item -ItemType Directory -Force $env:TEMP,"reports/evidence/$Stage" | Out-Null
$arguments="--headless --path $projectRoot --fixed-fps $Fps"
if ($Editor) { $arguments+=' --editor' }
if ($Pack) { $arguments+=" --main-pack $projectRoot/$Pack" }
if ($Script) { $arguments+=" --script $projectRoot/tests/$Script" } else { $arguments+=' --editor --import' }
if ($Extra) { $arguments+=' -- '+$Extra }
$stdout=Join-Path $projectRoot "reports/evidence/$Stage/$Name.log"
$stderr=Join-Path $projectRoot "reports/evidence/$Stage/$Name-errors.log"
$process=Start-Process -FilePath (Join-Path $projectRoot 'reports/temp/engine/godot.windows.opt.tools.64.exe') -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -Wait -PassThru
"$Name exit=$($process.ExitCode)"
Get-Content -LiteralPath $stdout -Tail 8
if ((Get-Item -LiteralPath $stderr).Length) { Get-Content -LiteralPath $stderr -Tail 20 }
exit $process.ExitCode
