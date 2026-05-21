targetScope = 'resourceGroup'

param location string
param tags object = {}
param accountName string
param projectName string
param customSubdomain string
param agentSubnetResourceId string
param disableLocalAuth bool = true
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

var defaultAction = publicNetworkAccess == 'Disabled' ? 'Deny' : 'Allow'

resource account 'Microsoft.CognitiveServices/accounts@2026-01-15-preview' = {
  name: accountName
  location: location
  tags: tags
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: customSubdomain
    disableLocalAuth: disableLocalAuth
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: defaultAction
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
    networkInjections: [
      {
        scenario: 'agent'
        subnetArmId: agentSubnetResourceId
        useMicrosoftManagedNetwork: false
      }
    ]
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  name: projectName
  parent: account
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Base spoke default project'
  }
}

output accountResourceId string = account.id
output projectResourceId string = project.id
