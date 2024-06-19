# Prompt for username
$username = Read-Host "Enter your username (e.g., james.bond@domain.int)"

# Prompt for authSource
$authSource = Read-Host "Specify the authentication source (e.g., vIDMAuthSource)"

# Prompt for password
$password = Read-Host "Enter your password" -AsSecureString

#Prompt for AOps hostname
$vropsHostname = Read-Host "Type/Paste in the AOps hostname"

# Convert secure string to plain text
$passwordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))

# Login to vrops API and get auth token
$loginUri = "https://$vropsHostname/suite-api/api/auth/token/acquire?_no_links=true"
$loginData = @{
    username = $username
    authSource = $authSource
    password = $passwordPlainText
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri $loginUri -Method POST -Body $loginData -ContentType "application/json" -Headers @{"Accept"="application/json"} -UseBasicParsing
$token = $response.token

#Show token response
Write-Host "Auth Token: $token"

# Read CSV (URL,Port) for 'customscripts'
$SourceCSV = "C:\temp\ssl.csv"

# Ask for a VM (with agent running)
$VMwithAgent = Read-Host "Name of the VM running Telegraf Agent"

# Get vROPS object ID by VM name
$objectUri = "https://$vropsHostname/suite-api/api/resources?resourceKind=VirtualMachine&name=$VMwithAgent"
$objectResponse = Invoke-RestMethod -Uri $objectUri -Method GET -Headers @{"Accept"="application/json"; "Authorization"="vRealizeOpsToken $token"} -UseBasicParsing
$AgentID = $objectResponse.resourceList.identifier

#Prep the vRO/AOps URL
$vRopsURL = "https://$($vropsHostname)/suite-api/api/applications/agents/$($AgentID)/services?_no_links=true"

#Read the CSV
$Data = Get-Content -Path $SourceCSV | ConvertFrom-Csv

#Populate the Config for each Custom Script from the CSV Rows.
$Configurations = $Data | ForEach-Object {
    @{
        configName = "SSL Expiry - $($_.URL):$($_.Port) on $VMwithAgent"
        isActivated = $true
        parameters = @(
            @{
                key = "ARGS"
                value = "$($_.URL) $($_.Port)"
            },
            @{
                key = "TIMEOUT"
                value = "60"
            },
            @{
                key = "PREFIX"
                value = ""
            },
            @{
                key = "FILE_PATH"
                value = "/opt/vmware/any-ssl-check.sh"
            }
        )
    }
}

#Populate the "customscript" with the configurations created above.
$PostObject = @{
    services = @(
        @{
            serviceName = "customscript"
            configurations = $Configurations
        }
    )
}

# Define the headers
$headers = @{
    "Accept" = "application/json"
    "Authorization" = "OpsToken $token"
    "Content-Type" = "application/json"
}

#JSON'fy the populated items
$Json = $PostObject | ConvertTo-Json -Depth 10

#uncomment if you want to see the POST JSON.
#Write-Host $Json

#DO THE THINGS
Invoke-RestMethod -Method Post -Uri $vRopsURL -Body $Json -Headers $headers -UseBasicParsing

# Symptom create for each row in the CSV...
foreach ($row in $Data) {
    # Create a symptom for the custom metric
    $symptomUri = "https://$vropsHostname/suite-api/api/symptomdefinitions"
    $symptomData = @{
        name = "SSL Countdown for $($row.URL):$($row.Port)"
        #Telegraf Agent Adapater / Task type
        adapterKindKey = "APPOSUCP"
        resourceKindKey = "executescript"
        waitCycles = 1
        cancelCycles = 1
        state = @{
            severity = "WARNING"
            condition = @{
                type = "CONDITION_HT"
                key = "scripts|$configName $($row.URL):$($row.Port)"
                operator = "LT"
                #ADJUST WARNING VALUE AS NEEDED
                value = "30"
                valueType = "NUMERIC"
                instanced = $false
                thresholdType = "STATIC"
            }
        }
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $symptomUri -Method POST -Body $symptomData -Headers $headers -UseBasicParsing
}
