cd .\ARM-JSON
Import-Module C:\github\Azure\arm-ttk\arm-ttk\arm-ttk.psd1 -Force
Test-AzTemplate -TemplatePath . -MainTemplateFile .\mainTemplate.json
