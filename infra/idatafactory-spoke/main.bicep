targetScope = 'resourceGroup'
@description('Prefijo exclusivo del entorno paralelo; no reutilizar nombres productivos.')
@minLength(3)
@maxLength(16)
param prefix string
param location string = resourceGroup().location
param tags object = { workload: 'idatafactory', gestion: 'CAF' }
@description('CIDR aprobado por IPAM, sin solapamientos con hub u otros spokes.')
param addressPrefix string
param subnetPrefixes object
@minLength(1)
param dnsServers array
param firewallIp string
param hubVnetId string
param useRemoteGateways bool = false
param logAnalyticsWorkspaceResourceId string
@description('Crear sólo si CAF no dispone de browser_authentication para esta región y zona DNS.')
param createDatabricksBrowserAuth bool = false
@description('Etiqueta o digest de imagen validado; se copia al ACR nuevo antes de activar commons.')
param commonsImage string
@description('Conservar inicialmente el runtime exportado; actualizar tras pruebas de compatibilidad.')
param processingRuntime string = 'Python|3.9'
@secure()
param applicationSettings object = {}
var suffix = uniqueString(resourceGroup().id, prefix)
var registryName = 'acr${suffix}'
var plans = ['web', 'audits', 'commons', 'notifications', 'processing']
var storageDefinitions = [
  { key: 'common', original: 'asacommon', hns: false }
  { key: 'notify', original: 'asapocnotificationscr', hns: false }
  { key: 'users', original: 'asauserpermissions', hns: false }
  { key: 'legacy1', original: 'rgpocidatafactorycr8d9e', hns: false }
  { key: 'legacy2', original: 'rgpocidatafactorycra72f', hns: false }
  { key: 'legacy3', original: 'rgpocidatafactorycra907', hns: false }
  { key: 'legacy4', original: 'rgpocidatafactorycrb5a2', hns: false }
  { key: 'legacy5', original: 'rgpocidatafactorycrba55', hns: false }
  { key: 'data', original: 'sapocidatafactorycr', hns: true }
  { key: 'risk', original: 'storagerisk1', hns: false }
  { key: 'audit', original: 'NUEVO-host-audits', hns: false }
]
var appDefinitions = [
  { key: 'web', plan: 0, storage: 8, function: false, container: false, runtime: 'NODE|24-lts' }
  { key: 'audits', plan: 1, storage: 10, function: true, container: false, runtime: 'Python|3.13' }
  { key: 'commons', plan: 2, storage: 0, function: true, container: true, runtime: '' }
  { key: 'notifications', plan: 3, storage: 1, function: true, container: false, runtime: 'Python|3.13' }
  { key: 'userpermissions', plan: 3, storage: 2, function: true, container: false, runtime: 'Python|3.13' }
  { key: 'processing', plan: 4, storage: 8, function: true, container: false, runtime: processingRuntime }
]
module network 'modules/network.bicep' = {
  name: '${prefix}-network'
  params: {
    name: '${prefix}-vnet'
    location: location
    tags: tags
    addressPrefix: addressPrefix
    subnetPrefixes: subnetPrefixes
    firewallIp: firewallIp
    dnsServers: dnsServers
    hubVnetId: hubVnetId
    useRemoteGateways: useRemoteGateways
  }
}
module storage 'modules/storage.bicep' = [for definition in storageDefinitions: {
  name: '${prefix}-storage-${definition.key}'
  params: {
    name: 'st${definition.key}${suffix}'
    location: location
    tags: union(tags, { origen: definition.original })
    hns: definition.hns
  }
}]
module services 'modules/services.bicep' = {
  name: '${prefix}-services'
  params: {
    prefix: prefix
    location: location
    tags: tags
    registryName: registryName
    cosmosNames: ['${prefix}-notifications', '${prefix}-data', '${prefix}-secaps']
    cosmosDatabases: loadJsonContent('cosmos-databases.json')
  }
}
resource appPlans 'Microsoft.Web/serverfarms@2024-04-01' = [for plan in plans: {
  name: '${prefix}-plan-${plan}'
  location: location
  tags: tags
  kind: 'linux'
  sku: { name: 'P1v3', tier: 'PremiumV3', capacity: 1 }
  properties: { reserved: true }
}]
module apps 'modules/app.bicep' = [for (app,i) in appDefinitions: {
  name: '${prefix}-app-${i}'
  params: {
    name: '${prefix}-${app.key}'
    location: location
    tags: tags
    planId: appPlans[app.plan].id
    subnetId: '${network.outputs.id}/subnets/snet-${plans[app.plan]}'
    runtime: app.container ? 'DOCKER|${services.outputs.registryHost}/${commonsImage}' : app.runtime
    isFunction: app.function
    isContainer: app.container
    storageName: storage[app.storage].outputs.name
    registryName: registryName
    settings: applicationSettings[?app.key] ?? {}
  }
}]
module hostAccess 'modules/host-access.bicep' = [for (app,i) in appDefinitions: if (app.function) {
  name: '${prefix}-host-access-${i}'
  params: {
    storageName: storage[app.storage].outputs.name
    principalId: apps[i].outputs.principalId
  }
}]
module databricks 'modules/databricks.bicep' = {
  name: '${prefix}-databricks'
  params: {
    location: location
    tags: tags
    workspaceName: '${prefix}-databricks'
    accessConnectorName: '${prefix}-connector'
    managedResourceGroupName: '${prefix}-databricks-managed-${suffix}'
    vnetResourceId: network.outputs.id
    publicSubnetName: 'snet-dbxhost'
    privateSubnetName: 'snet-dbxcontainer'
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
  }
}
module factory 'modules/adf.bicep' = {
  name: '${prefix}-adf'
  params: {
    name: '${prefix}-adf'
    location: location
    tags: tags
    endpoints: [
      { name: 'data-blob', id: storage[8].outputs.id, groupId: 'blob' }
      { name: 'data-dfs', id: storage[8].outputs.id, groupId: 'dfs' }
      { name: 'risk-blob', id: storage[9].outputs.id, groupId: 'blob' }
      { name: 'databricks', id: databricks.outputs.resourceId, groupId: 'databricks_ui_api' }
    ]
  }
}
// Cada servicio Storage tiene DNS y PE propios; dfs no sustituye a blob.
var baseTargets = [
  { name: 'storage-common-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'stcommon${suffix}'), groupId: 'blob' }
  { name: 'storage-common-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'stcommon${suffix}'), groupId: 'queue' }
  { name: 'storage-common-table', id: resourceId('Microsoft.Storage/storageAccounts', 'stcommon${suffix}'), groupId: 'table' }
  { name: 'storage-common-file', id: resourceId('Microsoft.Storage/storageAccounts', 'stcommon${suffix}'), groupId: 'file' }
  { name: 'storage-notify-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'stnotify${suffix}'), groupId: 'blob' }
  { name: 'storage-notify-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'stnotify${suffix}'), groupId: 'queue' }
  { name: 'storage-notify-table', id: resourceId('Microsoft.Storage/storageAccounts', 'stnotify${suffix}'), groupId: 'table' }
  { name: 'storage-notify-file', id: resourceId('Microsoft.Storage/storageAccounts', 'stnotify${suffix}'), groupId: 'file' }
  { name: 'storage-users-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'stusers${suffix}'), groupId: 'blob' }
  { name: 'storage-users-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'stusers${suffix}'), groupId: 'queue' }
  { name: 'storage-users-table', id: resourceId('Microsoft.Storage/storageAccounts', 'stusers${suffix}'), groupId: 'table' }
  { name: 'storage-users-file', id: resourceId('Microsoft.Storage/storageAccounts', 'stusers${suffix}'), groupId: 'file' }
  { name: 'storage-legacy1-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy1${suffix}'), groupId: 'blob' }
  { name: 'storage-legacy1-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy1${suffix}'), groupId: 'queue' }
  { name: 'storage-legacy1-table', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy1${suffix}'), groupId: 'table' }
  { name: 'storage-legacy1-file', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy1${suffix}'), groupId: 'file' }
  { name: 'storage-legacy2-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy2${suffix}'), groupId: 'blob' }
  { name: 'storage-legacy2-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy2${suffix}'), groupId: 'queue' }
  { name: 'storage-legacy2-table', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy2${suffix}'), groupId: 'table' }
  { name: 'storage-legacy2-file', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy2${suffix}'), groupId: 'file' }
  { name: 'storage-legacy3-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy3${suffix}'), groupId: 'blob' }
  { name: 'storage-legacy3-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy3${suffix}'), groupId: 'queue' }
  { name: 'storage-legacy3-table', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy3${suffix}'), groupId: 'table' }
  { name: 'storage-legacy3-file', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy3${suffix}'), groupId: 'file' }
  { name: 'storage-legacy4-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy4${suffix}'), groupId: 'blob' }
  { name: 'storage-legacy4-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy4${suffix}'), groupId: 'queue' }
  { name: 'storage-legacy4-table', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy4${suffix}'), groupId: 'table' }
  { name: 'storage-legacy4-file', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy4${suffix}'), groupId: 'file' }
  { name: 'storage-legacy5-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy5${suffix}'), groupId: 'blob' }
  { name: 'storage-legacy5-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy5${suffix}'), groupId: 'queue' }
  { name: 'storage-legacy5-table', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy5${suffix}'), groupId: 'table' }
  { name: 'storage-legacy5-file', id: resourceId('Microsoft.Storage/storageAccounts', 'stlegacy5${suffix}'), groupId: 'file' }
  { name: 'storage-data-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'stdata${suffix}'), groupId: 'blob' }
  { name: 'storage-data-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'stdata${suffix}'), groupId: 'queue' }
  { name: 'storage-data-table', id: resourceId('Microsoft.Storage/storageAccounts', 'stdata${suffix}'), groupId: 'table' }
  { name: 'storage-data-file', id: resourceId('Microsoft.Storage/storageAccounts', 'stdata${suffix}'), groupId: 'file' }
  { name: 'storage-data-dfs', id: resourceId('Microsoft.Storage/storageAccounts', 'stdata${suffix}'), groupId: 'dfs' }
  { name: 'storage-risk-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'strisk${suffix}'), groupId: 'blob' }
  { name: 'storage-risk-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'strisk${suffix}'), groupId: 'queue' }
  { name: 'storage-risk-table', id: resourceId('Microsoft.Storage/storageAccounts', 'strisk${suffix}'), groupId: 'table' }
  { name: 'storage-risk-file', id: resourceId('Microsoft.Storage/storageAccounts', 'strisk${suffix}'), groupId: 'file' }
  { name: 'storage-audit-blob', id: resourceId('Microsoft.Storage/storageAccounts', 'staudit${suffix}'), groupId: 'blob' }
  { name: 'storage-audit-queue', id: resourceId('Microsoft.Storage/storageAccounts', 'staudit${suffix}'), groupId: 'queue' }
  { name: 'storage-audit-table', id: resourceId('Microsoft.Storage/storageAccounts', 'staudit${suffix}'), groupId: 'table' }
  { name: 'storage-audit-file', id: resourceId('Microsoft.Storage/storageAccounts', 'staudit${suffix}'), groupId: 'file' }
  { name: 'app-web', id: resourceId('Microsoft.Web/sites', '${prefix}-web'), groupId: 'sites' }
  { name: 'app-audits', id: resourceId('Microsoft.Web/sites', '${prefix}-audits'), groupId: 'sites' }
  { name: 'app-commons', id: resourceId('Microsoft.Web/sites', '${prefix}-commons'), groupId: 'sites' }
  { name: 'app-notifications', id: resourceId('Microsoft.Web/sites', '${prefix}-notifications'), groupId: 'sites' }
  { name: 'app-userpermissions', id: resourceId('Microsoft.Web/sites', '${prefix}-userpermissions'), groupId: 'sites' }
  { name: 'app-processing', id: resourceId('Microsoft.Web/sites', '${prefix}-processing'), groupId: 'sites' }
  { name: 'openai', id: resourceId('Microsoft.CognitiveServices/accounts', '${prefix}-openai'), groupId: 'account' }
  { name: 'formrecognizer', id: resourceId('Microsoft.CognitiveServices/accounts', '${prefix}-formrecognizer'), groupId: 'account' }
  { name: 'cosmos-notifications', id: resourceId('Microsoft.DocumentDB/databaseAccounts', '${prefix}-notifications'), groupId: 'Sql' }
  { name: 'cosmos-data', id: resourceId('Microsoft.DocumentDB/databaseAccounts', '${prefix}-data'), groupId: 'Sql' }
  { name: 'cosmos-secaps', id: resourceId('Microsoft.DocumentDB/databaseAccounts', '${prefix}-secaps'), groupId: 'Sql' }
  { name: 'acr', id: resourceId('Microsoft.ContainerRegistry/registries', registryName), groupId: 'registry' }
  { name: 'search', id: resourceId('Microsoft.Search/searchServices', '${prefix}-search'), groupId: 'searchService' }
  { name: 'databricks', id: resourceId('Microsoft.Databricks/workspaces', '${prefix}-databricks'), groupId: 'databricks_ui_api' }
  { name: 'adf', id: resourceId('Microsoft.DataFactory/factories', '${prefix}-adf'), groupId: 'dataFactory' }
  { name: 'adf-portal', id: resourceId('Microsoft.DataFactory/factories', '${prefix}-adf'), groupId: 'portal' }
  { name: 'automation-jrds', id: resourceId('Microsoft.Automation/automationAccounts', '${prefix}-automation'), groupId: 'DSCAndHybridWorker' }
  { name: 'automation-webhook', id: resourceId('Microsoft.Automation/automationAccounts', '${prefix}-automation'), groupId: 'Webhook' }
]
var targets = concat(baseTargets, createDatabricksBrowserAuth ? [{
  name: 'databricks-browser'
  id: resourceId('Microsoft.Databricks/workspaces', '${prefix}-databricks')
  groupId: 'browser_authentication'
}] : [])
module endpoints 'modules/private-endpoint.bicep' = [for target in targets: {
  name: '${prefix}-pe-${target.name}'
  dependsOn: [storage, services, apps, databricks, factory]
  params: {
    name: '${prefix}-pe-${target.name}'
    location: location
    tags: tags
    subnetId: network.outputs.peSubnetId
    targetId: target.id
    groupId: target.groupId
  }
}]
module communications 'modules/communications.bicep' = {
  name: '${prefix}-communications'
  params: { prefix: prefix, tags: tags }
}
output vnetId string = network.outputs.id
output storageMapping array = [for (definition,i) in storageDefinitions: { origen: definition.original, destino: storage[i].outputs.name }]
output privateEndpointNames array = [for target in targets: '${prefix}-pe-${target.name}']
output adfId string = factory.outputs.id
output databricksUrl string = databricks.outputs.workspaceUrl
output registryHost string = services.outputs.registryHost
output applicationPrincipals array = [for (app,i) in appDefinitions: { app: app.key, principalId: apps[i].outputs.principalId }]
output adfPrincipalId string = factory.outputs.principalId
output databricksStoragePrincipalId string = databricks.outputs.accessConnectorPrincipalId
output communicationsId string = communications.outputs.id
