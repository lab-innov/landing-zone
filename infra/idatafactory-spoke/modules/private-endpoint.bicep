param name string
param location string
param tags object
param subnetId string
param targetId string
param groupId string
// DNS y grupos de zona pertenecen a la política DINE central de CAF.
resource endpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [{
      name: name
      properties: {
        privateLinkServiceId: targetId
        groupIds: [groupId]
      }
    }]
  }
}
output id string = endpoint.id
