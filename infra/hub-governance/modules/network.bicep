targetScope = 'resourceGroup'

param location string
param tags object = {}
param vnetName string
param vnetAddressPrefixes array
param apimSubnetName string
param apimSubnetPrefix string
param privateEndpointSubnetName string
param privateEndpointSubnetPrefix string
param integrationSubnetName string
param integrationSubnetPrefix string

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
        name: apimSubnetName
        properties: {
          addressPrefix: apimSubnetPrefix
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: integrationSubnetName
        properties: {
          addressPrefix: integrationSubnetPrefix
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output apimSubnetId string = '${vnet.id}/subnets/${apimSubnetName}'
output privateEndpointSubnetId string = '${vnet.id}/subnets/${privateEndpointSubnetName}'
output integrationSubnetId string = '${vnet.id}/subnets/${integrationSubnetName}'
