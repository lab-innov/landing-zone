targetScope = 'resourceGroup'

param location string
param tags object = {}
param vnetName string
param vnetAddressPrefixes array
param privateEndpointSubnetName string
param privateEndpointSubnetPrefix string
param agentSubnetName string
param agentSubnetPrefix string
param applicationSubnetName string
param applicationSubnetPrefix string
param managementSubnetName string
param managementSubnetPrefix string
param routeTableId string = ''

var attachRouteTable = !empty(routeTableId)

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: vnetAddressPrefixes
    }
    subnets: [
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: agentSubnetName
        properties: {
          addressPrefix: agentSubnetPrefix
          routeTable: attachRouteTable ? {
            id: routeTableId
          } : null
          delegations: [
            {
              name: 'aca-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: applicationSubnetName
        properties: {
          addressPrefix: applicationSubnetPrefix
          routeTable: attachRouteTable ? {
            id: routeTableId
          } : null
        }
      }
      {
        name: managementSubnetName
        properties: {
          addressPrefix: managementSubnetPrefix
          routeTable: attachRouteTable ? {
            id: routeTableId
          } : null
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output privateEndpointSubnetId string = '${vnet.id}/subnets/${privateEndpointSubnetName}'
output agentSubnetId string = '${vnet.id}/subnets/${agentSubnetName}'
output applicationSubnetId string = '${vnet.id}/subnets/${applicationSubnetName}'
output managementSubnetId string = '${vnet.id}/subnets/${managementSubnetName}'
