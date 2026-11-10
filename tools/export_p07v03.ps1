param([switch]$Debug)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
$env:APPDATA=Join-Path $projectRoot 'reports/temp/appdata'
$env:LOCALAPPDATA=Join-Path $projectRoot 'reports/temp/local'
$env:TEMP=Join-Path $projectRoot 'reports/temp/p07v03-music'
$env:TMP=$env:TEMP
$name=if($Debug){'p07v03-music'}else{'p07v03-music-release'}
$mode=if($Debug){'--export-debug'}else{'--export-release'}
New-Item -ItemType Directory -Force "exports/$name" | Out-Null
$process=Start-Process -FilePath (Join-Path $projectRoot 'reports/temp/engine/godot.windows.opt.tools.64.exe') -ArgumentList "--headless --path $projectRoot $mode Web $projectRoot/exports/$name/index.html" -WindowStyle Hidden -RedirectStandardOutput "reports/evidence/p07v03-music/export-$name.log" -RedirectStandardError "reports/evidence/p07v03-music/export-$name-errors.log" -Wait -PassThru
"$name exit=$($process.ExitCode)"
Get-Content "reports/evidence/p07v03-music/export-$name-errors.log"
exit $process.ExitCode
