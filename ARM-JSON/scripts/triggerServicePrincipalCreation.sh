#!/bin/bash

secretName="verySecret"

output="$( echo "{}" | jq --arg x "${secretName}" '.secretName=$x' )"

# https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deployment-script-template?tabs=CLI#work-with-outputs-from-cli-script
echo "${output}" > "${AZ_SCRIPTS_OUTPUT_PATH}"
