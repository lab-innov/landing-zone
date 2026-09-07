param name string
param location string
param tags object
param planId string
param subnetId string
param runtime string
param isFunction bool
param storageName string
param registryName string
param isContainer bool
@secure()
param settings object = {}
resource app 'Microsoft.Web/sites@2024-04-01' = {
  name: name
  location: location
  tags: tags
  kind: isFunction ? (isContainer ? 'functionapp,linux,container' : 'functionapp,linux') : 'app,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    // Activar sólo tras recuperar código, configuración y probar la conectividad.
    enabled: false
    serverFarmId: planId
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetId: subnetId
    vnetContentShareEnabled: true
    vnetImagePullEnabled: true
    siteConfig: {
      linuxFxVersion: runtime
      alwaysOn: true
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      ftpsState: 'Disabled'
      vnetRouteAllEnabled: true
      acrUseManagedIdentityCreds: isContainer
      appSettings: [for setting in items(union(settings, isFunction ? {
        AzureWebJobsStorage__accountName: storageName
        AzureWebJobsStorage__credential: 'managedidentity'
        FUNCTIONS_EXTENSION_VERSION: '~4'
        FUNCTIONS_WORKER_RUNTIME: 'python'
      } : {})): { name: setting.key, value: string(setting.value) }]
    }
  }
}
resource ftp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: app
  name: 'ftp'
  properties: { allow: false }
}
resource scm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2024-04-01' = {
  parent: app
  name: 'scm'
  properties: { allow: false }
}
resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = { name: registryName }
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (isContainer) {
  name: guid(registry.id, app.id, 'AcrPull')
  scope: registry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: app.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
output id string = app.id
output principalId string = app.identity.principalId
