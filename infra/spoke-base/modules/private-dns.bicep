targetScope = 'resourceGroup'

param location string = 'global'
param tags object = {}
param vnetId string
param deployBlobZone bool = true
param deployKeyVaultZone bool = true
param deployCognitiveServicesZone bool = true
param deployOpenAiZone bool = true
param deployAiServicesZone bool = true
param deploySearchZone bool = false
param deployCosmosZone bool = false
param deployAcrZone bool = false

resource blobZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployBlobZone) {
  name: 'privatelink.blob.core.windows.net'
  location: location
  tags: tags
}

resource blobLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployBlobZone) {
  name: 'blob-${uniqueString(vnetId)}'
  parent: blobZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource keyVaultZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployKeyVaultZone) {
  name: 'privatelink.vaultcore.azure.net'
  location: location
  tags: tags
}

resource keyVaultLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployKeyVaultZone) {
  name: 'kv-${uniqueString(vnetId)}'
  parent: keyVaultZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource cognitiveServicesZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployCognitiveServicesZone) {
  name: 'privatelink.cognitiveservices.azure.com'
  location: location
  tags: tags
}

resource cognitiveServicesLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployCognitiveServicesZone) {
  name: 'cog-${uniqueString(vnetId)}'
  parent: cognitiveServicesZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource openAiZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployOpenAiZone) {
  name: 'privatelink.openai.azure.com'
  location: location
  tags: tags
}

resource openAiLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployOpenAiZone) {
  name: 'openai-${uniqueString(vnetId)}'
  parent: openAiZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource aiServicesZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployAiServicesZone) {
  name: 'privatelink.services.ai.azure.com'
  location: location
  tags: tags
}

resource aiServicesLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployAiServicesZone) {
  name: 'aisvc-${uniqueString(vnetId)}'
  parent: aiServicesZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource searchZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deploySearchZone) {
  name: 'privatelink.search.windows.net'
  location: location
  tags: tags
}

resource searchLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deploySearchZone) {
  name: 'search-${uniqueString(vnetId)}'
  parent: searchZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource cosmosZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployCosmosZone) {
  name: 'privatelink.documents.azure.com'
  location: location
  tags: tags
}

resource cosmosLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployCosmosZone) {
  name: 'cosmos-${uniqueString(vnetId)}'
  parent: cosmosZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource acrZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (deployAcrZone) {
  name: 'privatelink.azurecr.io'
  location: location
  tags: tags
}

resource acrLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (deployAcrZone) {
  name: 'acr-${uniqueString(vnetId)}'
  parent: acrZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

output blobZoneId string = deployBlobZone ? blobZone.id : ''
output keyVaultZoneId string = deployKeyVaultZone ? keyVaultZone.id : ''
output cognitiveServicesZoneId string = deployCognitiveServicesZone ? cognitiveServicesZone.id : ''
output openAiZoneId string = deployOpenAiZone ? openAiZone.id : ''
output aiServicesZoneId string = deployAiServicesZone ? aiServicesZone.id : ''
output searchZoneId string = deploySearchZone ? searchZone.id : ''
output cosmosZoneId string = deployCosmosZone ? cosmosZone.id : ''
output acrZoneId string = deployAcrZone ? acrZone.id : ''
