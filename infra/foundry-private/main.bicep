targetScope = 'resourceGroup'

@description('Región aprobada con soporte Foundry BYO VNet y Storage ZRS.')
param location string = resourceGroup().location
param tags object = {}
@description('Identificador estable del workload; no cambiar tras desplegar.')
@minLength(2)
@maxLength(12)
param workload string
@description('CIDR aprobados por CAF, sin valores predeterminados. Ver README.')
param prefixes object
@minLength(1)
param dnsServers array
@minLength(1)
param hubVnetId string
@minLength(1)
param hubFirewallIp string
param useRemoteGateways bool = false
@minLength(1)
param cafClientPrefixes array
@allowed(['policy', 'existing'])
@description('policy: DINE administra los grupos DNS; existing: usar IDs centrales explícitos.')
param privateDnsMode string = 'policy'
@description('IDs de zonas privadas existentes: foundry (tres), blob, agentBlob, vault, acr, cosmos, search; cada valor es un array.')
param privateDnsZoneIds object = {}
@description('Crear zona del dominio interno de ACA solo si CAF delega su gestión al spoke; de otro modo usar los outputs en DNS central.')
param createContainerEnvironmentDns bool = false
@description('Activar después de verificar endpoints privados, DNS y propagación de RBAC.')
param activateAgentRuntime bool = false
@description('Modelos autorizados con name, model, version, sku y capacity. Vacío no despliega modelos.')
param models array = []
@description('Activar después de publicar ambas imágenes en el ACR privado.')
param deployApplications bool = false
param frontendImage string = ''
param backendImage string = ''
param frontendPort int = 3000
param backendPort int = 8000
@description('Variables no secretas adicionales; deben corresponder al contrato real de cada imagen.')
param frontendEnv array = []
param backendEnv array = []
@description('Activar después de importar el certificado TLS en Key Vault y publicar DNS del sitio.')
param deployGateway bool = false
param gatewayPrivateIp string = ''
param gatewayHostname string = ''
@description('Nombre del secreto de certificado PFX en el Key Vault creado por esta plantilla.')
param certificateSecretName string = 'appgateway-tls'
param frontendHealthPath string = '/'

var token = uniqueString(resourceGroup().id, workload)
resource frontendIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-frontend-${token}'
  location: location
  tags: tags
}
resource backendIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-backend-${token}'
  location: location
  tags: tags
}
resource gatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-gateway-${token}'
  location: location
  tags: tags
}
module network './modules/network.bicep' = {
  name: 'red-foundry'
  params: {
    location: location
    tags: tags
    name: 'vnet-${workload}-${token}'
    prefixes: prefixes
    dnsServers: dnsServers
    hubVnetId: hubVnetId
    firewallIp: hubFirewallIp
    useRemoteGateways: useRemoteGateways
    clientPrefixes: cafClientPrefixes
  }
}
module services './modules/services.bicep' = {
  name: 'servicios-foundry'
  params: {
    location: location
    tags: tags
    token: token
    foundrySubnetId: network.outputs.foundrySubnetId
    backendPrincipalId: backendIdentity.properties.principalId
    frontendPrincipalId: frontendIdentity.properties.principalId
    gatewayPrincipalId: gatewayIdentity.properties.principalId
    models: models
  }
}
@batchSize(1)
module endpoints './modules/private-endpoint.bicep' = [
  for i in range(0, 7): {
    name: 'endpoint-${i}'
    params: {
      location: location
      tags: tags
      name: 'pe-${services.outputs.targets[i].name}-${token}'
      subnetId: network.outputs.peSubnetId
      targetId: services.outputs.targets[i].id
      groupId: services.outputs.targets[i].group
      zoneIds: privateDnsMode == 'policy' ? [] : privateDnsZoneIds[services.outputs.targets[i].name]
    }
  }
]
module agentRuntime './modules/agent-runtime.bicep' = if (activateAgentRuntime) {
  name: 'runtime-foundry-standard'
  params: {
    accountName: services.outputs.accountName
    projectPrincipalId: services.outputs.projectPrincipalId
    storageName: services.outputs.agentStorageName
    cosmosName: services.outputs.cosmosName
    searchName: services.outputs.searchName
  }
  dependsOn: [endpoints]
}
module apps './modules/apps.bicep' = {
  name: 'container-apps'
  params: {
    location: location
    tags: tags
    token: token
    subnetId: network.outputs.containerSubnetId
    gatewaySubnetPrefix: prefixes.appGateway
    frontendIdentityId: frontendIdentity.id
    backendIdentityId: backendIdentity.id
    backendClientId: backendIdentity.properties.clientId
    registryServer: services.outputs.registryServer
    projectEndpoint: services.outputs.projectEndpoint
    blobEndpoint: services.outputs.blobEndpoint
    vaultUri: services.outputs.vaultUri
    deployApplications: deployApplications
    frontendImage: frontendImage
    backendImage: backendImage
    frontendPort: frontendPort
    backendPort: backendPort
    frontendEnv: frontendEnv
    backendEnv: backendEnv
    createEnvironmentDns: createContainerEnvironmentDns
  }
  dependsOn: [endpoints]
}
module gateway './modules/gateway.bicep' = if (deployGateway) {
  name: 'application-gateway'
  params: {
    location: location
    tags: tags
    token: token
    subnetId: network.outputs.gatewaySubnetId
    privateIp: gatewayPrivateIp
    hostname: gatewayHostname
    backendFqdn: apps.outputs.frontendFqdn
    identityId: gatewayIdentity.id
    certificateSecretId: '${services.outputs.vaultUri}secrets/${certificateSecretName}'
    healthPath: frontendHealthPath
    workspaceId: apps.outputs.workspaceId
  }
}
output vnetId string = network.outputs.vnetId
output registryServer string = services.outputs.registryServer
output registryId string = services.outputs.registryId
output keyVaultUri string = services.outputs.vaultUri
output projectEndpoint string = services.outputs.projectEndpoint
output containerEnvironmentDomain string = apps.outputs.environmentDomain
output containerEnvironmentIp string = apps.outputs.environmentIp
output frontendFqdn string = apps.outputs.frontendFqdn
output applicationUrl string = deployGateway ? gateway!.outputs.url : ''
