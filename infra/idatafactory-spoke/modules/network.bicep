param location string
param tags object
param name string
param addressPrefix string
param subnetPrefixes object
param firewallIp string
param dnsServers array
param hubVnetId string
param useRemoteGateways bool
var definitions = [
  { name: 'pe', delegation: '' }
  { name: 'web', delegation: 'Microsoft.Web/serverFarms' }
  { name: 'audits', delegation: 'Microsoft.Web/serverFarms' }
  { name: 'commons', delegation: 'Microsoft.Web/serverFarms' }
  { name: 'notifications', delegation: 'Microsoft.Web/serverFarms' }
  { name: 'processing', delegation: 'Microsoft.Web/serverFarms' }
  { name: 'dbxhost', delegation: 'Microsoft.Databricks/workspaces' }
  { name: 'dbxcontainer', delegation: 'Microsoft.Databricks/workspaces' }
]
resource routes 'Microsoft.Network/routeTables@2024-05-01' = {
  name: '${name}-egress'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [{
      name: 'salida-firewall-caf'
      properties: {
        addressPrefix: '0.0.0.0/0'
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: firewallIp
      }
    }]
  }
}
// Databricks añade las reglas obligatorias mediante la delegación de subred.
// No se restringe Cosmos Direct a 443: requiere puertos TCP dinámicos privados.
resource nsgs 'Microsoft.Network/networkSecurityGroups@2024-05-01' = [for subnet in definitions: {
  name: '${name}-${subnet.name}-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: subnet.name == 'pe' ? [{
      name: 'DenegarOrigenNoConectado'
      properties: {
        priority: 4000
        direction: 'Inbound'
        access: 'Deny'
        protocol: '*'
        sourceAddressPrefix: 'Internet'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '*'
      }
    }] : []
  }
}]
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [addressPrefix] }
    dhcpOptions: { dnsServers: dnsServers }
    subnets: [for (subnet,i) in definitions: {
      name: 'snet-${subnet.name}'
      properties: {
        addressPrefix: subnetPrefixes[subnet.name]
        networkSecurityGroup: { id: nsgs[i].id }
        // Mantener la ruta local a PE; una UDR /0 no fuerza su inspección.
        routeTable: subnet.name == 'pe' ? null : { id: routes.id }
        privateEndpointNetworkPolicies: subnet.name == 'pe' ? 'NetworkSecurityGroupEnabled' : 'Disabled'
        delegations: empty(subnet.delegation) ? [] : [{
          name: 'delegacion'
          properties: { serviceName: subnet.delegation }
        }]
      }
    }]
  }
}
resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: vnet
  name: 'hacia-hub-caf'
  properties: {
    remoteVirtualNetwork: { id: hubVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: useRemoteGateways
  }
}
output id string = vnet.id
output peSubnetId string = '${vnet.id}/subnets/snet-pe'
