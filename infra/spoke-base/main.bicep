targetScope = 'subscription'

@description('Azure region for the spoke.')
param location string

@description('Resource group name for the spoke deployment.')
param resourceGroupName string

@description('Tags applied to all resources.')
param tags object = {}

@description('Spoke virtual network name. Leave empty to auto-generate.')
param vnetName string = ''

@description('Spoke virtual network address prefixes.')
param vnetAddressPrefixes array = [
  '10.180.0.0/24'
]

@description('Private endpoint subnet name.')
param privateEndpointSubnetName string = 'snet-private-endpoints'

@description('Private endpoint subnet prefix.')
param privateEndpointSubnetPrefix string = '10.180.0.0/26'

@description('AI Foundry agent subnet name.')
param agentSubnetName string = 'snet-agents'

@description('AI Foundry agent subnet prefix.')
param agentSubnetPrefix string = '10.180.0.64/26'

@description('Application subnet name.')
param applicationSubnetName string = 'snet-app'

@description('Application subnet prefix.')
param applicationSubnetPrefix string = '10.180.0.128/26'

@description('Management subnet name.')
param managementSubnetName string = 'snet-management'

@description('Management subnet prefix.')
param managementSubnetPrefix string = '10.180.0.192/26'

@description('Create a route table and point spoke egress to the hub firewall private IP.')
param createRouteTable bool = false

@description('Firewall private IP in the connectivity hub for default route 0.0.0.0/0.')
param hubFirewallPrivateIp string = ''

@description('Create a peering from the spoke to the hub VNet.')
param createSpokeToHubPeering bool = false

@description('Hub VNet resource ID for peering.')
param hubVnetResourceId string = ''

@description('Use remote gateways on the spoke-to-hub peering.')
param useRemoteGatewaysOnSpoke bool = false

@description('Deploy private DNS zones in the spoke resource group and link them to the spoke VNet.')
param deployPrivateDnsZones bool = true

@description('Pre-existing private DNS zone resource IDs when using shared central DNS.')
param privateDnsZoneResourceIds object = {
  blob: ''
  keyVault: ''
  cognitiveServices: ''
  openAi: ''
  aiServices: ''
  search: ''
  cosmos: ''
  acr: ''
}

@description('Deploy private endpoints for supported resources.')
param deployPrivateEndpoints bool = true

@description('Log Analytics workspace name. Leave empty to auto-generate.')
param logAnalyticsWorkspaceName string = ''

@description('Application Insights name. Leave empty to auto-generate.')
param applicationInsightsName string = ''

@description('Storage account name. Leave empty to auto-generate.')
param storageAccountName string = ''

@description('Key Vault name. Leave empty to auto-generate.')
param keyVaultName string = ''

@description('AI Foundry / AI Services account name. Leave empty to auto-generate.')
param aiFoundryAccountName string = ''

@description('Default AI Foundry project name.')
param aiFoundryProjectName string = 'spoke-project'

@description('Custom subdomain for the AI Foundry account. Leave empty to derive it from the account name.')
param aiFoundryCustomSubdomain string = ''

@description('Disable local key auth on the AI Foundry account.')
param disableAiFoundryLocalAuth bool = true

@description('Deploy AI Search.')
param deployAiSearch bool = false

@description('AI Search service name. Leave empty to auto-generate.')
param aiSearchServiceName string = ''

@description('Deploy Cosmos DB.')
param deployCosmosDb bool = false

@description('Cosmos DB account name. Leave empty to auto-generate.')
param cosmosDbAccountName string = ''

@description('Cosmos DB SQL database name.')
param cosmosDbDatabaseName string = 'app'

@description('Cosmos DB SQL container name.')
param cosmosDbContainerName string = 'items'

@description('Deploy Azure Container Registry.')
param deployContainerRegistry bool = false

@description('Container Registry name. Leave empty to auto-generate.')
param containerRegistryName string = ''

var resourceToken = toLower(uniqueString(subscription().id, resourceGroupName, location))
var resolvedVnetName = !empty(vnetName) ? vnetName : 'vnet-ai-spoke-${resourceToken}'
var resolvedLogAnalyticsName = !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : 'law-ai-spoke-${resourceToken}'
var resolvedApplicationInsightsName = !empty(applicationInsightsName) ? applicationInsightsName : 'appi-ai-spoke-${resourceToken}'
var resolvedStorageAccountName = !empty(storageAccountName) ? storageAccountName : take('staspoke${resourceToken}', 24)
var resolvedKeyVaultName = !empty(keyVaultName) ? keyVaultName : take('kv-ai-spoke-${resourceToken}', 24)
var resolvedAiFoundryAccountName = !empty(aiFoundryAccountName) ? aiFoundryAccountName : take('aif-spoke-${resourceToken}', 24)
var resolvedAiFoundrySubdomain = !empty(aiFoundryCustomSubdomain) ? toLower(aiFoundryCustomSubdomain) : toLower(resolvedAiFoundryAccountName)
var resolvedAiSearchName = !empty(aiSearchServiceName) ? aiSearchServiceName : take('srch-ai-spoke-${resourceToken}', 44)
var resolvedCosmosDbAccountName = !empty(cosmosDbAccountName) ? cosmosDbAccountName : take('cosmos-ai-spoke-${resourceToken}', 44)
var resolvedContainerRegistryName = !empty(containerRegistryName) ? containerRegistryName : take('acr${resourceToken}', 50)

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module routeTable './modules/route-table.bicep' = if (createRouteTable) {
  name: 'spoke-route-table'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    routeTableName: 'rt-ai-spoke-${resourceToken}'
    nextHopIpAddress: hubFirewallPrivateIp
  }
}

module network './modules/network.bicep' = {
  name: 'spoke-network'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    vnetName: resolvedVnetName
    vnetAddressPrefixes: vnetAddressPrefixes
    privateEndpointSubnetName: privateEndpointSubnetName
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    agentSubnetName: agentSubnetName
    agentSubnetPrefix: agentSubnetPrefix
    applicationSubnetName: applicationSubnetName
    applicationSubnetPrefix: applicationSubnetPrefix
    managementSubnetName: managementSubnetName
    managementSubnetPrefix: managementSubnetPrefix
    routeTableId: createRouteTable ? routeTable!.outputs.resourceId : ''
  }
}

module privateDns './modules/private-dns.bicep' = if (deployPrivateDnsZones) {
  name: 'spoke-private-dns'
  scope: spokeResourceGroup
  params: {
    location: 'global'
    tags: tags
    vnetId: network.outputs.vnetId
    deployBlobZone: true
    deployKeyVaultZone: true
    deployCognitiveServicesZone: true
    deployOpenAiZone: true
    deployAiServicesZone: true
    deploySearchZone: deployAiSearch
    deployCosmosZone: deployCosmosDb
    deployAcrZone: deployContainerRegistry
  }
}

module logAnalytics './modules/log-analytics.bicep' = {
  name: 'spoke-law'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    workspaceName: resolvedLogAnalyticsName
  }
}

module applicationInsights './modules/application-insights.bicep' = {
  name: 'spoke-appi'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    applicationInsightsName: resolvedApplicationInsightsName
    workspaceResourceId: logAnalytics.outputs.resourceId
  }
}

module storage './modules/storage-account.bicep' = {
  name: 'spoke-storage'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    storageAccountName: resolvedStorageAccountName
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

module keyVault './modules/key-vault.bicep' = {
  name: 'spoke-key-vault'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    keyVaultName: resolvedKeyVaultName
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

module aiFoundry './modules/ai-foundry.bicep' = {
  name: 'spoke-ai-foundry'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    accountName: resolvedAiFoundryAccountName
    projectName: aiFoundryProjectName
    customSubdomain: resolvedAiFoundrySubdomain
    disableLocalAuth: disableAiFoundryLocalAuth
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
    agentSubnetResourceId: network.outputs.agentSubnetId
  }
}

module aiSearch './modules/ai-search.bicep' = if (deployAiSearch) {
  name: 'spoke-search'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    searchServiceName: resolvedAiSearchName
    publicNetworkAccess: deployPrivateEndpoints ? 'disabled' : 'enabled'
  }
}

module cosmosDb './modules/cosmos-db.bicep' = if (deployCosmosDb) {
  name: 'spoke-cosmos'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    accountName: resolvedCosmosDbAccountName
    databaseName: cosmosDbDatabaseName
    containerName: cosmosDbContainerName
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

module containerRegistry './modules/container-registry.bicep' = if (deployContainerRegistry) {
  name: 'spoke-acr'
  scope: spokeResourceGroup
  params: {
    location: location
    tags: tags
    registryName: resolvedContainerRegistryName
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

module vnetPeering './modules/vnet-peering.bicep' = if (createSpokeToHubPeering && !empty(hubVnetResourceId)) {
  name: 'spoke-to-hub-peering'
  scope: spokeResourceGroup
  params: {
    localVnetName: resolvedVnetName
    remoteVnetResourceId: hubVnetResourceId
    localPeeringName: 'peer-${resolvedVnetName}-to-hub'
    useRemoteGatewaysOnLocal: useRemoteGatewaysOnSpoke
  }
}

var blobDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.blobZoneId : (privateDnsZoneResourceIds.blob ?? '')
var keyVaultDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.keyVaultZoneId : (privateDnsZoneResourceIds.keyVault ?? '')
var cognitiveServicesDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.cognitiveServicesZoneId : (privateDnsZoneResourceIds.cognitiveServices ?? '')
var openAiDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.openAiZoneId : (privateDnsZoneResourceIds.openAi ?? '')
var aiServicesDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.aiServicesZoneId : (privateDnsZoneResourceIds.aiServices ?? '')
var searchDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.searchZoneId : (privateDnsZoneResourceIds.search ?? '')
var cosmosDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.cosmosZoneId : (privateDnsZoneResourceIds.cosmos ?? '')
var acrDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.acrZoneId : (privateDnsZoneResourceIds.acr ?? '')

module storagePrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints) {
  name: 'spoke-storage-pe'
  scope: spokeResourceGroup
  params: {
    name: '${resolvedStorageAccountName}-blob-pe'
    location: location
    subnetResourceId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: storage.outputs.resourceId
    groupIds: [
      'blob'
    ]
    privateDnsZoneResourceIds: !empty(blobDnsZoneId) ? [blobDnsZoneId] : []
    tags: tags
  }
}

module keyVaultPrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints) {
  name: 'spoke-kv-pe'
  scope: spokeResourceGroup
  params: {
    name: '${resolvedKeyVaultName}-pe'
    location: location
    subnetResourceId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: keyVault.outputs.resourceId
    groupIds: [
      'vault'
    ]
    privateDnsZoneResourceIds: !empty(keyVaultDnsZoneId) ? [keyVaultDnsZoneId] : []
    tags: tags
  }
}

var aiFoundryDnsZoneIds = concat(
  !empty(cognitiveServicesDnsZoneId) ? [cognitiveServicesDnsZoneId] : [],
  !empty(openAiDnsZoneId) ? [openAiDnsZoneId] : [],
  !empty(aiServicesDnsZoneId) ? [aiServicesDnsZoneId] : []
)

module aiFoundryPrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints) {
  name: 'spoke-aif-pe'
  scope: spokeResourceGroup
  params: {
    name: '${resolvedAiFoundryAccountName}-pe'
    location: location
    subnetResourceId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: aiFoundry.outputs.accountResourceId
    groupIds: [
      'account'
    ]
    privateDnsZoneResourceIds: aiFoundryDnsZoneIds
    tags: tags
  }
}

module searchPrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints && deployAiSearch) {
  name: 'spoke-search-pe'
  scope: spokeResourceGroup
  params: {
    name: '${resolvedAiSearchName}-pe'
    location: location
    subnetResourceId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: aiSearch!.outputs.resourceId
    groupIds: [
      'searchService'
    ]
    privateDnsZoneResourceIds: !empty(searchDnsZoneId) ? [searchDnsZoneId] : []
    tags: tags
  }
}

module cosmosPrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints && deployCosmosDb) {
  name: 'spoke-cosmos-pe'
  scope: spokeResourceGroup
  params: {
    name: '${resolvedCosmosDbAccountName}-pe'
    location: location
    subnetResourceId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: cosmosDb!.outputs.resourceId
    groupIds: [
      'Sql'
    ]
    privateDnsZoneResourceIds: !empty(cosmosDnsZoneId) ? [cosmosDnsZoneId] : []
    tags: tags
  }
}

module acrPrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints && deployContainerRegistry) {
  name: 'spoke-acr-pe'
  scope: spokeResourceGroup
  params: {
    name: '${resolvedContainerRegistryName}-pe'
    location: location
    subnetResourceId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: containerRegistry!.outputs.resourceId
    groupIds: [
      'registry'
    ]
    privateDnsZoneResourceIds: !empty(acrDnsZoneId) ? [acrDnsZoneId] : []
    tags: tags
  }
}

output resourceGroupId string = spokeResourceGroup.id
output vnetId string = network.outputs.vnetId
output privateEndpointSubnetId string = network.outputs.privateEndpointSubnetId
output agentSubnetId string = network.outputs.agentSubnetId
output applicationSubnetId string = network.outputs.applicationSubnetId
output managementSubnetId string = network.outputs.managementSubnetId
output logAnalyticsWorkspaceId string = logAnalytics.outputs.resourceId
output applicationInsightsId string = applicationInsights.outputs.resourceId
output applicationInsightsConnectionString string = applicationInsights.outputs.connectionString
output storageAccountId string = storage.outputs.resourceId
output keyVaultId string = keyVault.outputs.resourceId
output keyVaultUri string = keyVault.outputs.vaultUri
output aiFoundryAccountId string = aiFoundry.outputs.accountResourceId
output aiFoundryProjectId string = aiFoundry.outputs.projectResourceId
output aiSearchId string = deployAiSearch ? aiSearch!.outputs.resourceId : ''
output cosmosDbId string = deployCosmosDb ? cosmosDb!.outputs.resourceId : ''
output containerRegistryId string = deployContainerRegistry ? containerRegistry!.outputs.resourceId : ''
