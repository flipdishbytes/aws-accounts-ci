$workload_name = $env:workload_name
$ou_name = $env:ou_name
$cache_path = $env:cache_path
$cache_hit = $env:cache_hit

if (-not $workload_name -or -not $ou_name) {
    Write-Output "workload_name and ou_name must be set."
    exit 1
}

# AWS account IDs are 12-digit numeric strings.
$accountIdPattern = '^\d{12}$'

function Remove-CacheFile {
    if ($cache_path -and (Test-Path $cache_path)) {
        Remove-Item $cache_path -Force -ErrorAction SilentlyContinue
    }
}

# Short-circuit on cache hit: read the previously stored account ID and skip the API call.
if ($cache_hit -eq 'true' -and $cache_path -and (Test-Path $cache_path)) {
    $cachedAccountId = (Get-Content $cache_path -Raw).Trim()
    if ($cachedAccountId -match $accountIdPattern) {
        Write-Output "Cache hit: '$ou_name-$workload_name' account is: $cachedAccountId"
        if ($env:GITHUB_OUTPUT) {
            "accountId=$cachedAccountId" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
        }
        exit 0
    }
    Write-Output "Cached value invalid; falling through to API call."
    Remove-CacheFile
}

# Defensive: ensure the cache file does not exist before the API call so a
# failed/error response can never be picked up by actions/cache's post-step.
Remove-CacheFile

$apiUrl = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("aHR0cHM6Ly9lMXp2cG51cDNkLmV4ZWN1dGUtYXBpLmV1LXdlc3QtMS5hbWF6b25hd3MuY29tL2F3cy1nb3Zlcm5hbmNlL2FjY291bnQtaWQ="))

try {
    $response = Invoke-WebRequest -Uri $apiUrl -Method GET -Body @{ workload_name = $workload_name; ou_name = $ou_name }

    if ($response.StatusCode -ne 200) {
        Remove-CacheFile
        Write-Output "Unexpected status code $($response.StatusCode); not caching."
        exit 1
    }

    $body = $response.Content | ConvertFrom-Json

    if (-not $body.accountId) {
        Remove-CacheFile
        Write-Output "200 response missing accountId; not caching."
        exit 1
    }

    if ($body.accountId -notmatch $accountIdPattern) {
        Remove-CacheFile
        Write-Output "accountId '$($body.accountId)' is not a 12-digit AWS account ID; not caching."
        exit 1
    }

    Write-Output "The Id for '$ou_name-$workload_name' account is: $($body.accountId)"

    if ($env:GITHUB_OUTPUT) {
        "accountId=$($body.accountId)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }

    # Cache only after we've confirmed 200 + valid 12-digit accountId.
    if ($cache_path) {
        $body.accountId | Out-File -FilePath $cache_path -Encoding utf8 -NoNewline
    }
}
catch {
    # Belt-and-braces: make sure no partial file exists after a failure.
    Remove-CacheFile

    if ($_.Exception.Response.StatusCode -eq 404) {
        try {
            Write-Output ($_.ErrorDetails.Message | ConvertFrom-Json).error
        }
        catch {
            Write-Output "404: account not found"
        }
    }
    else {
        Write-Output "Error calling API: $($_.Exception.Message)"
    }
    exit 1
}