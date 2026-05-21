targetScope = 'resourceGroup'

param name string
param location string
param subnetResourceId string
param privateLinkServiceId string
param groupIds array
param privateDnsZoneResourceIds array = []
param tags object = {}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-connection'
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: groupIds
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = if (!empty(privateDnsZoneResourceIds)) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      for (zoneId, i) in privateDnsZoneResourceIds: {
        name: 'zone-${i}'
        properties: {
          privateDnsZoneId: zoneId
        }
      }
    ]
  }
}

output resourceId string = privateEndpoint.id
