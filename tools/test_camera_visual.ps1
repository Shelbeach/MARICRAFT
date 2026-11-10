$ErrorActionPreference='Stop'
foreach ($fps in @(60,30)) {
 foreach ($hero in @('human','ogre')) {
  foreach ($form in @(0,1,2)) {
   node tests/camera_repair_visual.mjs "--fps=$fps" "--hero=$hero" "--form=$form" --width=640 --port=18822
   if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
 }
}
