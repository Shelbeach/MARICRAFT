$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
foreach ($rate in @(60,30)) {
  foreach ($hero in @('human','ogre')) {
    foreach ($region in @('forest','durotar','molten')) {
      $flags="--$hero --$rate"
      & "$PSScriptRoot/run_final_polish.ps1" -Name "routes-$region-$hero-$rate" -Script "final_polish_$region.gd" -Fps $rate -Extra $flags
    }
  }
}
