# Stop when error
$ErrorActionPreference = 'Stop'

$org = $args[0]

# Read ENV File
$dotEnvFile = "./scripts/deployments/env/$org.env"
if (!(Test-Path $dotEnvFile)) {
  Write-Error "Environment file $dotEnvFile not found."
  exit 1
}

$envFileItemsArray = Get-Content $dotEnvFile | ForEach-Object { $_ }
foreach ($envItem in $envFileItemsArray) {
  $envName = $envItem.Split('=')[0].Trim()
  $envValue = $envItem.Split('=')[1].Trim()
  [Environment]::SetEnvironmentVariable($envName, $envValue, [EnvironmentVariableTarget]::Process)
  Write-Host "Environment variable $envName set to $envValue"
}

# 1. Deploy source to demo org
sf project deploy start --target-org $org

# 2. Assign the POC permission set
sf org assign permset --name HealthPulse_Email_Draft_POC  --target-org $org
sf org assign permset --name EinsteinGPTPromptTemplateManager  --target-org $org

# 3. Seed mock demo records
sf apex run --file scripts/apex/createMockData.apex --target-org $org