# Stop when error
$ErrorActionPreference = 'Stop'

$org = $args[0]
# 1. Deploy source to demo org
sf project deploy start --target-org $org

# 2. Assign the POC permission set
sf org assign permset --name HealthPulse_Email_Draft_POC  --target-org $org
sf org assign permset --name EinsteinGPTPromptTemplateManager  --target-org $org

# 3. Seed mock demo records
sf apex run --file scripts/apex/createMockData.apex --target-org $org
