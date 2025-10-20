<#
.SYNOPSIS
    Retrieves public IP address information and WHOIS-like details from multiple providers.

.DESCRIPTION
    The Get-PublicIPWhois function queries one or more public IP information providers (ip-api.com, ipapi.co, ipinfo.io)
    for details about a specified IP address. If no provider is specified, it queries all providers and merges the results,
    deduplicating fields and preferring the first non-null value found.

.PARAMETER IpAddress
    The public IP address to query. If omitted, your own public IP will be used.

.PARAMETER Provider
    The provider to query. Valid values are 'ip-api.com', 'ipapi.co', and 'ipinfo.io'.
    If omitted, all providers are queried and results are merged.

.EXAMPLE
    Get-PublicIPWhois -IpAddress 8.8.8.8 -Provider ipinfo.io

    Retrieves information about 8.8.8.8 from ipinfo.io.

.EXAMPLE
    Get-PublicIPWhois -IpAddress 8.8.8.8

    Retrieves information about 8.8.8.8 from all providers and merges the results.

.EXAMPLE
    Get-PublicIPWhois

    Retrieves information about your own public IP from all providers and merges the results.

.NOTES
    Merged results may contain fields from all providers, with duplicate fields merged and the first non-null value used.
#>
function Get-PublicIPWhois {
    [CmdletBinding()]
    param (
        [string]$IpAddress,
        [ValidateSet('ip-api.com','ipapi.co','ipinfo.io')]
        [string]$Provider
    )

    $providerMap = @{
        'ip-api.com' = { 
            if ($IpAddress) { "http://ip-api.com/json/$IpAddress" } else { "http://ip-api.com/json/" }
        }
        'ipapi.co' = { 
            if ($IpAddress) { "https://ipapi.co/$IpAddress/json/" } else { "https://ipapi.co/json/" }
        }
        'ipinfo.io' = { 
            if ($IpAddress) { "https://ipinfo.io/$IpAddress/json" } else { "https://ipinfo.io/json" }
        }
    }

    function Merge-Objects {
        param([Parameter(ValueFromPipeline)]$Objects)
        $merged = @{}
        foreach ($obj in $Objects) {
            foreach ($prop in $obj.PSObject.Properties) {
                if (-not $merged.ContainsKey($prop.Name) -or $null -eq $merged[$prop.Name]) {
                    $merged[$prop.Name] = $prop.Value
                }
            }
        }
        return [PSCustomObject]$merged
    }

    if ($Provider) {
        $uri = & $providerMap[$Provider]
        try {
            $response = Invoke-RestMethod -Uri $uri -ErrorAction Stop
            $response | Add-Member -MemberType NoteProperty -Name Provider -Value $Provider -Force
            return $response
        } catch {
            Write-Warning "Failed to retrieve data from $Provider for IP $IpAddress"
            return $null
        }
    } else {
        $results = @()
        foreach ($prov in $providerMap.Keys) {
            $uri = & $providerMap[$prov]
            try {
                $resp = Invoke-RestMethod -Uri $uri -ErrorAction Stop
                $resp | Add-Member -MemberType NoteProperty -Name Provider -Value $prov -Force
                $results += $resp
            } catch {
                Write-Warning "Failed to retrieve data from $prov for IP $IpAddress"
            }
        }
        if ($results.Count -eq 0) { return $null }
        return Merge-Objects $results
    }
}