Function Get-PublicIP
{
    $previousPublicIP = ''
    $firstRun = $True
    While ($True)
    {
        try
        {
            $ProgressPreference = 'SilentlyContinue'
            $publicIP = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 6 'http://checkip.dyndns.org').Content -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"
            $ProgressPreference = 'Continue'   
            $publicIP = $Matches[0]
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
