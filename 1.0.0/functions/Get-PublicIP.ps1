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
