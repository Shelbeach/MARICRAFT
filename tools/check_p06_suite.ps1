param([int]$Group=1)
$checks = if ($Group -eq 1) {
    @(
        @('routes-ogre-60','s04_routes.gd',60,'--ogre'),
        @('routes-human-30','s04_routes.gd',30,''),
        @('branches-human-30','durotar_revision_branches.gd',30,''),
        @('branches-ogre-60','durotar_revision_branches.gd',60,'--ogre')
    )
} else {
    @(
        @('branches-ogre-30','durotar_revision_branches.gd',30,'--ogre'),
        @('blocks-60','durotar_revision_blocks.gd',60,''),
        @('blocks-30','durotar_revision_blocks.gd',30,''),
        @('hat-contract-60','durotar_revision_contract.gd',60,''),
        @('hat-contract-30','durotar_revision_contract.gd',30,''),
        @('mechanics','s04_mechanics.gd',60,''),
        @('animation-contract','animation_regression.gd',60,''),
        @('first-chapter-visual','visual_polish_contract.gd',60,'')
    )
}
$failedChecks=@()
foreach ($check in $checks) {
    & "$PSScriptRoot/run_p06_check.ps1" -Name $check[0] -Script $check[1] -Fps $check[2] -Extra $check[3]
    if ($LASTEXITCODE -ne 0) { $failedChecks+=$check[0] }
}
"SUITE $Group failed: $($failedChecks -join ', ')"
if ($failedChecks.Count) { exit 1 }
