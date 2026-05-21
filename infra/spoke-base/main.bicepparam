using './main.bicep'

param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus2')
param resourceGroupName = readEnvironmentVariable('AZURE_RESOURCE_GROUP', 'rg-ai-spoke-dev')
param tags = {
  Environment: readEnvironmentVariable('ENVIRONMENT', 'dev')
  Workload: 'ai-spoke-base'
  ManagedBy: 'bicep'
}

param vnetName = readEnvironmentVariable('VNET_NAME', '')
param vnetAddressPrefixes = [
  readEnvironmentVariable('VNET_ADDRESS_PREFIX', '10.180.0.0/24')
]
param privateEndpointSubnetName = readEnvironmentVariable('PRIVATE_ENDPOINT_SUBNET_NAME', 'snet-private-endpoints')
param privateEndpointSubnetPrefix = readEnvironmentVariable('PRIVATE_ENDPOINT_SUBNET_PREFIX', '10.180.0.0/26')
param agentSubnetName = readEnvironmentVariable('AGENT_SUBNET_NAME', 'snet-agents')
param agentSubnetPrefix = readEnvironmentVariable('AGENT_SUBNET_PREFIX', '10.180.0.64/26')
param applicationSubnetName = readEnvironmentVariable('APPLICATION_SUBNET_NAME', 'snet-app')
param applicationSubnetPrefix = readEnvironmentVariable('APPLICATION_SUBNET_PREFIX', '10.180.0.128/26')
param managementSubnetName = readEnvironmentVariable('MANAGEMENT_SUBNET_NAME', 'snet-management')
param managementSubnetPrefix = readEnvironmentVariable('MANAGEMENT_SUBNET_PREFIX', '10.180.0.192/26')

param createRouteTable = bool(readEnvironmentVariable('CREATE_ROUTE_TABLE', 'false'))
param hubFirewallPrivateIp = readEnvironmentVariable('HUB_FIREWALL_PRIVATE_IP', '')
param createSpokeToHubPeering = bool(readEnvironmentVariable('CREATE_SPOKE_TO_HUB_PEERING', 'false'))
param hubVnetResourceId = readEnvironmentVariable('HUB_VNET_RESOURCE_ID', '')
param useRemoteGatewaysOnSpoke = bool(readEnvironmentVariable('USE_REMOTE_GATEWAYS_ON_SPOKE', 'false'))

param deployPrivateDnsZones = bool(readEnvironmentVariable('DEPLOY_PRIVATE_DNS_ZONES', 'true'))
param privateDnsZoneResourceIds = {
  blob: readEnvironmentVariable('DNS_ZONE_BLOB_ID', '')
  keyVault: readEnvironmentVariable('DNS_ZONE_KEYVAULT_ID', '')
  cognitiveServices: readEnvironmentVariable('DNS_ZONE_COGNITIVE_ID', '')
  openAi: readEnvironmentVariable('DNS_ZONE_OPENAI_ID', '')
  aiServices: readEnvironmentVariable('DNS_ZONE_AISERVICES_ID', '')
  search: readEnvironmentVariable('DNS_ZONE_SEARCH_ID', '')
  cosmos: readEnvironmentVariable('DNS_ZONE_COSMOS_ID', '')
  acr: readEnvironmentVariable('DNS_ZONE_ACR_ID', '')
}
param deployPrivateEndpoints = bool(readEnvironmentVariable('DEPLOY_PRIVATE_ENDPOINTS', 'true'))

param logAnalyticsWorkspaceName = readEnvironmentVariable('LOG_ANALYTICS_NAME', '')
param applicationInsightsName = readEnvironmentVariable('APPLICATION_INSIGHTS_NAME', '')
param storageAccountName = readEnvironmentVariable('STORAGE_ACCOUNT_NAME', '')
param keyVaultName = readEnvironmentVariable('KEY_VAULT_NAME', '')

param aiFoundryAccountName = readEnvironmentVariable('AI_FOUNDRY_ACCOUNT_NAME', '')
param aiFoundryProjectName = readEnvironmentVariable('AI_FOUNDRY_PROJECT_NAME', 'spoke-project')
param aiFoundryCustomSubdomain = readEnvironmentVariable('AI_FOUNDRY_CUSTOM_SUBDOMAIN', '')
param disableAiFoundryLocalAuth = bool(readEnvironmentVariable('AI_FOUNDRY_DISABLE_LOCAL_AUTH', 'true'))

param deployAiSearch = bool(readEnvironmentVariable('DEPLOY_AI_SEARCH', 'false'))
param aiSearchServiceName = readEnvironmentVariable('AI_SEARCH_NAME', '')

param deployCosmosDb = bool(readEnvironmentVariable('DEPLOY_COSMOS_DB', 'false'))
param cosmosDbAccountName = readEnvironmentVariable('COSMOS_DB_ACCOUNT_NAME', '')
param cosmosDbDatabaseName = readEnvironmentVariable('COSMOS_DB_DATABASE_NAME', 'app')
param cosmosDbContainerName = readEnvironmentVariable('COSMOS_DB_CONTAINER_NAME', 'items')

param deployContainerRegistry = bool(readEnvironmentVariable('DEPLOY_CONTAINER_REGISTRY', 'false'))
param containerRegistryName = readEnvironmentVariable('CONTAINER_REGISTRY_NAME', '')
