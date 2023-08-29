function Ping-IpList
{
   
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String[]]$ipList,
        [int]$Count = 4,
        [int]$BufferSize = 32,
        [switch]$DontFragment,
        [int]$Ttl = 128,
        [int]$Timeout = 5000,
        [switch]$Continuous
    )
   

    try
    {
        if ($Continuous) { $Count = -1 }
        $iCount = 0
   
        while ($iCount -ne $Count)
        {
            $results = New-Object System.Collections.ArrayList
            foreach ($ip in $ipList)
            {
                $ping = New-Object System.Net.NetworkInformation.Ping
                $pingOptions = New-Object System.Net.NetworkInformation.PingOptions($Ttl, $DontFragment)
                $pingResult = $ping.Send($ip, $Timeout, [System.Text.Encoding]::ASCII.GetBytes(("a" * $BufferSize)), $pingOptions)

                $pingStatistics = [pscustomobject]@{
                    IPAddress   = ""
                    ResponsTime = [double]0.0
                    Result      = ""
                }

                if ($pingResult.Status -eq "Success")
                {
                    $pingStatistics.IPAddress = $ip
                    $pingStatistics.ResponsTime = $pingResult.RoundtripTime
                    $pingStatistics.Result = $pingResult.Status
                    $results+= $pingStatistics
                
                }
                else
                {
                    $pingStatistics.IPAddress = $ip
                    $pingStatistics.ResponsTime = 9999
                    $pingStatistics.Result = $pingResult.Status
                    $results+= $pingStatistics
                }
            }
            Clear-Host
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), Ping sequnce: $iCount"
            Write-Output $results | Format-Table -RepeatHeader
            $iCount++
            Start-Sleep -Seconds 1
        }
    }
    finally
    {
       
    }
    
}

