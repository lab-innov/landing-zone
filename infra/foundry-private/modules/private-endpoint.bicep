param location string
param tags object
param name string
param subnetId string
param targetId string
param groupId string
@description('Vacío cuando Azure Policy/DINE administra los grupos DNS.')
param zoneIds array
resource endpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: name
        properties: { privateLinkServiceId: targetId, groupIds: [groupId] }
      }
    ]
  }
}
resource dns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(zoneIds)) {
  parent: endpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [for (id, i) in zoneIds: { name: 'zone-${i}', properties: { privateDnsZoneId: id } }]
  }
}
