param apimName string
param logAnalyticsWorkspaceId string

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = { name: apimName }
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'ai-gateway-central'
  scope: apim
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [{ category: 'GatewayLogs', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}
