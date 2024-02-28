#!/bin/bash

outputArmJsonDir="$(pwd)/ARM-JSON"
[[ -d "$outputArmJsonDir" ]] || mkdir "$outputArmJsonDir" 

az bicep build --stdout --file src/mainTemplate.bicep > "${outputArmJsonDir}/mainTemplate.json"

cp    src/createUiDefinition.json "${outputArmJsonDir}"
cp -a src/scripts                 "${outputArmJsonDir}"
