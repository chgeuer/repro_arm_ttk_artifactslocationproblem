@description('Location for all resources.')
param location string = resourceGroup().location

// https://github.com/Azure/azure-quickstart-templates/blob/master/1-CONTRIBUTION-GUIDE/best-practices.md#deployment-artifacts-nested-templates-scripts
@description('The base URI where artifacts required by this template are located including a trailing \'/\'')
param _artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated. Use the defaultValue if the staging location is not secured.')
@secure()
param _artifactsLocationSasToken string = ''

var meteringConfiguration = loadJsonContent('../meteringConfiguration.json')

resource publisherKeyVaultWithBootstrapSecret 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: meteringConfiguration.publisherVault.vaultName
  scope: resourceGroup(meteringConfiguration.publisherVault.publisherSubscription, meteringConfiguration.publisherVault.vaultResourceGroupName)
}

// The required code for setting up metering
module setupMeteredBillingConfigurationModule './nestedtemplates/meteredBillingDependencies.bicep' = {
  name: 'setupMeteredBillingConfiguration'
  params: {
    location: location
    artifactsLocation: _artifactsLocation
    artifactsLocationSasToken: _artifactsLocationSasToken
    bootstrapSecretValue: publisherKeyVaultWithBootstrapSecret.getSecret(meteringConfiguration.publisherVault.bootstrapSecretName)
    meteringConfiguration: meteringConfiguration
  }
}
