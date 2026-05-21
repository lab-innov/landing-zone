targetScope = 'resourceGroup'

param location string
param tags object = {}
param namespaceName string
param hubName string
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

resource namespace 'Microsoft.EventHub/namespaces@2025-05-01-preview' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
    minimumTlsVersion: '1.2'
    zoneRedundant: false
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2025-05-01-preview' = {
  name: hubName
  parent: namespace
  properties: {
    messageRetentionInDays: 1
    partitionCount: 2
  }
}

output namespaceResourceId string = namespace.id
output eventHubResourceId string = eventHub.id
