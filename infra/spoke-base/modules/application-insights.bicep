targetScope = 'resourceGroup'

param location string
param tags object = {}
param applicationInsightsName string
param workspaceResourceId string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
    IngestionMode: 'LogAnalytics'
  }
}

output resourceId string = applicationInsights.id
output connectionString string = applicationInsights.properties.ConnectionString
