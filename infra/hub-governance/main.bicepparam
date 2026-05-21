using './main.bicep'

param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus2')
param resourceGroupName = readEnvironmentVariable('AZURE_RESOURCE_GROUP', 'rg-ai-gov-hub-dev')
param tags = {
  Environment: readEnvironmentVariable('ENVIRONMENT', 'dev')
  Workload: 'ai-governance-hub'
  ManagedBy: 'bicep'
}

param vnetName = readEnvironmentVariable('VNET_NAME', '')
param vnetAddressPrefixes = [
  readEnvironmentVariable('VNET_ADDRESS_PREFIX', '10.170.0.0/24')
]
param apimSubnetName = readEnvironmentVariable('APIM_SUBNET_NAME', 'snet-apim')
param apimSubnetPrefix = readEnvironmentVariable('APIM_SUBNET_PREFIX', '10.170.0.0/26')
param privateEndpointSubnetName = readEnvironmentVariable('PRIVATE_ENDPOINT_SUBNET_NAME', 'snet-private-endpoints')
param privateEndpointSubnetPrefix = readEnvironmentVariable('PRIVATE_ENDPOINT_SUBNET_PREFIX', '10.170.0.64/26')
param integrationSubnetName = readEnvironmentVariable('INTEGRATION_SUBNET_NAME', 'snet-integration')
param integrationSubnetPrefix = readEnvironmentVariable('INTEGRATION_SUBNET_PREFIX', '10.170.0.128/26')

param deployPrivateDnsZones = bool(readEnvironmentVariable('DEPLOY_PRIVATE_DNS_ZONES', 'true'))
param privateDnsZoneResourceIds = {
  blob: readEnvironmentVariable('DNS_ZONE_BLOB_ID', '')
  keyVault: readEnvironmentVariable('DNS_ZONE_KEYVAULT_ID', '')
  cosmos: readEnvironmentVariable('DNS_ZONE_COSMOS_ID', '')
  eventHub: readEnvironmentVariable('DNS_ZONE_EVENTHUB_ID', '')
  cognitiveServices: readEnvironmentVariable('DNS_ZONE_COGNITIVE_ID', '')
  openAi: readEnvironmentVariable('DNS_ZONE_OPENAI_ID', '')
  aiServices: readEnvironmentVariable('DNS_ZONE_AISERVICES_ID', '')
  apim: readEnvironmentVariable('DNS_ZONE_APIM_ID', '')
}
param deployPrivateEndpoints = bool(readEnvironmentVariable('DEPLOY_PRIVATE_ENDPOINTS', 'true'))

param logAnalyticsWorkspaceName = readEnvironmentVariable('LOG_ANALYTICS_NAME', '')
param applicationInsightsName = readEnvironmentVariable('APPLICATION_INSIGHTS_NAME', '')
param storageAccountName = readEnvironmentVariable('STORAGE_ACCOUNT_NAME', '')
param keyVaultName = readEnvironmentVariable('KEY_VAULT_NAME', '')

param deployEventHub = bool(readEnvironmentVariable('DEPLOY_EVENT_HUB', 'true'))
param eventHubNamespaceName = readEnvironmentVariable('EVENTHUB_NAMESPACE_NAME', '')
param eventHubName = readEnvironmentVariable('EVENTHUB_NAME', 'ai-usage')

param deployCosmosDb = bool(readEnvironmentVariable('DEPLOY_COSMOS_DB', 'true'))
param cosmosDbAccountName = readEnvironmentVariable('COSMOS_DB_ACCOUNT_NAME', '')
param cosmosDbDatabaseName = readEnvironmentVariable('COSMOS_DB_DATABASE_NAME', 'governance')
param cosmosDbContainerName = readEnvironmentVariable('COSMOS_DB_CONTAINER_NAME', 'usage')

param deployAiFoundry = bool(readEnvironmentVariable('DEPLOY_AI_FOUNDRY', 'true'))
param aiFoundryAccountName = readEnvironmentVariable('AI_FOUNDRY_ACCOUNT_NAME', '')
param aiFoundryProjectName = readEnvironmentVariable('AI_FOUNDRY_PROJECT_NAME', 'governance-project')
param aiFoundryCustomSubdomain = readEnvironmentVariable('AI_FOUNDRY_CUSTOM_SUBDOMAIN', '')
param disableAiFoundryLocalAuth = bool(readEnvironmentVariable('AI_FOUNDRY_DISABLE_LOCAL_AUTH', 'true'))

param apiManagementName = readEnvironmentVariable('APIM_NAME', '')
param apiManagementPublisherName = readEnvironmentVariable('APIM_PUBLISHER_NAME', 'Platform Team')
param apiManagementPublisherEmail = readEnvironmentVariable('APIM_PUBLISHER_EMAIL', 'platform@example.com')
param apiManagementSkuName = readEnvironmentVariable('APIM_SKU_NAME', 'Developer')
param apiManagementSkuCapacity = int(readEnvironmentVariable('APIM_SKU_CAPACITY', '1'))
param apiManagementVirtualNetworkType = readEnvironmentVariable('APIM_VNET_TYPE', 'External')
param apiManagementPublicNetworkAccess = readEnvironmentVariable('APIM_PUBLIC_NETWORK_ACCESS', 'Enabled')
param enableApimPrivateEndpoint = bool(readEnvironmentVariable('ENABLE_APIM_PRIVATE_ENDPOINT', 'false'))
