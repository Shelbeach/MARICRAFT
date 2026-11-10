$ErrorActionPreference='Stop'
foreach ($rate in @(60,30)) {
 foreach ($hero in @('human','ogre')) {
  foreach ($region in @('forest','durotar','molten')) {
   & "$PSScriptRoot/run_camera_repair.ps1" -Name "routes-$region-$hero-$rate" -Script "camera_repair_$region.gd" -Fps $rate -Extra "--$hero --$rate"
  }
 }
}
