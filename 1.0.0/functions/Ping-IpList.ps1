function Ping-IpList
{
   
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String[]]$ipList,
        [string]$range,
        [string]$cidr,
        [int]$Count = 4,
        [int]$BufferSize = 32,
        [switch]$DontFragment,
        [int]$Ttl = 128,
        [int]$Timeout = 100,
        [switch]$Continuous,
        [switch]$ShowHistory,
        [int]$HistoryResetCount = 100
    )
   
    if ($range)
    {
        $ipList = Get-IpAddressesInRange $range
    }
    elseif ($cidr)
    {
        $ipList = Get-IPAddressesInSubnet $cidr
    }
    else
    {
        # Trim leading or trailing white spaces from each entry in the list
        $ipList = $ipList | ForEach-Object { $_.Trim() }

        # Removing any non-IP addresses or blank entry from the list
        $ipList = $ipList -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"

        # Check if the list does not contain any hostnames
        if (($ipList -match "^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$").Count -eq 0)
        {
            $ipList = Sort-IpAddress $ipList
        }
    }
    
    try
    {
        if ($Continuous) { $Count = -1 }
        $iCount = 0
        
        if ($ShowHistory)
        { 
            $pingHistory = [ordered]@{} 
            $ipList.foreach({ $pingHistory.Add($_, "") })
            $pingHistory | Out-Null
            while ($iCount -ne $Count)
            {
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
    
                    if ($pingHistory.item($ip).Result.length -eq $HistoryResetCount ) { $pingHistory.item($ip).Result = "" }
                    if ($pingResult.Status -eq "Success")
                    {
                        $pingStatistics.IPAddress = $ip
                        $pingStatistics.ResponsTime = $pingResult.RoundtripTime
                        $pingStatistics.Result = $pingHistory.item($ip).Result + "!"
                        $pingHistory.item($ip) = $pingStatistics
                    
                    }
                    else
                    {
                        $pingStatistics.IPAddress = $ip
                        $pingStatistics.ResponsTime = "-"
                        $pingStatistics.Result = $pingHistory.item($ip).Result + "."
                        $pingHistory.item($ip) = $pingStatistics
                    }
                }
                Clear-Host
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), Ping sequnce: $($iCount + 1)"
                foreach ($item in $pingHistory.Values)
                {
                    $paddingSize = 20 - $item.IPAddress.length
                    if ($paddingSize -lt 0) { $paddingSize = 0 }
                    Write-Host -NoNewline "Ip:"
                    Write-Host -ForegroundColor Green -NoNewline "$($item.IPAddress) "
                    Write-Host -NoNewline "time:".PadLeft($paddingSize, " ")
                    Write-Host -ForegroundColor Green -NoNewline "$($item.ResponsTime) "
                    if ($item.Result -like "*.*")
                    {
                        Write-Host -ForegroundColor Red "$($item.Result)"
                    }
                    else
                    {
                        Write-Host "$($item.Result)"
                    }
                    
                }
      
                
                $iCount++
                Start-Sleep -Seconds 1
            }

        }
        else
        {
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
                        $results += $pingStatistics
                    
                    }
                    else
                    {
                        $pingStatistics.IPAddress = $ip
                        $pingStatistics.ResponsTime = "-"
                        $pingStatistics.Result = $pingResult.Status
                        $results += $pingStatistics
                    }
                }
                Clear-Host
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), Ping sequnce: $($iCount + 1)"
                Write-Output $results | Format-Table -RepeatHeader
      
                
                $iCount++
                Start-Sleep -Seconds 1
            }
        }
        
    }
    finally
    {
       
    }
    
}

