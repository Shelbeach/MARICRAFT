param([string]$Name='camera-repair',[switch]$Release,[string]$Preset="Web",[string]$Stage='camera-repair')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$env:APPDATA=Join-Path $projectRoot 'reports/temp/appdata'
$env:LOCALAPPDATA=Join-Path $projectRoot 'reports/temp/local'
$env:TEMP=Join-Path $projectRoot "reports/temp/$Stage"
$env:TMP=$env:TEMP
New-Item -ItemType Directory -Force "exports/$Name","reports/evidence/$Stage",$env:TEMP | Out-Null
$mode=if($Release){'--export-release'}else{'--export-debug'}
$p=Start-Process -FilePath (Join-Path $projectRoot 'reports/temp/engine/godot.windows.opt.tools.64.exe') -ArgumentList "--headless --path $projectRoot $mode `"$Preset`" $projectRoot/exports/$Name/index.html" -WindowStyle Hidden -RedirectStandardOutput "reports/evidence/$Stage/export-$Name.log" -RedirectStandardError "reports/evidence/$Stage/export-$Name-errors.log" -Wait -PassThru
"$Name exit=$($p.ExitCode)"
Get-Content "reports/evidence/$Stage/export-$Name-errors.log"
exit $p.ExitCode
