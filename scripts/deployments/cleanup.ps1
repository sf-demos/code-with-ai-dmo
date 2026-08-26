# Stop on error
$ErrorActionPreference = 'Stop'

$org = $args[0]
if (-not $org) {
    $org = 'demo_org'
}

Write-Host "Running demo data cleanup on org: $org"
sf apex run --file scripts/apex/cleanupData.apex --target-org $org
