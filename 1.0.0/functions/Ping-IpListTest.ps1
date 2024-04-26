function Ping-IpListTest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String[]]$ipList,
        [int]$Count = 4,
        [int]$BufferSize = 32,
        [switch]$DontFragment,
        [int]$Ttl = 128,
        [int]$Timeout = 5000,
        [switch]$Continuous,
        [switch]$ShowHistory,
        [int]$HistoryResetCount = 100
    )

    try {
        if ($Continuous) { $Count = -1 }
        $iCount = 0
        
        if ($ShowHistory) { 
            $pingHistory = @{}
            $timeoutCounters = @{}
            $ipList | foreach { 
                $pingHistory.Add($_, [System.Collections.ArrayList]@()) 
                $timeoutCounters[$_] = 0
            }

            while ($iCount -ne $Count) {
                $jobs = @()
                foreach ($ip in $ipList) {
                    $jobs += Start-ThreadJob -ScriptBlock {
                        param($ip, $BufferSize, $Ttl, $DontFragment, $Timeout)
                        $ping = New-Object System.Net.NetworkInformation.Ping
                        $pingOptions = New-Object System.Net.NetworkInformation.PingOptions ($Ttl, $DontFragment)
                        $bytes = [System.Text.Encoding]::ASCII.GetBytes(("a" * $BufferSize))
                        try {
                            $ping.Send($ip, $Timeout, $bytes, $pingOptions)
                        }
                        catch {
                            [System.Net.NetworkInformation.PingReply]::new()
                        }
                    } -ArgumentList $ip, $BufferSize, $Ttl, $DontFragment, $Timeout
                }
                
                $results = $jobs | Wait-Job | Receive-Job
                Remove-Job $jobs # Clean up

                Clear-Host
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), Ping sequence: $($iCount + 1)"
                foreach ($result in $results) {
                    $ip = ($result.Address).ToString()
                    if (-not $ip) {
                        $ip = $result.Options.Address.ToString() 
                    }

                    if ($result.Status -eq "Success") {
                        $pingHistory[$ip].Add($result.RoundtripTime)
                    }
                    else {
                        $pingHistory[$ip].Add("-")
                        $timeoutCounters[$ip]++
                    }

                    $pingHistory[$ip] = $pingHistory[$ip] | Select-Object -Last $HistoryResetCount

                    $paddingSize = 20 - $ip.length
                    Write-Host -NoNewline "Ip:"
                    Write-Host -ForegroundColor Green -NoNewline "$ip "
                    Write-Host -NoNewline "time:".PadLeft($paddingSize, " ")
                    Write-Host -ForegroundColor Green -NoNewline "$($result.RoundtripTime)ms "
                    if ($timeoutCounters[$ip] -gt 0) {
                        Write-Host -ForegroundColor Red "$($pingHistory[$ip]) Timeouts: $($timeoutCounters[$ip])"
                    }
                    else {
                        Write-Host "$($pingHistory[$ip])"
                    }
                }
                
                $iCount++
                Start-Sleep -Seconds 1
            }
        }
        else {
            while ($iCount -ne $Count) {
                $results = New-Object System.Collections.ArrayList
                foreach ($ip in $ipList) {
                    $ping = New-Object System.Net.NetworkInformation.Ping
                    $pingOptions = New-Object System.Net.NetworkInformation.PingOptions($Ttl, $DontFragment)
                    $pingResult = $ping.Send($ip, $Timeout, [System.Text.Encoding]::ASCII.GetBytes(("a" * $BufferSize)), $pingOptions)
    
                    $pingStatistics = [pscustomobject]@{
                        IPAddress   = ""
                        ResponsTime = [double]0.0
                        Result      = ""
                    }
    
    
                    if ($pingResult.Status -eq "Success") {
                        $pingStatistics.IPAddress = $ip
                        $pingStatistics.ResponsTime = $pingResult.RoundtripTime
                        $pingStatistics.Result = $pingResult.Status
                        $results += $pingStatistics
                    
                    }
                    else {
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
    finally {
        # Cleanup if needed
    }
}
