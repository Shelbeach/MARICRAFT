param(
    [string]$Godot = '',
    [string]$Python = '',
    [string]$Output = 'handoff/teacher-2026-11-10',
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if (-not $Godot) { $Godot = Join-Path $projectRoot 'reports/temp/engine/godot.windows.opt.tools.64.exe' }
$Godot = (Resolve-Path -LiteralPath $Godot).Path
$originalAppData = $env:APPDATA
$engineRoot = Split-Path -Parent $Godot
# Resolve the interpreter before isolating LOCALAPPDATA: Python's Windows app
# alias otherwise tries to install another runtime into the temporary profile.
if (-not $Python) { $Python = @(& python -c 'import sys; print(sys.executable)')[-1] }
if (-not (Test-Path -LiteralPath $Python)) { throw 'Python 3 interpreter not found.' }
$target = [IO.Path]::GetFullPath((Join-Path $projectRoot $Output))
if (-not $target.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Output must stay inside the MARICRAFT project.'
}
$tempRoot = Join-Path $projectRoot 'reports/temp/handoff'
$logRoot = Join-Path $projectRoot 'reports/evidence/handoff'
New-Item -ItemType Directory -Force $tempRoot,$logRoot,"$target/web","$target/windows" | Out-Null
$env:APPDATA = Join-Path $tempRoot 'appdata'
$env:LOCALAPPDATA = Join-Path $tempRoot 'local'
$env:TEMP = $tempRoot
$env:TMP = $tempRoot
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null

# Preserve template discovery when a non-portable Godot installation is supplied.
# All copies go to the isolated build profile on D:, never to the real user profile.
$portable = (Test-Path -LiteralPath (Join-Path $engineRoot '_sc_')) -or (Test-Path -LiteralPath (Join-Path $engineRoot '._sc_'))
$templateTarget = if ($portable) {
    Join-Path $engineRoot 'editor_data/export_templates/4.7.2.stable'
} else {
    Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'
}
foreach ($name in @('web_nothreads_release.zip','windows_debug_x86_64.exe')) {
    $dest = Join-Path $templateTarget $name
    if (-not (Test-Path -LiteralPath $dest)) {
        $sources = @(
            (Join-Path $engineRoot "editor_data/export_templates/4.7.2.stable/$name"),
            (Join-Path $originalAppData "Godot/export_templates/4.7.2.stable/$name")
        )
        $source = $sources | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if (-not $source) { throw "Install Godot 4.7.2 Standard export templates first: $name is missing." }
        New-Item -ItemType Directory -Force $templateTarget | Out-Null
        Copy-Item -LiteralPath $source -Destination $dest
    }
}

function Run-Godot([string]$Name, [string]$Arguments) {
    $p = Start-Process -FilePath $Godot -ArgumentList "--headless --path `"$projectRoot`" $Arguments" -WindowStyle Hidden -Wait -PassThru `
        -RedirectStandardOutput "$logRoot/$Name.log" -RedirectStandardError "$logRoot/$Name-errors.log"
    if ($p.ExitCode -ne 0) { throw "Godot $Name failed ($($p.ExitCode)); see $logRoot" }
    if (Select-String -LiteralPath "$logRoot/$Name-errors.log" -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet) {
        throw "Godot reported errors in $Name; see $logRoot"
    }
    Write-Output "$Name OK"
}
Run-Godot 'version' '--version'
$version = (Get-Content -LiteralPath "$logRoot/version.log" -Raw).Trim()
if (-not $version.StartsWith('4.7.2.stable.')) { throw "This delivery requires Godot 4.7.2 Standard; found $version" }
if ($CheckOnly) { Write-Output 'Engine, Python and export templates are ready.'; exit 0 }
Run-Godot 'import' '--editor --import'
Run-Godot 'web-release' "--export-release `"Web`" `"$target/web/index.html`""
Run-Godot 'windows-teacher' "--export-debug `"Windows Teacher`" `"$target/windows/MARICRAFT.exe`""
& $Python tools/package_handoff.py --output $target
if ($LASTEXITCODE -ne 0) { throw 'Packaging failed.' }
