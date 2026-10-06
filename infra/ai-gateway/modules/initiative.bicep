param apimName string
param initiativeName string
param tenantId string
param audience string
param requiredRole string
param clientApplicationIds string[]
param accountName string
param deploymentName string
param apiVersion string
param requestsPerMinute int
param tokensPerMinute int
param monthlyTokenQuota int

func xml(value string) string => replace(replace(replace(replace(replace(value, '&', '&amp;'), '<', '&lt;'), '>', '&gt;'), '"', '&quot;'), '\'', '&apos;')

var clientIdsXml = join(map(clientApplicationIds, id => '<application-id>${xml(id)}</application-id>'), '')
var policyIdentity = replace(replace(replace(replace(loadTextContent('../policies/chat.xml'), '__TENANT__', xml(tenantId)), '__CLIENTS__', clientIdsXml), '__AUDIENCE__', xml(audience)), '__ROLE__', xml(requiredRole))
var policyLimits = replace(replace(replace(policyIdentity, '__RPM__', string(requestsPerMinute)), '__TPM__', string(tokensPerMinute)), '__MONTHLY__', string(monthlyTokenQuota))
var policy = replace(replace(replace(policyLimits, '__BACKEND__', 'ai-${xml(initiativeName)}'), '__DEPLOYMENT__', xml(uriComponent(deploymentName))), '__VERSION__', xml(apiVersion))

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = { name: apimName }
resource backend 'Microsoft.ApiManagement/service/backends@2024-05-01' = {
  parent: apim
  name: 'ai-${initiativeName}'
  properties: {
    protocol: 'http'
    url: 'https://${accountName}.openai.azure.com/openai'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}
resource api 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'ai-${initiativeName}'
  properties: {
    displayName: 'IA - ${initiativeName}'
    path: 'ai/${initiativeName}'
    protocols: ['https']
    subscriptionRequired: false
    apiType: 'http'
  }
}
resource operation 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: api
  name: 'chat-completions'
  properties: {
    displayName: 'Conversación con el modelo autorizado'
    method: 'POST'
    urlTemplate: '/chat/completions'
    responses: []
  }
  dependsOn: [apiPolicy]
}
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: policy
  }
  dependsOn: [backend]
}
output chatCompletionsUrl string = 'https://${apim.name}.azure-api.net/ai/${initiativeName}/chat/completions'
