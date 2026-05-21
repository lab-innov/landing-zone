targetScope = 'resourceGroup'

param location string
param tags object = {}
param apiManagementName string
param publisherName string
param publisherEmail string
param skuName string = 'Developer'
param skuCapacity int = 1
@allowed([
  'None'
  'External'
  'Internal'
])
param virtualNetworkType string = 'External'
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'
param subnetResourceId string = ''

var minApiVersion = '2021-08-01'
var useSubnet = virtualNetworkType != 'None' && !empty(subnetResourceId)

resource apiManagement 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apiManagementName
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    publicNetworkAccess: publicNetworkAccess
    virtualNetworkType: virtualNetworkType
    virtualNetworkConfiguration: useSubnet ? {
      subnetResourceId: subnetResourceId
    } : null
    apiVersionConstraint: {
      minApiVersion: minApiVersion
    }
  }
}

output resourceId string = apiManagement.id
output gatewayUrl string = 'https://${apiManagement.name}.azure-api.net'
