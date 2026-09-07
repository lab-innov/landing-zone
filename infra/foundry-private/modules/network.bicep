param location string
param tags object
param name string
@description('CIDR aprobados por IPAM: vnet, foundry, containers, appGateway, privateEndpoints, gateway y firewall.')
param prefixes object
param dnsServers array
param hubVnetId string
param firewallIp string
param useRemoteGateways bool
param clientPrefixes array

resource routes 'Microsoft.Network/routeTables@2024-05-01' = {
  name: '${name}-egress'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'salida-firewall-caf'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallIp
        }
      }
    ]
  }
}
resource gatewayNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${name}-appgw-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'HTTPS-desde-CAF'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefixes: clientPrefixes
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Sondas-Azure'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Denegar-otras-entradas'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}
// NSG de base; las reglas de salida aprobadas se aplican en el firewall central.
resource workloadNsgs 'Microsoft.Network/networkSecurityGroups@2024-05-01' = [
  for purpose in ['foundry', 'containers']: {
    name: '${name}-${purpose}-nsg'
    location: location
    tags: tags
    properties: { securityRules: [] }
  }
]
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [prefixes.vnet] }
    dhcpOptions: { dnsServers: dnsServers }
    subnets: [
      {
        name: 'snet-foundry'
        properties: {
          addressPrefix: prefixes.foundry
          networkSecurityGroup: { id: workloadNsgs[0].id }
          routeTable: { id: routes.id }
          delegations: [{ name: 'foundry', properties: { serviceName: 'Microsoft.App/environments' } }]
        }
      }
      {
        name: 'snet-containers'
        properties: {
          addressPrefix: prefixes.containers
          networkSecurityGroup: { id: workloadNsgs[1].id }
          routeTable: { id: routes.id }
          delegations: [{ name: 'containers', properties: { serviceName: 'Microsoft.App/environments' } }]
        }
      }
      {
        name: 'snet-appgateway'
        properties: {
          addressPrefix: prefixes.appGateway
          routeTable: { id: routes.id }
          networkSecurityGroup: { id: gatewayNsg.id }
          delegations: [{ name: 'appgateway', properties: { serviceName: 'Microsoft.Network/applicationGateways' } }]
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: prefixes.privateEndpoints
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      // Reservas solicitadas; no crean un firewall ni un gateway VPN/ExpressRoute.
      { name: 'GatewaySubnet', properties: { addressPrefix: prefixes.gateway } }
      { name: 'AzureFirewallSubnet', properties: { addressPrefix: prefixes.firewall } }
    ]
  }
}
resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: vnet
  name: 'to-caf-hub'
  properties: {
    remoteVirtualNetwork: { id: hubVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: useRemoteGateways
  }
}
output vnetId string = vnet.id
output foundrySubnetId string = '${vnet.id}/subnets/snet-foundry'
output containerSubnetId string = '${vnet.id}/subnets/snet-containers'
output gatewaySubnetId string = '${vnet.id}/subnets/snet-appgateway'
output peSubnetId string = '${vnet.id}/subnets/snet-private-endpoints'
