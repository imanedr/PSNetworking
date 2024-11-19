
<#
.SYNOPSIS
Monitors real-time bandwidth usage for a specified network interface.

.DESCRIPTION
The Get-BandwidthUsage function provides continuous monitoring of network bandwidth usage, displaying upload and download speeds along with cumulative data transfer. It supports both instantaneous view and historical logging of network traffic.

.PARAMETER InterfaceName
The name of the network interface to monitor. This parameter is mandatory.

.PARAMETER ShowHistory
Switch parameter that enables logging of historical bandwidth data instead of showing only current values.

.EXAMPLE
Get-BandwidthUsage -InterfaceName "Ethernet"
# Shows real-time bandwidth usage for the Ethernet interface with current values only

.EXAMPLE
Get-BandwidthUsage -InterfaceName "Wi-Fi" -ShowHistory
# Logs historical bandwidth usage data for the Wi-Fi interface

.OUTPUTS
Returns a custom object containing:
- Send: Current upload speed (Kbps or Mbps)
- Receive: Current download speed (Kbps or Mbps)
- TotalSent: Cumulative data sent (Mb or Gb)
- TotalReceived: Cumulative data received (Mb or Gb)
- Time: Timestamp (only when -ShowHistory is used)

.NOTES
- Requires administrator privileges
- Press Ctrl+C to stop monitoring
- Updates every second
- Automatically converts units between Kbps/Mbps and Mb/Gb based on magnitude

.LINK
https://github.com/imanedr/psnetworking
#>

function Get-BandwidthUsage
{
    [CmdletBinding()]
    param (
        # This parameter specifies the name of the network interface to monitor
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$InterfaceName,
        # This parameter controls whether to show the bandwidth data for each iteration or not
        [Switch]$ShowHistory
    )
    # This variable keeps track of the number of iterations
    $iteration = 0
    # This loop runs indefinitely until the user stops the function
    While ($true)
    {
        if ($iteration -eq 0)
        {
            # This command gets the network adapter statistics for the given interface name
            $netStats1 = Get-NetAdapterStatistics -Name $InterfaceName
            # This variable stores the current date and time
            $timeStamp1 = get-date
        }
        else
        {
            # This assigns the previous values of netStats2 and timeStamp2 to netStats1 and timeStamp1
            $netStats1 = $netStats2
            $timeStamp1 = $timeStamp2
        }
        
        # These variables store the number of bytes sent and received by the network adapter at time 1
        $sendBytes1 = $netStats1.SentBytes
        $receivedBytes1 = $netStats1.ReceivedBytes
        # This pauses the execution for one second
        Start-Sleep -Seconds 1
        
        # This gets the network adapter statistics and current date and time again at time 2
        $netStats2 = Get-NetAdapterStatistics -Name $InterfaceName
        $timeStamp2 = get-date
        # This calculates the time difference between time 1 and time 2 in seconds
        $timeDiff = ($timeStamp2 - $timeStamp1).Ticks / 10000000
        # These variables store the number of bytes sent and received by the network adapter at time 2
        $sendBytes2 = $netStats2.SentBytes
        $receivedBytes2 = $netStats2.ReceivedBytes

        # These variables calculate the number of bytes sent and received per second by subtracting the values at time 1 from the values at time 2
        $sendBytePerSecond = $sendBytes2 - $sendBytes1
        $receiveBytePerSecond = $receivedBytes2 - $receivedBytes1

        # These variables keep track of the total number of bytes sent and received since the function started
        $totalByteSent += $sendBytePerSecond
        $totalByteReceived += $receiveBytePerSecond

        # These variables convert the bytes per second to bits per second by multiplying by 8
        $sendBitsPerSecond = $sendBytePerSecond * 8
        $receiveBitsPerSecond = $receiveBytePerSecond * 8
        
        # These variables store the strings to display the bandwidth usage in Kbps or Mbps depending on the magnitude of the bits per second values
        if ($sendBitsPerSecond -lt 1000000)
        {
            # This rounds the bits per second value to the nearest integer and divides by 1000 to get Kbps 
            $send = "$([math]::Round(($sendBitsPerSecond / $timeDiff) / 1000)) Kbps"
        }
        else
        {
            # This rounds the bits per second value to the nearest integer and divides by 1000000 to get Mbps 
            $send = "$([math]::Round(($sendBitsPerSecond / $timeDiff) / 1000000)) Mbps"
        }

        if ($receiveBitsPerSecond -lt 1000000)
        {
            # This rounds the bits per second value to the nearest integer and divides by 1000 to get Kbps 
            $receive = "$([math]::Round(($receiveBitsPerSecond / $timeDiff) /1000)) Kbps"
        }
        else
        {
            # This rounds the bits per second value to the nearest integer and divides by 1000000 to get Mbps 
            $receive = "$([math]::Round(($receiveBitsPerSecond / $timeDiff) /1000000)) Mbps"
        }

        
        # These variables store the strings to display the total bandwidth usage in Mb or Gb depending on the magnitude of the total byte values
        
        if ($totalByteSent -lt 1000000000)
        {
            # This rounds the total byte value to two decimal places and divides by 1000000 to get Mb 
            $totalSent = "$([math]::Round($totalByteSent / 1000000,2)) Mb"
        }
        else
        {
            # This rounds the total byte value to two decimal places and divides by 1000000000 to get Gb 
            $totalSent = "$([math]::Round($totalByteSent / 1000000000,2)) Gb"
        }

        if ($totalByteReceived -lt 1000000000)
        {
            # This rounds the total byte value to two decimal places and divides by 1000000 to get Mb 
            $totalReceived = "$([math]::Round($totalByteReceived / 1000000,2)) Mb"
        }
        else
        {
            # This rounds the total byte value to two decimal places and divides by 1000000000 to get Gb 
            $totalReceived = "$([math]::Round($totalByteReceived / 1000000000,2)) Gb"
        }

        # This clears the screen
        if ($ShowHistory)
        {
            [pscustomobject]@{
                Time          = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                Send          = $send
                Receive       = $receive
                TotalSent     = $totalSent
                TotalReceived = $totalReceived
            } 
        }
        else
        {
            Clear-Host
            # This creates a custom object with the bandwidth usage properties and formats it as a table with repeated header
            [pscustomobject]@{
                Send          = $send
                Receive       = $receive
                TotalSent     = $totalSent
                TotalReceived = $totalReceived
            } | Format-Table -RepeatHeader
        }
        

        # This increments the iteration counter
        $iteration++
    }
    
    
}
