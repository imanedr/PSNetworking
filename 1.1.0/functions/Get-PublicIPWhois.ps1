<#
.SYNOPSIS
    Retrieves public IP whois/geolocation information from a selected provider.

.DESCRIPTION
    Queries public IP address information (whois/geolocation) from one of several free providers: ip-api.com, ipapi.co, or ipinfo.io.
    Returns all data provided by the selected provider.

.PARAMETER IpAddress
    The IP address to query. If omitted, the provider will return info for your public IP.

.PARAMETER Provider
    The provider to use. Valid values: 'ip-api.com', 'ipapi.co', 'ipinfo.io'.
    Default is 'ip-api.com'.

.EXAMPLE
    Get-PublicIPWhois -IpAddress "8.8.8.8" -Provider "ipinfo.io"

.EXAMPLE
    Get-PublicIPWhois -Provider "ipapi.co"

.EXAMPLE
    Get-PublicIPWhois

.NOTES
    Free providers may have rate limits. Returned properties depend on provider.
#>
function Get-PublicIPWhois {
    [CmdletBinding()]
    param (
        [string]$IpAddress,
        [ValidateSet('ip-api.com','ipapi.co','ipinfo.io')]
        [string]$Provider = 'ip-api.com'
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

    $uri = & $providerMap[$Provider]
    try {
        $response = Invoke-RestMethod -Uri $uri -ErrorAction Stop
        $response | Add-Member -MemberType NoteProperty -Name Provider -Value $Provider -Force
        return $response
    } catch {
        Write-Warning "Failed to retrieve data from $Provider for IP $IpAddress"
        return $null
    }
}