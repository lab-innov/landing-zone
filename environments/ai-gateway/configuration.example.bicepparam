using '../../infra/ai-gateway/main.bicep'

param apimName = 'PENDIENTE-APIM'
param tenantId = '00000000-0000-0000-0000-000000000000'
param audience = 'api://PENDIENTE-APLICACION-GATEWAY'
param requiredRole = 'AiGateway.Invoke'
param initiatives = [{
  name: 'piloto'
  clientApplicationIds: ['00000000-0000-0000-0000-000000000000']
  accountName: 'PENDIENTE-OPENAI'
  deploymentName: 'PENDIENTE-MODELO'
  apiVersion: '2024-10-21'
  requestsPerMinute: 60
  tokensPerMinute: 10000
  monthlyTokenQuota: 1000000
}]
