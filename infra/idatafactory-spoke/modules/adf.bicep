param name string
param location string
param tags object
param endpoints array
resource factory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: name
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: { publicNetworkAccess: 'Disabled' }
}
resource vnet 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  parent: factory
  name: 'default'
  properties: {}
}
resource ir 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  parent: factory
  name: 'AutoResolveIntegrationRuntime'
  properties: {
    type: 'Managed'
    managedVirtualNetwork: { type: 'ManagedVirtualNetworkReference', referenceName: vnet.name }
    typeProperties: { computeProperties: { location: location } }
  }
}
resource managedEndpoints 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = [for endpoint in endpoints: {
  parent: vnet
  name: endpoint.name
  properties: {
    privateLinkResourceId: endpoint.id
    groupId: endpoint.groupId
  }
}]
// La exportación no contiene pipelines, linked services ni triggers. No inventarlos.
output id string = factory.id
output principalId string = factory.identity.principalId
