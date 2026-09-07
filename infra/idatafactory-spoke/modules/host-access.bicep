param storageName string
param principalId string
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = { name: storageName }
var roles = [
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Propietario de datos Blob: host Functions.
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88' // Colaborador de datos Queue.
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Colaborador de datos Table.
]
resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in roles: {
  name: guid(storage.id, principalId, role)
  scope: storage
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
  }
}]
