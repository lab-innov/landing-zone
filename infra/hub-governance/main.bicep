targetScope = 'subscription'

@description('Azure region for the governance hub.')
param location string

@description('Resource group name for the governance hub.')
param resourceGroupName string

@description('Tags applied to all resources.')
param tags object = {}

@description('Virtual network name. Leave empty to auto-generate.')
param vnetName string = ''

@description('Virtual network address prefixes.')
param vnetAddressPrefixes array = [
  '10.170.0.0/24'
]

@description('APIM subnet name.')
param apimSubnetName string = 'snet-apim'

@description('APIM subnet prefix.')
param apimSubnetPrefix string = '10.170.0.0/26'

@description('Private endpoint subnet name.')
param privateEndpointSubnetName string = 'snet-private-endpoints'

@description('Private endpoint subnet prefix.')
param privateEndpointSubnetPrefix string = '10.170.0.64/26'

@description('Integration subnet name.')
param integrationSubnetName string = 'snet-integration'

@description('Integration subnet prefix.')
param integrationSubnetPrefix string = '10.170.0.128/26'

@description('Deploy private DNS zones in this resource group and link them to the governance hub VNet.')
param deployPrivateDnsZones bool = true

@description('Pre-existing private DNS zone resource IDs when deployPrivateDnsZones is false or when central DNS is managed elsewhere.')
param privateDnsZoneResourceIds object = {
  blob: ''
  keyVault: ''
  cosmos: ''
  eventHub: ''
  cognitiveServices: ''
  openAi: ''
  aiServices: ''
  apim: ''
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

@description('Event Hub namespace name. Leave empty to auto-generate.')
param eventHubNamespaceName string = ''

@description('Event Hub name.')
param eventHubName string = 'ai-usage'

@description('Deploy Event Hub namespace and hub.')
param deployEventHub bool = true

@description('Cosmos DB account name. Leave empty to auto-generate.')
param cosmosDbAccountName string = ''

@description('Cosmos DB SQL database name.')
param cosmosDbDatabaseName string = 'governance'

@description('Cosmos DB SQL container name.')
param cosmosDbContainerName string = 'usage'

@description('Deploy Cosmos DB.')
param deployCosmosDb bool = true

@description('Azure AI Foundry / AI Services account name. Leave empty to auto-generate.')
param aiFoundryAccountName string = ''

@description('Default AI Foundry project name.')
param aiFoundryProjectName string = 'governance-project'

@description('Custom subdomain for the AI Foundry account. Leave empty to derive it from the account name.')
param aiFoundryCustomSubdomain string = ''

@description('Disable local key auth on the AI Foundry account.')
param disableAiFoundryLocalAuth bool = true

@description('Deploy AI Foundry account and project.')
param deployAiFoundry bool = true

@description('API Management service name. Leave empty to auto-generate.')
param apiManagementName string = ''

@description('APIM publisher name.')
param apiManagementPublisherName string

@description('APIM publisher email.')
param apiManagementPublisherEmail string

@description('APIM SKU name.')
param apiManagementSkuName string = 'Developer'

@description('APIM SKU capacity.')
param apiManagementSkuCapacity int = 1

@description('APIM virtual network mode.')
@allowed([
  'None'
  'External'
  'Internal'
])
param apiManagementVirtualNetworkType string = 'External'

@description('APIM public network access setting.')
@allowed([
  'Enabled'
  'Disabled'
])
param apiManagementPublicNetworkAccess string = 'Enabled'

@description('Create a private endpoint for APIM.')
param enableApimPrivateEndpoint bool = false

var resourceToken = toLower(uniqueString(subscription().id, resourceGroupName, location))
var resolvedVnetName = !empty(vnetName) ? vnetName : 'vnet-ai-gov-${resourceToken}'
var resolvedLogAnalyticsName = !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : 'law-ai-gov-${resourceToken}'
var resolvedApplicationInsightsName = !empty(applicationInsightsName) ? applicationInsightsName : 'appi-ai-gov-${resourceToken}'
var resolvedStorageAccountName = !empty(storageAccountName) ? storageAccountName : take('staigov${resourceToken}', 24)
var resolvedKeyVaultName = !empty(keyVaultName) ? keyVaultName : take('kv-ai-gov-${resourceToken}', 24)
var resolvedEventHubNamespaceName = !empty(eventHubNamespaceName) ? eventHubNamespaceName : take('evh-ai-gov-${resourceToken}', 50)
var resolvedCosmosDbAccountName = !empty(cosmosDbAccountName) ? cosmosDbAccountName : take('cosmos-ai-gov-${resourceToken}', 44)
var resolvedAiFoundryAccountName = !empty(aiFoundryAccountName) ? aiFoundryAccountName : take('aif-gov-${resourceToken}', 24)
var resolvedAiFoundrySubdomain = !empty(aiFoundryCustomSubdomain) ? toLower(aiFoundryCustomSubdomain) : toLower(resolvedAiFoundryAccountName)
var resolvedApiManagementName = !empty(apiManagementName) ? apiManagementName : take('apim-ai-gov-${resourceToken}', 50)

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module network './modules/network.bicep' = {
  name: 'hub-governance-network'
  scope: hubResourceGroup
  params: {
    location: location
    tags: tags
    vnetName: resolvedVnetName
    vnetAddressPrefixes: vnetAddressPrefixes
    apimSubnetName: apimSubnetName
    apimSubnetPrefix: apimSubnetPrefix
    privateEndpointSubnetName: privateEndpointSubnetName
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    integrationSubnetName: integrationSubnetName
    integrationSubnetPrefix: integrationSubnetPrefix
  }
}

module privateDns './modules/private-dns.bicep' = if (deployPrivateDnsZones) {
  name: 'hub-governance-private-dns'
  scope: hubResourceGroup
  params: {
    location: 'global'
    tags: tags
    vnetId: network.outputs.vnetId
    deployBlobZone: true
    deployKeyVaultZone: true
    deployCosmosZone: deployCosmosDb
    deployEventHubZone: deployEventHub
    deployCognitiveServicesZone: deployAiFoundry
    deployOpenAiZone: deployAiFoundry
    deployAiServicesZone: deployAiFoundry
    deployApimZone: enableApimPrivateEndpoint
  }
}

module logAnalytics './modules/log-analytics.bicep' = {
  name: 'hub-governance-law'
  scope: hubResourceGroup
  params: {
    location: location
    tags: tags
    workspaceName: resolvedLogAnalyticsName
  }
}

module applicationInsights './modules/application-insights.bicep' = {
  name: 'hub-governance-appi'
  scope: hubResourceGroup
  params: {
    location: location
    tags: tags
    applicationInsightsName: resolvedApplicationInsightsName
    workspaceResourceId: logAnalytics.outputs.resourceId
  }
}

module storage './modules/storage-account.bicep' = {
  name: 'hub-governance-storage'
  scope: hubResourceGroup
  params: {
    location: location
    tags: tags
    storageAccountName: resolvedStorageAccountName
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

module keyVault './modules/key-vault.bicep' = {
  name: 'hub-governance-key-vault'
  scope: hubResourceGroup
  params: {
    location: location
    tags: tags
    keyVaultName: resolvedKeyVaultName
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

module eventHub './modules/event-hub.bicep' = if (deployEventHub) {
  name: 'hub-governance-event-hub'
  scope: hubResourceGroup
  params: {
    location: location
    tags: tags
    namespaceName: resolvedEventHubNamespaceName
    hubName: eventHubName
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

module cosmosDb './modules/cosmos-db.bicep' = if (deployCosmosDb) {
  name: 'hub-governance-cosmos'
  scope: hubResourceGroup
  params: {
    location: location
    tags: tags
    accountName: resolvedCosmosDbAccountName
    databaseName: cosmosDbDatabaseName
    containerName: cosmosDbContainerName
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

module aiFoundry './modules/ai-foundry.bicep' = if (deployAiFoundry) {
  name: 'hub-governance-ai-foundry'
  scope: hubResourceGroup
  params: {
    location: location
    tags: tags
    accountName: resolvedAiFoundryAccountName
    projectName: aiFoundryProjectName
    customSubdomain: resolvedAiFoundrySubdomain
    disableLocalAuth: disableAiFoundryLocalAuth
    publicNetworkAccess: deployPrivateEndpoints ? 'Disabled' : 'Enabled'
  }
}

module apiManagement './modules/api-management.bicep' = {
  name: 'hub-governance-apim'
  scope: hubResourceGroup
  params: {
    location: location
    tags: tags
    apiManagementName: resolvedApiManagementName
    publisherName: apiManagementPublisherName
    publisherEmail: apiManagementPublisherEmail
    skuName: apiManagementSkuName
    skuCapacity: apiManagementSkuCapacity
    virtualNetworkType: apiManagementVirtualNetworkType
    publicNetworkAccess: apiManagementPublicNetworkAccess
    subnetResourceId: network.outputs.apimSubnetId
  }
}

var blobDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.blobZoneId : (privateDnsZoneResourceIds.blob ?? '')
var keyVaultDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.keyVaultZoneId : (privateDnsZoneResourceIds.keyVault ?? '')
var cosmosDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.cosmosZoneId : (privateDnsZoneResourceIds.cosmos ?? '')
var eventHubDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.eventHubZoneId : (privateDnsZoneResourceIds.eventHub ?? '')
var cognitiveServicesDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.cognitiveServicesZoneId : (privateDnsZoneResourceIds.cognitiveServices ?? '')
var openAiDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.openAiZoneId : (privateDnsZoneResourceIds.openAi ?? '')
var aiServicesDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.aiServicesZoneId : (privateDnsZoneResourceIds.aiServices ?? '')
var apimDnsZoneId = deployPrivateDnsZones ? privateDns!.outputs.apimZoneId : (privateDnsZoneResourceIds.apim ?? '')

module storagePrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints) {
  name: 'hub-governance-storage-pe'
  scope: hubResourceGroup
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
  name: 'hub-governance-kv-pe'
  scope: hubResourceGroup
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

module eventHubPrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints && deployEventHub) {
  name: 'hub-governance-evh-pe'
  scope: hubResourceGroup
  params: {
    name: '${resolvedEventHubNamespaceName}-pe'
    location: location
    subnetResourceId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: eventHub!.outputs.namespaceResourceId
    groupIds: [
      'namespace'
    ]
    privateDnsZoneResourceIds: !empty(eventHubDnsZoneId) ? [eventHubDnsZoneId] : []
    tags: tags
  }
}

module cosmosPrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints && deployCosmosDb) {
  name: 'hub-governance-cosmos-pe'
  scope: hubResourceGroup
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

var aiFoundryDnsZoneIds = concat(
  !empty(cognitiveServicesDnsZoneId) ? [cognitiveServicesDnsZoneId] : [],
  !empty(openAiDnsZoneId) ? [openAiDnsZoneId] : [],
  !empty(aiServicesDnsZoneId) ? [aiServicesDnsZoneId] : []
)

module aiFoundryPrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints && deployAiFoundry) {
  name: 'hub-governance-aif-pe'
  scope: hubResourceGroup
  params: {
    name: '${resolvedAiFoundryAccountName}-pe'
    location: location
    subnetResourceId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: aiFoundry!.outputs.accountResourceId
    groupIds: [
      'account'
    ]
    privateDnsZoneResourceIds: aiFoundryDnsZoneIds
    tags: tags
  }
}

module apimPrivateEndpoint './modules/private-endpoint.bicep' = if (deployPrivateEndpoints && enableApimPrivateEndpoint) {
  name: 'hub-governance-apim-pe'
  scope: hubResourceGroup
  params: {
    name: '${resolvedApiManagementName}-pe'
    location: location
    subnetResourceId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: apiManagement.outputs.resourceId
    groupIds: [
      'Gateway'
    ]
    privateDnsZoneResourceIds: !empty(apimDnsZoneId) ? [apimDnsZoneId] : []
    tags: tags
  }
}

output resourceGroupId string = hubResourceGroup.id
output vnetId string = network.outputs.vnetId
output apimSubnetId string = network.outputs.apimSubnetId
output privateEndpointSubnetId string = network.outputs.privateEndpointSubnetId
output logAnalyticsWorkspaceId string = logAnalytics.outputs.resourceId
output applicationInsightsId string = applicationInsights.outputs.resourceId
output applicationInsightsConnectionString string = applicationInsights.outputs.connectionString
output storageAccountId string = storage.outputs.resourceId
output keyVaultId string = keyVault.outputs.resourceId
output keyVaultUri string = keyVault.outputs.vaultUri
output eventHubNamespaceId string = deployEventHub ? eventHub!.outputs.namespaceResourceId : ''
output cosmosDbId string = deployCosmosDb ? cosmosDb!.outputs.resourceId : ''
output aiFoundryAccountId string = deployAiFoundry ? aiFoundry!.outputs.accountResourceId : ''
output aiFoundryProjectId string = deployAiFoundry ? aiFoundry!.outputs.projectResourceId : ''
output apiManagementId string = apiManagement.outputs.resourceId
output apiManagementGatewayUrl string = apiManagement.outputs.gatewayUrl
