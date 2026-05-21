targetScope = 'resourceGroup'

param location string
param tags object = {}
param routeTableName string
param nextHopIpAddress string

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: !empty(nextHopIpAddress) ? [
      {
        name: 'default-to-hub-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nextHopIpAddress
        }
      }
    ] : []
  }
}

output resourceId string = routeTable.id
