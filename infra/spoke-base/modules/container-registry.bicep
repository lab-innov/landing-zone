targetScope = 'resourceGroup'

param location string
param tags object = {}
param registryName string
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: 'Premium'
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
    adminUserEnabled: false
    networkRuleBypassOptions: 'AzureServices'
  }
}

output resourceId string = registry.id
output loginServer string = registry.properties.loginServer
