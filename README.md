
# Repro for the `The _artifactsLocation and _artifactsLocationSasToken parameters must not have a defaultValue in a nested template` problem

The [ARM TTK](https://github.com/Azure/arm-ttk/) is used by Azure Marketplace for manual validation of submitted managed applications. Unfortunately, ARM TTK complains about a problem related to the `_artifactsLocation` and `_artifactsLocationSasToken` parameters. 

In this repro, we compile a set of Bicep sources into an ARM JSON, which we validate using ARM TTK.

In `mainTemplate.bicep`, these 2 parameters either **have** default values,

```bicep
param _artifactsLocation string = deployment().properties.templateLink.uri

@secure()
param _artifactsLocationSasToken string = ''
```

or **don't**:

```bicep
param _artifactsLocation string

@secure()
param _artifactsLocationSasToken string
```

Subsequently, we passe these values down to a nested template (please note that I renamed the receiving parameters to avoid confusion):

```bicep
module nestedModule './nestedtemplates/meteredBillingDependencies.bicep' = {
  name: '...'
  params: {
    artifactsLocation: _artifactsLocation
    artifactsLocationSasToken: _artifactsLocationSasToken
  }
}
```

Note that in the nested template, the `artifactsLocation` and `artifactsLocationSasToken` parameters have no default values at all. 

## When using default values **in the main template**

When supplying default values in the *main* template,

```bicep
param _artifactsLocation string = deployment().properties.templateLink.uri

@secure()
param _artifactsLocationSasToken string = ''
```

we're getting a confusing error message, which says that **in a nested template**, there must be no default values. However, the nested template **has** no default values:

```text
Validating ARM-JSON\mainTemplate.json
  artifacts parameter
    [-] artifacts parameter (86 ms)
        The _artifactsLocation and _artifactsLocationSasToken parameters in "mainTemplate.json" 
        must not have a defaulValue in a nested template.
```

However, looking at the samples (https://github.com/Azure/azure-quickstart-templates/blob/master/1-CONTRIBUTION-GUIDE/best-practices.md#deployment-artifacts-nested-templates-scripts), this seems to be the correct way. 

But ARM TTK [artifacts-parameter.test.ps1](https://github.com/Azure/arm-ttk/blob/master/arm-ttk/testcases/deploymentTemplate/artifacts-parameter.test.ps1#L68) triggers the error. It seems the `$IsMainTemplate` isn't properly coming in...

## When removing the defaults in the main template

When removing the defaults for `_artifactsLocation` and `_artifactsLocationSasToken` in the main template, the validation from ARM TTK moves to the `createUiDefinition.json` file... 

```text
Validating ARM-JSON\createUiDefinition.json
  Parameters Without Default Must Exist In CreateUIDefinition
    [-] Parameters Without Default Must Exist In CreateUIDefinition (67 ms)
        _artifactsLocation does not have a default value, and is not defined in CreateUIDefinition.outputs
        _artifactsLocationSasToken does not have a default value, and is not defined in CreateUIDefinition.outputs
```

