param location string
param tags object
param token string
param subnetId string
param gatewaySubnetPrefix string
param frontendIdentityId string
param backendIdentityId string
param backendClientId string
param registryServer string
param projectEndpoint string
param blobEndpoint string
param vaultUri string
@description('Imágenes existentes en el ACR de este despliegue; usar digest o etiqueta inmutable.')
param frontendImage string
param backendImage string
param frontendPort int
param backendPort int
param deployApplications bool
param frontendEnv array
param backendEnv array
param createEnvironmentDns bool

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-${token}'
  location: location
  tags: tags
  properties: { retentionInDays: 30, sku: { name: 'PerGB2018' } }
}
resource insights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${token}'
  location: location
  tags: tags
  kind: 'web'
  properties: { Application_Type: 'web', WorkspaceResourceId: workspace.id }
}
resource environment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: 'cae-${token}'
  location: location
  tags: tags
  properties: {
    vnetConfiguration: { infrastructureSubnetId: subnetId, internal: true }
    workloadProfiles: [{ name: 'Consumption', workloadProfileType: 'Consumption' }]
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.properties.customerId
        sharedKey: workspace.listKeys().primarySharedKey
      }
    }
  }
}
module environmentDns './environment-dns.bicep' = if (createEnvironmentDns) {
  name: 'dns-container-apps'
  params: {
    domain: environment.properties.defaultDomain
    ip: environment.properties.staticIp
    vnetId: substring(subnetId, 0, lastIndexOf(subnetId, '/subnets/'))
    tags: tags
  }
}
resource backend 'Microsoft.App/containerApps@2025-01-01' = if (deployApplications) {
  name: 'backend-${token}'
  location: location
  tags: tags
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${backendIdentityId}': {} } }
  properties: {
    managedEnvironmentId: environment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: { external: false, targetPort: backendPort, transport: 'auto', allowInsecure: false }
      registries: [{ server: registryServer, identity: backendIdentityId }]
    }
    template: {
      containers: [
        {
          name: 'backend'
          image: backendImage
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: concat(
            [
              { name: 'AZURE_CLIENT_ID', value: backendClientId }
              { name: 'AZURE_AI_PROJECT_ENDPOINT', value: projectEndpoint }
              { name: 'AZURE_STORAGE_BLOB_ENDPOINT', value: blobEndpoint }
              { name: 'AZURE_STORAGE_CONTAINER', value: 'uploads' }
              { name: 'AZURE_KEY_VAULT_URL', value: vaultUri }
              { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: insights.properties.ConnectionString }
            ],
            backendEnv
          )
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 3 }
    }
  }
}
resource frontend 'Microsoft.App/containerApps@2025-01-01' = if (deployApplications) {
  name: 'frontend-${token}'
  location: location
  tags: tags
  identity: { type: 'UserAssigned', userAssignedIdentities: { '${frontendIdentityId}': {} } }
  properties: {
    managedEnvironmentId: environment.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      // external=true expone a la VNet; el entorno sigue siendo interno.
      ingress: {
        external: true
        targetPort: frontendPort
        transport: 'auto'
        allowInsecure: false
        ipSecurityRestrictions: [{ name: 'solo-appgateway', action: 'Allow', ipAddressRange: gatewaySubnetPrefix }]
      }
      registries: [{ server: registryServer, identity: frontendIdentityId }]
    }
    template: {
      containers: [
        {
          name: 'frontend'
          image: frontendImage
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: concat(
            [{ name: 'BACKEND_URL', value: 'https://${backend!.properties.configuration.ingress.fqdn}' }],
            frontendEnv
          )
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 3 }
    }
  }
}
output frontendFqdn string = deployApplications ? frontend!.properties.configuration.ingress.fqdn : ''
output environmentDomain string = environment.properties.defaultDomain
output environmentIp string = environment.properties.staticIp
output workspaceId string = workspace.id
