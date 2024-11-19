<#
.SYNOPSIS
    Advanced parallel ping utility for multiple IP addresses with history tracking and statistics.

.DESCRIPTION
    Ping-IpList provides powerful network connectivity testing capabilities with features like:
    - Parallel ping execution for multiple targets
    - Continuous monitoring mode
    - Ping history visualization
    - DNS resolution
    - Customizable ping parameters
    - Support for IP ranges and CIDR notation
    - Downtime tracking

.PARAMETER FromClipBoard
    Reads IP addresses from clipboard

.PARAMETER ipList
    Array of IP addresses or hostnames to ping

.PARAMETER range
    IP address range in format "192.168.1.1-192.168.1.254"

.PARAMETER cidr
    CIDR notation subnet like "192.168.1.0/24"

.PARAMETER Count
    Number of ping attempts (default: 4, use -Continuous for endless)

.PARAMETER BufferSize
    Size of ping packet in bytes (default: 32)

.PARAMETER DontFragment
    Sets the Don't Fragment flag in ping packet

.PARAMETER Ttl
    Time to live value (default: 128)

.PARAMETER Timeout
    Ping timeout in milliseconds (default: 100)

.PARAMETER Continuous
    Enables continuous ping mode

.PARAMETER ResolveDNS
    Resolves IP addresses to hostnames

.PARAMETER ShowHistory
    Displays ping history using symbols (! for success, . for failure)

.PARAMETER HistoryResetCount
    Number of results to keep in history before reset (default: 100)

.PARAMETER DontSortIpList
    Prevents automatic IP address sorting

.PARAMETER MaxThreads
    Maximum number of concurrent ping threads (default: 100)

.PARAMETER OutToPipe
    Outputs results to pipeline instead of console

.EXAMPLE
    # Copy these IPs to your clipboard:
    # 192.168.1.10
    # 8.8.8.8
    # 1.1.1.1
    Ping-IpList -FromClipBoard -ShowHistory

    Output:
    2024-11-19 14:01:24, Ping sequnce: 1
    192.168.1.10 [t:1ms DownFor:0s]:!
    8.8.8.8     [t:27ms DownFor:0s]:!
    1.1.1.1     [t:18ms DownFor:0s]:!

    This example shows how to quickly ping multiple IPs by copying them from any source (text file, Excel, web page).
    Just ensure each IP is on a new line before copying.


.EXAMPLE
    Ping-IpList -ipList "8.8.8.8","1.1.1.1" -Count 10

    Output:
    IPAddress ResponsTime  Result   DownTime
    --------- -----------  ------   --------
    1.1.1.1            18 Success
    8.8.8.8            27 Success

.EXAMPLE
    Ping-IpList -range "192.168.1.1-192.168.1.10" -Continuous -ShowHistory

    Output:
    2024-11-19 13:57:24, Ping sequnce: 7
    192.168.1.1 [t:1ms DownFor:0s]:!!!!!!!
    192.168.1.2 [t:-ms DownFor:9s]:.......
    192.168.1.3 [t:-ms DownFor:9s]:.......
    [...]

.EXAMPLE
    Ping-IpList -cidr "10.0.0.0/29" -ResolveDNS

    Output:
    2024-11-19 13:58:09, Ping sequnce: 4
    IPAddress           ResponsTime Result   DownTime
    ---------          ----------- ------   --------
    10.0.0.0           -           TimedOut     4.49
    host1.example.com   1           Success
    10.0.0.2           1           Success
    host3.example.com   1           Success
    [...]

.NOTES
    Author: PSNetworking Toolkit
    Requires: PowerShell 5.1 or higher
    Tags: Network, Monitoring, Ping
#>
function Ping-IpList {
   
    [CmdletBinding()]
    param (
        [switch]$FromClipBoard,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('list')]
        [String[]]$ipList,
        [string]$range,
        [string]$cidr,
        [Alias('n')]
        [int]$Count = 4,
        [Alias('l')]
        [int]$BufferSize = 32,
        [Alias('f')]
        [switch]$DontFragment,
        [Alias('i')]
        [int]$Ttl = 128,
        [int]$Timeout = 100,
        [Alias('c','t')]
        [switch]$Continuous,
        [Alias('a')]
        [switch]$ResolveDNS,
        [switch]$ShowHistory,
        [int]$HistoryResetCount = 100,
        [switch]$DontSortIpList,
        [int]$MaxThreads = 100,
        [switch]$OutToPipe
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

    if ($ResolveDNS) {
        for ($i = 0; $i -lt $ipList.Count; $i++) {
            if ($ipList[$i] -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}") {
                $NameHost = (Resolve-DnsName $ipList[$i] -Type PTR -DnsOnly -ErrorAction SilentlyContinue).NameHost
                if ($NameHost) { 
                    if ($NameHost.Count -gt 1) {$ipList[$i] = $NameHost[0]} else { $ipList[$i] = $NameHost }
                }
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
            if (-not $OutToPipe) {
            if ($ShowHistory) {
                Clear-Host
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), Ping sequnce: $($iCount + 1)"
                foreach ($item in $pingHistory.Values) {
                    # $paddingSize = 20 - $item.IPAddress.length
                    # if ($paddingSize -lt 0) { $paddingSize = 0 }
                    Write-Host -ForegroundColor Green -NoNewline "$($item.IPAddress) ["
                    Write-Host -NoNewline "t:"#.PadLeft($paddingSize, " ")
                    Write-Host -ForegroundColor Green -NoNewline "$($item.ResponsTime)ms "
                    Write-Host -NoNewline "DownFor:"
                    Write-Host -ForegroundColor Green -NoNewline "$([math]::Round($item.DownTime,2))s]:"
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
        }else{
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), Ping sequnce: $($iCount + 1)"
            if ($iCount -eq ($Count - 1)) {
                Write-Output -InputObject $pingHistory.Values | Select-Object IPAddress, ResponsTime, Result, ResultHistory, DownTime
            }
        }
            $iCount++
            Start-Sleep -Seconds 1
        }

        
        
        
    }
    finally {
       
    }
    
}

