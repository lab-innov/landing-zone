using '../../infra/ai-gateway/foundation.bicep'

param location = 'PENDIENTE-REGION'
param apimName = 'PENDIENTE-APIM'
param publisherName = 'PENDIENTE-RESPONSABLE'
param publisherEmail = 'pendiente@example.invalid'
param integrationSubnetId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/PENDIENTE/providers/Microsoft.Network/virtualNetworks/PENDIENTE/subnets/PENDIENTE-integracion'
param privateEndpointSubnetId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/PENDIENTE/providers/Microsoft.Network/virtualNetworks/PENDIENTE/subnets/PENDIENTE-endpoints'
param stage = 'privada'
param logAnalyticsWorkspaceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/PENDIENTE/providers/Microsoft.OperationalInsights/workspaces/PENDIENTE'
param tags = {
  workload: 'ai-gateway'
  environment: 'PENDIENTE'
  owner: 'PENDIENTE'
}
