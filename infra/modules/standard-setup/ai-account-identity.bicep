param accountName string
param location string
param modelDeployments array
param networkIsolation bool = false
param agentSubnetId string
param deployAiFoundrySubnet bool = true
param accountExists bool = false

param useUAI bool = false
param userAssignedIdentityResourceId string
param userAssignedIdentityPrincipalId string

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = if (!accountExists) {
  name: accountName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: (useUAI) ? 'UserAssigned' : 'SystemAssigned'
    userAssignedIdentities: useUAI ? { '${userAssignedIdentityResourceId}': {} } : null
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: networkIsolation ? 'Deny' : 'Allow'
      virtualNetworkRules: networkIsolation && deployAiFoundrySubnet ? [
        {
          id: agentSubnetId
          ignoreMissingVnetServiceEndpoint: true
        }
      ] : null
      ipRules: []
    }
    publicNetworkAccess: 'Enabled' //this is because the firewall allows the subnets //networkIsolation ? 'Disabled' : 'Enabled'
    #disable-next-line BCP036
    networkInjections: ((networkIsolation && deployAiFoundrySubnet) ? [
      {
        scenario: 'agent'
        subnetArmId: agentSubnetId
        useMicrosoftManagedNetwork: false
      }
    ] : null)

    // API-key based auth is not supported for the Agent service
    disableLocalAuth: false
  }
}

resource accountExisting 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = if (accountExists) {
  name: accountName
}

// Model Deployments Resource

@batchSize(1)
resource modelDeploymentNew 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = [
  for deployment in modelDeployments: if (!accountExists) {
    parent: account
    name: deployment.name
    sku: {
      name: deployment.type
      capacity: deployment.capacity
    }
    properties: {
      model: {
        name: deployment.model
        format: deployment.modelFormat
        version: deployment.version
      }
    }
  }
]

@batchSize(1)
resource modelDeploymentExisting 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = [
  for deployment in modelDeployments: if (accountExists) {
    parent: accountExisting
    name: deployment.name
    sku: {
      name: deployment.type
      capacity: deployment.capacity
    }
    properties: {
      model: {
        name: deployment.model
        format: deployment.modelFormat
        version: deployment.version
      }
    }
  }
]

output accountName string = accountExists ? accountExisting.name : account.name
output accountID string = accountExists ? accountExisting.id : account.id
output accountTarget string = accountExists ? accountExisting.properties.endpoint : account.properties.endpoint
output accountPrincipalId string = (useUAI)
  ? userAssignedIdentityPrincipalId
  : (accountExists ? accountExisting.identity.principalId : account.identity.principalId)
