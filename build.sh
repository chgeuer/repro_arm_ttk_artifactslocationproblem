#!/bin/bash


zipDir="$(pwd)/zip"
[[ -d "$zipDir" ]] || mkdir "$zipDir" 

az bicep build --stdout --file src/mainTemplate.bicep > "${zipDir}/mainTemplate.json"

cp    src/createUiDefinition.json "${zipDir}"
cp -a src/scripts                 "${zipDir}"
