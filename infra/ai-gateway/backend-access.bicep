targetScope = 'resourceGroup'

@description('Ejecutar en el grupo de recursos de la cuenta Azure OpenAI existente.')
@minLength(2)
param accountName string
@description('Object ID de la identidad administrada de sistema de APIM; no es el client ID.')
@minLength(36)
@maxLength(36)
param apimPrincipalId string

resource account 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = { name: accountName }
resource access 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(account.id, apimPrincipalId, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
  scope: account
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd')
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}
output roleAssignmentId string = access.id
