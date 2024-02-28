@description('Location for all resources.')
param location string

@description('Location for scripts etc.')
param artifactsLocation string

@description('SAS token to access scripts etc.')
@secure()
param artifactsLocationSasToken string

@description('The bootstrap secret to request service principal creation')
@secure()
param bootstrapSecretValue string

@description('The metering configuration object')
param meteringConfiguration object = {
  servicePrincipalCreationURL: 'https://my-rest-api.contoso.com'
  amqpEndpoint: 'https://metering-contoso.servicebus.windows.net/metering'
  publisherVault: {
    publisherSubscription: '{isvSubscriptionId}'
    vaultResourceGroupName: '...'
    vaultName: '...'
    bootstrapSecretName: 'BootstrapSecret'
  }
}

var names = {
  identity: {
    setup: 'uami-setup'
  }
  runtimeKeyVault: {
    name: 'kvchgp${uniqueString(resourceGroup().id)}'
    meteringSubmissionSecretName: 'meteringsubmissionconnection'
  }
  deploymentScript: {
    name: 'deploymentScriptCreateSP'
    azCliVersion: '2.36.0'
  }
  managedApp: {
    managedBy: resourceGroup().managedBy
    resourceGroupName: split(resourceGroup().managedBy, '/')[4]
    appName: split(resourceGroup().managedBy, '/')[8]
  }
}

var roles = {
  Owner: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  Contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  Reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  KeyVault: {
    KeyVaultSecretsOfficer: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
    KeyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  }
}

resource setupIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: names.identity.setup
  location: location
}

resource setupIdentityIsContributorOnManagedResourceGroup 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(setupIdentity.id, roles.Contributor, resourceGroup().id)
  scope: resourceGroup()
  properties: {
    description: '${setupIdentity.name} should be Contributor on the managed resource group'
    principalType: 'ServicePrincipal'
    principalId: reference(setupIdentity.id, '2023-01-31').principalId
    delegatedManagedIdentityResourceId: setupIdentity.id
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.Contributor)    
  }
}

resource runtimeKeyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: names.runtimeKeyVault.name
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: false
    networkAcls: {
       bypass: 'AzureServices'
       defaultAction: 'Allow'
    }
  }  
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = { 
  name: names.deploymentScript.name
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: names.deploymentScript.azCliVersion
    timeout: 'PT10M'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnExpiration'
    containerSettings: {
      containerGroupName: uniqueString(resourceGroup().id, names.deploymentScript.name)
    }
    primaryScriptUri: uri(artifactsLocation, 'scripts/triggerServicePrincipalCreation.sh${artifactsLocationSasToken}')
    environmentVariables: [
      { name: 'SERVICE_PRINCIPAL_CREATION_URL',      value:       meteringConfiguration.servicePrincipalCreationURL  }
      { name: 'BOOTSTRAP_SECRET_VALUE',              secureValue: bootstrapSecretValue                               }
      { name: 'MANAGED_BY',                          value:       names.managedApp.managedBy                         }
    ]
  }
}

resource publisherKeyVaultWithBootstrapSecret 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: meteringConfiguration.publisherVault.vaultName
  scope: resourceGroup(meteringConfiguration.publisherVault.publisherSubscription, meteringConfiguration.publisherVault.vaultResourceGroupName)
}

module setServicePrincipalSecret 'setSecret.bicep' = {
  // Take the secretName output from the deploymentScript, 
  // fetch the actual service principal credential from the publisher KeyVault, 
  // and store it in the runtime KeyVault.
  name: 'setServicePrincipalSecret'
  params: {
    vaultName: runtimeKeyVault.name
    secretName: names.runtimeKeyVault.meteringSubmissionSecretName
    secretValue: publisherKeyVaultWithBootstrapSecret.getSecret(reference(deploymentScript.id).outputs.secretName)
    managedBy: names.managedApp.managedBy
  }
}
