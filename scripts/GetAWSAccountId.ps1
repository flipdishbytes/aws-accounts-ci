$workload_name = $env:workload_name 
$ou_name = $env:ou_name

if (-not $workload_name -or -not $ou_name) {
    Write-Output "workload_name and ou_name must be set."
    exit 1
}

$apiUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("aHR0cHM6Ly9lMXp2cG51cDNkLmV4ZWN1dGUtYXBpLmV1LXdlc3QtMS5hbWF6b25hd3MuY29tL2F3cy1nb3Zlcm5hbmNlL2FjY291bnQtaWQ="))

try {
    $response = Invoke-WebRequest -Uri $apiUrl -Method GET -Body @{ workload_name = $workload_name; ou_name = $ou_name } | ConvertFrom-Json
    
    if ($response.accountId) {
        Write-Output "The Id for '$ou_name-$workload_name' account is: $($response.accountId)"
        
        if ($env:GITHUB_OUTPUT) {
            "accountId=$($response.accountId)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        }
    }
    else {
        Write-Output "No account ID found in the API response."
        exit 1
    }
}
catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Output ($_.ErrorDetails.Message | ConvertFrom-Json).error
    }
    else {
        Write-Output "Error calling API: $($_.Exception.Message)"
    }
    exit 1
}