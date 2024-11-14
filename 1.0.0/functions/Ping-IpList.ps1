function Ping-IpListV2 {
   
    [CmdletBinding()]
    param (
        [switch]$FromClipBoard,
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
        [int]$HistoryResetCount = 100,
        [switch]$DontSortIpList,
        [int]$MaxThreads = 100
    )
   
    if ($range) {
        $ipList = Get-IpAddressesInRange $range
    }
    elseif ($cidr) {
        $ipList = Get-IPAddressesInSubnet $cidr
    }
    else {
        if ($FromClipBoard) { $ipList = Get-Clipboard }
        # Trim leading or trailing white spaces from each entry in the list
        $ipList = $ipList | ForEach-Object { $_.Trim() }

        # Removing any non-IP addresses or blank entry from the list
        $ipList = $ipList -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}|^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"

        # Check if the list does not contain any hostnames
        if (-not $DontSortIpList) {
            if (($ipList -match "^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$").Count -eq 0) {
                $ipList = Sort-IpAddress $ipList
            }
        }
    }
    
    try {
        if ($Continuous) { $Count = -1 }
        $iCount = 0
        $pingHistory = [ordered]@{} 

        while ($iCount -ne $Count) {
               
            # Create and open a runspace pool
            $pool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
            $pool.Open()

            # Collect the runspaces
            $runspaces = New-Object System.Collections.ArrayList

            foreach ($ip in $ipList) {
                # Prepare a script block to run in parallel
                $scriptBlock = {
                    param($ip, $BufferSize, $Ttl, $DontFragment, $Timeout, $HistoryResetCount)
                    function Send-Ping {
                        [CmdletBinding()]
                        param (
                            [string]$target,
                            [int]$BufferSize = 32,
                            [switch]$DontFragment,
                            [int]$Ttl = 128,
                            [int]$Timeout = 100 
                        )
    
                        $ping = New-Object System.Net.NetworkInformation.Ping
                        $pingOptions = New-Object System.Net.NetworkInformation.PingOptions($Ttl, $DontFragment)
                        $pingResult = $ping.Send($target, $Timeout, [System.Text.Encoding]::ASCII.GetBytes(("a" * $BufferSize)), $pingOptions)
                        Return $pingResult
                    }
                    # Simulating a ping result
                    $pingResult = send-ping -Target $ip -BufferSize $BufferSize -Ttl $Ttl -DontFragment:$DontFragment -Timeout $Timeout 

                    $pingStatistics = [pscustomobject]@{
                        IPAddress     = $ip
                        ResponsTime   = [double]0.0
                        Result        = ""
                        ResultHistory = ""
                        DownTimeStart = $null
                        DownTime      = $null
                    }

                    if ($pingResult.Status -eq "Success") {
                        $pingStatistics.ResponsTime = $pingResult.RoundtripTime
                        $pingStatistics.Result = $pingResult.Status
                        $pingStatistics.ResultHistory = "!"
                    }
                    else {
                        $pingStatistics.ResponsTime = "-"
                        $pingStatistics.Result = "TimedOut"
                        $pingStatistics.ResultHistory = "."
                    }
        
                    # Return the result
                    return @($ip, $pingStatistics)
                }

                # Create a new PowerShell runspace and configure it
                $powershell = [powershell]::Create().AddScript($scriptBlock).AddArgument($ip).AddArgument($BufferSize).AddArgument($Ttl).AddArgument($DontFragment).AddArgument($Timeout).AddArgument($HistoryResetCount)
                $powershell.RunspacePool = $pool

                # Start the asynchronous execution of the PowerShell instance
                $runspaces.Add([PSCustomObject]@{
                        Pipe        = $powershell
                        AsyncResult = $powershell.BeginInvoke()
                    }) | Out-Null
            }

            # Collect and process the results as they complete
            foreach ($runspace in $runspaces) {
                $result = $runspace.Pipe.EndInvoke($runspace.AsyncResult)
                $runspace.Pipe.Dispose()

                $ipAddress = $result[0]
                $pingStatistics = $result[1]
               
                if ($pingHistory.Contains($ipAddress)) {
                    if ($pingHistory[$ipAddress].ResultHistory.Length -eq $HistoryResetCount) {
                        $pingHistory[$ipAddress].ResultHistory = ""
                    }
                    $pingHistory[$ipAddress].ResponsTime = $pingStatistics.ResponsTime
                    $pingHistory[$ipAddress].Result = $pingStatistics.Result
                    $pingHistory[$ipAddress].ResultHistory += $pingStatistics.ResultHistory
                }
                else {
                    $pingHistory.Add($ipAddress, $pingStatistics)
                }
               


            }

            # Close and dispose of the runspace pool
            $pool.Close()
            $pool.Dispose()
            
            # Check for DownTime
            foreach ($item in $pingHistory.Values) {
                $timeStamp = Get-Date
                if ($item.Result -eq "TimedOut") {
                    if ($item.DownTimeStart) {
                        $item.DownTime += ($timeStamp - $item.DownTimeStart).TotalSeconds
                        $item.DownTimeStart = $timeStamp
                    }
                    else {
                        $item.DownTimeStart = $timeStamp
                    }
                }
                else {
                    $item.DownTimeStart = $null
                }
            }

            if ($ShowHistory) {
                Clear-Host
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), Ping sequnce: $($iCount + 1)"
                foreach ($item in $pingHistory.Values) {
                    $paddingSize = 20 - $item.IPAddress.length
                    if ($paddingSize -lt 0) { $paddingSize = 0 }
                    Write-Host -NoNewline "Ip:"
                    Write-Host -ForegroundColor Green -NoNewline "$($item.IPAddress) "
                    Write-Host -NoNewline "time:".PadLeft($paddingSize, " ")
                    Write-Host -ForegroundColor Green -NoNewline "$($item.ResponsTime) "
                    Write-Host -NoNewline "DownFor:"
                    Write-Host -ForegroundColor Green -NoNewline "$([math]::Round($item.DownTime,0)) "
                    if ($item.ResultHistory.EndsWith("..")) {
                        Write-Host -ForegroundColor Red "$($item.ResultHistory)"
                    }
                    elseif ($item.ResultHistory -like "*.*") {
                        Write-Host -ForegroundColor Yellow "$($item.ResultHistory)"
                    }
                    else {
                        Write-Host "$($item.ResultHistory)"
                    }
                    
                }
            }
            else {
                Clear-Host
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), Ping sequnce: $($iCount + 1)"
                Write-Output -InputObject $pingHistory.Values | Select-Object IPAddress, ResponsTime, Result, DownTime | Format-Table -RepeatHeader -AutoSize
            }
                
            $iCount++
            Start-Sleep -Seconds 1
        }

        
        
        
    }
    finally {
       
    }
    
}

