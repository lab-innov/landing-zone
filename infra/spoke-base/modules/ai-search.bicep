targetScope = 'resourceGroup'

param location string
param tags object = {}
param searchServiceName string
@allowed([
  'enabled'
  'disabled'
])
param publicNetworkAccess string = 'disabled'

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  tags: tags
  sku: {
    name: 'basic'
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: false
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
  }
}

output resourceId string = searchService.id
