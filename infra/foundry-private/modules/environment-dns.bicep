param domain string
param ip string
param vnetId string
param tags object
resource dns 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: domain
  location: 'global'
  tags: tags
}
resource link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: dns
  name: 'container-apps'
  location: 'global'
  properties: { registrationEnabled: false, virtualNetwork: { id: vnetId } }
}
resource record 'Microsoft.Network/privateDnsZones/A@2024-06-01' = {
  parent: dns
  name: '*'
  properties: { ttl: 60, aRecords: [{ ipv4Address: ip }] }
}
