function Ping-Ip
{
    <#
    .SYNOPSIS
The Ping-Ip function pings a specified computer name or IP address to test the network connection and provides detailed information on the response status.

.DESCRIPTION
The Ping-Ip function allows you to test the connectivity of a network by pinging a specified computer name or IP address. The function returns detailed information about the response, including the number of sent and received packets, the time taken for each response, and the status of each response. 

.PARAMETER ComputerName
Mandatory parameter that takes the name or IP address of the computer you want to ping.

.PARAMETER Count
The number of pings to send. The default value is 4.

.PARAMETER BufferSize
The size of the buffer in bytes to use for the data portion of the ping packet. The default value is 32.

.PARAMETER DontFragment
A switch parameter that indicates whether the ping packet can be fragmented. 

.PARAMETER Ttl
The time-to-live value to use for the ping packet. The default value is 128.

.PARAMETER Timeout
The number of milliseconds to wait for a response to the ping request. The default value is 5000.

.PARAMETER Continuous
A switch parameter that indicates whether to send an infinite number of pings.

.PARAMETER Short
A switch parameter that make the output shorter.

.EXAMPLE
PS C:\> Ping-Ip -ComputerName "www.google.com"
Pings the www.google.com server and returns the results of the ping.

.EXAMPLE
PS C:\> Ping-Ip -ComputerName "www.google.com" -Continuous
Pings the www.google.com server continuously and returns the results of each ping.

.OUTPUTS
The Ping-Ip function returns information about the network response to the ping request, including the date and time, the response status, and the response time.

.NOTES
Use the Ping-Ip function to test the connectivity of a network and diagnose any potential issues.```

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$ComputerName,
        [int]$Count = 4,
        [int]$BufferSize = 32,
        [switch]$DontFragment,
        [int]$Ttl = 128,
        [int]$Timeout = 5000,
        [switch]$Continuous,
        [switch]$Short
    )
    $pingStatistics = @{
        Sent     = 0
        Received = 0
        Lost     = 0
        Minimum  = [double]::MaxValue
        Maximum  = [double]::MinValue
        Average  = 0.0
    }

    try
    {
        if ($Continuous) { $Count = -1 }
        $iCount = 0
        "Pinging $ComputerName with $BufferSize bytes of data:"
        while ($iCount -ne $Count)
        {
            Write-Verbose "Testing network connection to $ComputerName..."
            $ping = New-Object System.Net.NetworkInformation.Ping
            $pingOptions = New-Object System.Net.NetworkInformation.PingOptions($Ttl, $DontFragment)
            $pingResult = $ping.Send($ComputerName, $Timeout, [System.Text.Encoding]::ASCII.GetBytes(("a" * $BufferSize)), $pingOptions)

            if ($pingResult.Status -eq "Success")
            {
                $pingStatistics.Sent++
                $pingStatistics.Received++
                $pingStatistics.Minimum = [Math]::Min($pingStatistics.Minimum, $pingResult.RoundtripTime)
                $pingStatistics.Maximum = [Math]::Max($pingStatistics.Maximum, $pingResult.RoundtripTime)
                $pingStatistics.Average = ($pingStatistics.Average * ($pingStatistics.Received - 1) + $pingResult.RoundtripTime) / $pingStatistics.Received
                if (-not $short)
                {
                    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Reply from $($pingResult.Address): seq=$($iCount + 1) bytes=$BufferSize time=$($pingResult.RoundtripTime)ms TTL=$($pingResult.Options.Ttl)"
                }
                else
                {
                    Write-Output "Reply $($pingResult.Address): S=$($iCount + 1) B=$BufferSize T=$($pingResult.RoundtripTime)ms TTL=$($pingResult.Options.Ttl)"
                }
            }
            else
            {
                $pingStatistics.Sent++
                $pingStatistics.Lost++
                #Write-Host -ForegroundColor Red "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Pinging $ComputerName [$($pingResult.Address)] with $BufferSize bytes of data: Request timed out."
                
                switch ($pingResult.Status)
                {
                    'DestinationNetworkUnreachable'
                    {
                        Write-Host -ForegroundColor Red "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Reply from $($pingResult.Address): seq=$($iCount + 1) Destination network unreachable."
                    }
                    'DestinationHostUnreachable'
                    {
                        Write-Host -ForegroundColor Red "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Reply from $($pingResult.Address): seq=$($iCount + 1) Destination host unreachable."
                    }
                    'DestinationProtocolUnreachable'
                    {
                        Write-Host -ForegroundColor Red "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Reply from $($pingResult.Address): seq=$($iCount + 1) Destination protocol unreachable."
                    }
                    'DestinationPortUnreachable'
                    {
                        Write-Host -ForegroundColor Red "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Reply from $($pingResult.Address): seq=$($iCount + 1) Destination port unreachable."
                    }
                    'NoResponse'
                    {
                        Write-Host -ForegroundColor Red "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Reply from $($pingResult.Address): seq=$($iCount + 1) No response was received."
                    }
                    'TimedOut'
                    {
                        Write-Host -ForegroundColor Red "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Reply from $($pingResult.Address): seq=$($iCount + 1) Request timed out."
                    }
                    'TtlExpired'
                    {
                        Write-Host -ForegroundColor Red "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Reply from $($pingResult.Address): seq=$($iCount + 1) Time to live exceeded."
                    }
                    'Error'
                    {
                        Write-Host -ForegroundColor Red "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Reply from $($pingResult.Address): seq=$($iCount + 1) An error occurred during the ping operation."
                    }
                }
            }
            Start-Sleep -Seconds 1
            $iCount++
        }
    }
    finally
    {
        if ($ping)
        {
            Write-Host -ForegroundColor Cyan "Ping statistics for $($computerName):
        Packets: Sent = $($pingStatistics.Sent), Received = $($pingStatistics.Received), Lost = $($pingStatistics.Lost) ($([Math]::Round(($pingStatistics.Lost / $pingStatistics.Sent) * 100, 2))% loss),
Approximate round trip times in milli-seconds:
        Minimum = $($pingStatistics.Minimum)ms, Maximum = $($pingStatistics.Maximum)ms, Average = $($pingStatistics.Average)ms"   
        } 
    }
    
}
