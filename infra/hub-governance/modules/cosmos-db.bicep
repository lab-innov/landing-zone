targetScope = 'resourceGroup'

param location string
param tags object = {}
param accountName string
param databaseName string
param containerName string
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-02-15-preview' = {
  name: accountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: false
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: []
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
  }
}

resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-02-15-preview' = {
  name: databaseName
  parent: account
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource sqlContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-02-15-preview' = {
  name: containerName
  parent: sqlDatabase
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/partitionKey'
        ]
        kind: 'Hash'
      }
    }
    options: {}
  }
}

output resourceId string = account.id
output databaseResourceId string = sqlDatabase.id
output containerResourceId string = sqlContainer.id
