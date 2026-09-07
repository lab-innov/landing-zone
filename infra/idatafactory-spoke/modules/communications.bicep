param prefix string
param tags object
resource email 'Microsoft.Communication/emailServices@2023-03-31' = {
  name: '${prefix}-email'
  location: 'global'
  tags: tags
  properties: { dataLocation: 'United States' }
}
resource domain 'Microsoft.Communication/emailServices/domains@2023-03-31' = {
  parent: email
  name: 'AzureManagedDomain'
  location: 'global'
  properties: { domainManagement: 'AzureManaged' }
}
resource communications 'Microsoft.Communication/communicationServices@2023-03-31' = {
  name: '${prefix}-communications'
  location: 'global'
  tags: tags
  properties: {
    dataLocation: 'United States'
    linkedDomains: [domain.id]
  }
}
output id string = communications.id
