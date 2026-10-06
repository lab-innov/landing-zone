targetScope = 'resourceGroup'

@description('Región aprobada para APIM y su red existente.')
param location string
@minLength(1)
param apimName string
@minLength(1)
param publisherName string
@minLength(1)
param publisherEmail string
@description('Subred exclusiva, delegada a Microsoft.Web/serverFarms y con NSG corporativo.')
@minLength(1)
param integrationSubnetId string
@description('Subred existente para el endpoint privado, distinta de la subred de integración.')
@minLength(1)
param privateEndpointSubnetId string
@description('Inicial crea una instancia sin APIs. Privada cierra el acceso público después de aprobar el endpoint.')
@allowed(['inicial', 'privada'])
param stage string = 'privada'
@minLength(1)
param logAnalyticsWorkspaceId string
param tags object

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: 'StandardV2'
    capacity: 1
  }
  identity: { type: 'SystemAssigned' }
  properties: {
    publisherName: publisherName
    publisherEmail: publisherEmail
    virtualNetworkType: 'External'
    virtualNetworkConfiguration: { subnetResourceId: integrationSubnetId }
    publicNetworkAccess: stage == 'privada' ? 'Disabled' : 'Enabled'
  }
}

resource endpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${apimName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: { id: privateEndpointSubnetId }
    privateLinkServiceConnections: [{
      name: '${apimName}-gateway'
      properties: {
        privateLinkServiceId: apim.id
        groupIds: ['Gateway']
      }
    }]
  }
}

module diagnostics './modules/diagnostics.bicep' = {
  name: 'ai-gateway-diagnostics'
  params: {
    apimName: apim.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

output apimId string = apim.id
output principalId string = apim.identity.principalId
output privateEndpointId string = endpoint.id
output gatewayUrl string = 'https://${apim.name}.azure-api.net'
