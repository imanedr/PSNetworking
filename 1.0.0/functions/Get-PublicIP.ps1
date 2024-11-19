
<#
.SYNOPSIS
    Continuously monitors and displays your public IP address.

.DESCRIPTION
    The Get-PublicIP function queries an external API service (ip-api.com) to retrieve and display your current public IP address. 
    It runs in a continuous loop, checking every 3 seconds, and highlights any changes in the IP address.

.EXAMPLE
    Get-PublicIP
    Returns and continuously monitors your public IP address, displaying timestamps with each check.

.NOTES
    Author: PSNetworking Toolkit
    Version: 1.0.0
    Requires: PowerShell 5.1 or higher
    Dependencies: Internet connection
    
.LINK
    https://github.com/imanedr/psnetworking

.OUTPUTS
    System.String
    Displays timestamp and public IP address, with color-coded output for IP changes
#>
Function Get-PublicIP
{
    $previousPublicIP = ''
    $firstRun = $True
    $publicIpProviderURL= "http://ip-api.com/json/"
    #$publicIpProviderURL= "http://checkip.dyndns.org"
    While ($True)
    {
        try
        {
            $ProgressPreference = 'SilentlyContinue'
            $publicIP = (Invoke-RestMethod -Uri $publicIpProviderURL ).query
            $ProgressPreference = 'Continue'   
           
            if ($firstRun)
            {
                $previousPublicIP = $publicIP
                $firstRun = $false
            }

            if ($publicIP -ne $previousPublicIP)
            {
                Write-Host "$(Get-Date) - Public IP address changed to: $publicIP" -ForegroundColor Green
                $previousPublicIP = $publicIP
            }
            else
            {
                Write-Host "$(Get-Date) - Public IP address: $publicIP"
            }
        }
        catch
        {
            Write-Host "$(Get-Date) - Error: API call timed out." -ForegroundColor Red
        }
        Start-Sleep -Seconds 3
    }
}
