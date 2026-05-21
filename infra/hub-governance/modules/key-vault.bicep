targetScope = 'resourceGroup'

param location string
param tags object = {}
param keyVaultName string
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

var defaultAction = publicNetworkAccess == 'Disabled' ? 'Deny' : 'Allow'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    publicNetworkAccess: publicNetworkAccess
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    accessPolicies: []
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: defaultAction
    }
  }
}

output resourceId string = keyVault.id
output vaultUri string = keyVault.properties.vaultUri
