param(
    [Parameter(Mandatory)]
    [ValidateSet("dev")]
    [string]$Environment
)

$ErrorActionPreference = "Stop"

Write-Host "Initializing Terraform for environment: $Environment"
$configPath = Join-Path $PSScriptRoot "..\environments\$Environment.psd1"
$config = Import-PowerShellDataFile -Path $configPath
Write-Host "Configuration loaded from $configPath"

$accountJson = az account show --output json

if ($LASTEXITCODE -ne 0) {
    throw "Unable to read the Azure account. Run az login and try again."
}

$account = $accountJson | ConvertFrom-Json


$expectedSubscriptionId = $config.SubscriptionId

if ($account.id -ne $expectedSubscriptionId) {
    throw "Wrong Azure subscription. Expected $expectedSubscriptionId, but found $($account.id)."
}

$env:TF_VAR_subscription_id = $expectedSubscriptionId

Write-Host "Subscription verified. Terraform subscription variable set."

Write-Host "Active subscription: $($account.name)"

$storageAccountsJson = az storage account list `
    --subscription $expectedSubscriptionId `
    --resource-group $config.StateResourceGroup `
    --output json

if ($LASTEXITCODE -ne 0) {
    throw "Unable to list backend storage accounts."
}

$storageAccounts = @($storageAccountsJson | ConvertFrom-Json)

if ($storageAccounts.Count -ne 1) {
    throw "Expected exactly one backend storage account; found $($storageAccounts.Count)."
}

$storageAccountName = $storageAccounts[0].name

Write-Host "Backend storage account: $storageAccountName"


terraform init `
    "-backend-config=resource_group_name=$($config.StateResourceGroup)" `
    "-backend-config=storage_account_name=$storageAccountName" `
    "-backend-config=container_name=$($config.StateContainer)" `
    "-backend-config=key=$($config.StateKey)" `
    "-backend-config=subscription_id=$expectedSubscriptionId" `
    "-backend-config=use_azuread_auth=true" `
    "-backend-config=use_cli=true" `
    -reconfigure

if ($LASTEXITCODE -ne 0) {
    throw "Terraform initialization failed."
}