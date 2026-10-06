targetScope = 'resourceGroup'

@description('APIM existente, privado y con identidad administrada de sistema habilitada.')
@minLength(1)
param apimName string
@description('Tenant corporativo que emite los tokens de las aplicaciones.')
@minLength(36)
@maxLength(36)
param tenantId string
@description('Audiencia de la aplicación de Entra que representa al gateway.')
@minLength(1)
param audience string
@description('Rol de aplicación requerido en el token. Entra debe concederlo a cada consumidor.')
@minLength(1)
param requiredRole string = 'AiGateway.Invoke'

type initiative = {
  @minLength(1)
  name: string
  @minLength(1)
  clientApplicationIds: string[]
  @minLength(1)
  accountName: string
  @minLength(1)
  deploymentName: string
  @minLength(1)
  apiVersion: string
  @minValue(1)
  requestsPerMinute: int
  @minValue(1)
  tokensPerMinute: int
  @minValue(1)
  monthlyTokenQuota: int
}

@description('Una ruta y límites independientes por iniciativa; los modelos ya deben existir en Azure OpenAI.')
@minLength(1)
param initiatives initiative[]

module apis './modules/initiative.bicep' = [for item in initiatives: {
  name: 'ai-gateway-${item.name}'
  params: {
    apimName: apimName
    initiativeName: item.name
    tenantId: tenantId
    audience: audience
    requiredRole: requiredRole
    clientApplicationIds: item.clientApplicationIds
    accountName: item.accountName
    deploymentName: item.deploymentName
    apiVersion: item.apiVersion
    requestsPerMinute: item.requestsPerMinute
    tokensPerMinute: item.tokensPerMinute
    monthlyTokenQuota: item.monthlyTokenQuota
  }
}]

output routes array = [for (item, i) in initiatives: {
  initiative: item.name
  chatCompletionsUrl: apis[i].outputs.chatCompletionsUrl
}]
