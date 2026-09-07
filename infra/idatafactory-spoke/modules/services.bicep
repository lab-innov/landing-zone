@minLength(3)
param prefix string
param location string
param tags object
param registryName string
param cosmosNames array
param cosmosDatabases array
resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  tags: tags
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'None'
    dataEndpointEnabled: true
  }
}
resource cognitive 'Microsoft.CognitiveServices/accounts@2024-10-01' = [for kind in ['OpenAI', 'FormRecognizer']: {
  name: '${prefix}-${toLower(kind)}'
  location: location
  tags: tags
  kind: kind
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: '${prefix}-${toLower(kind)}'
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    networkAcls: { defaultAction: 'Deny' }
  }
}]
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = [for name in cosmosNames: {
  name: name
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    networkAclBypass: 'None'
    capabilities: [{ name: 'EnableServerless' }]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    locations: [{ locationName: location, failoverPriority: 0 }]
  }
}]
resource databases 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = [for db in cosmosDatabases: {
  parent: cosmos[db.accountIndex]
  name: db.name
  properties: { resource: { id: db.name } }
}]
resource search 'Microsoft.Search/searchServices@2023-11-01' = {
  name: '${prefix}-search'
  location: location
  tags: tags
  sku: { name: 'standard' }
  identity: { type: 'SystemAssigned' }
  properties: {
    replicaCount: 1
    partitionCount: 1
    publicNetworkAccess: 'disabled'
    disableLocalAuth: true
  }
}
resource automation 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: '${prefix}-automation'
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    sku: { name: 'Basic' }
    publicNetworkAccess: false
    disableLocalAuth: true
  }
}
output registryId string = registry.id
output registryHost string = registry.properties.loginServer
output cognitiveIds array = [for (kind,i) in ['OpenAI', 'FormRecognizer']: cognitive[i].id]
output cosmosIds array = [for (name,i) in cosmosNames: cosmos[i].id]
output searchId string = search.id
output automationId string = automation.id
