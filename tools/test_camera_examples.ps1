$ErrorActionPreference='Stop'
foreach ($mode in @('elevation','long','boss')) {
 foreach ($variant in @('before','after')) {
  $flags=@("--mode=$mode",'--form=1','--port=18823')
  if ($variant -eq 'before') { $flags+='--before' }
  node tests/camera_repair_visual.mjs @flags
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
 }
}
