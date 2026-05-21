targetScope = 'resourceGroup'

param location string
param tags object = {}
param storageAccountName string
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'
param skuName string = 'Standard_LRS'

var defaultAction = publicNetworkAccess == 'Disabled' ? 'Deny' : 'Allow'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: publicNetworkAccess
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: defaultAction
    }
  }
}

output resourceId string = storageAccount.id
