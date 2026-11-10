param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Script,
    [int]$Fps=60,
    [switch]$Native,
    [string]$Extra=''
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$env:APPDATA=Join-Path $projectRoot 'reports/temp/appdata'
$env:LOCALAPPDATA=Join-Path $projectRoot 'reports/temp/local'
$env:TEMP=Join-Path $projectRoot 'reports/temp/p06'
$env:TMP=$env:TEMP
$arguments="--path $projectRoot --script res://tests/$Script --disable-vsync --fixed-fps $Fps"
if (-not $Native) { $arguments+=' --headless' }
if ($Extra) { $arguments+=' -- '+$Extra }
$stdout=Join-Path $projectRoot "reports/evidence/p06/$Name.log"
$stderr=Join-Path $projectRoot "reports/evidence/p06/$Name-errors.log"
$process=Start-Process -FilePath (Join-Path $projectRoot 'reports/temp/engine/godot.windows.opt.tools.64.exe') -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -Wait -PassThru
"$Name exit=$($process.ExitCode)"
Get-Content -LiteralPath $stdout -Tail 4
if ((Get-Item -LiteralPath $stderr).Length) { Get-Content -LiteralPath $stderr -Tail 15 }
exit $process.ExitCode
