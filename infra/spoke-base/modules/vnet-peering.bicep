targetScope = 'resourceGroup'

param localVnetName string
param remoteVnetResourceId string
param localPeeringName string
param useRemoteGatewaysOnLocal bool = false

resource localVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: localVnetName
}

resource localPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: localPeeringName
  parent: localVnet
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    doNotVerifyRemoteGateways: false
    remoteVirtualNetwork: {
      id: remoteVnetResourceId
    }
    useRemoteGateways: useRemoteGatewaysOnLocal
  }
}

output localPeeringId string = localPeering.id
