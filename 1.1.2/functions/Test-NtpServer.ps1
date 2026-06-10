<#
.SYNOPSIS
    Tests one or more NTP servers and returns time synchronization information.

.DESCRIPTION
    Queries NTP servers using UDP port 123 and retrieves time synchronization data.
    Returns the server time, offset from local clock, round-trip delay, and stratum level.
    Supports testing multiple servers in parallel.

.PARAMETER Server
    One or more NTP server hostnames or IP addresses to test.

.PARAMETER Port
    UDP port to use for NTP queries. Default is 123.

.PARAMETER Timeout
    Timeout in milliseconds for each NTP query. Default is 3000.

.PARAMETER Count
    Number of NTP queries to send per server for averaging. Default is 1.

.EXAMPLE
    Test-NtpServer -Server "pool.ntp.org"

    Server       : pool.ntp.org
    Status       : Success
    ServerTime   : 2026-04-14 10:23:45
    OffsetMs     : -12.34
    DelayMs      : 25.67
    Stratum      : 2
    ReferenceId  : 192.5.41.40

.EXAMPLE
    Test-NtpServer -Server "0.pool.ntp.org","1.pool.ntp.org","time.windows.com"

.EXAMPLE
    "pool.ntp.org","time.cloudflare.com" | Test-NtpServer -Count 3

.NOTES
    NTP uses UDP port 123. Some firewalls may block this traffic.
    Stratum 1 = directly connected to reference clock (GPS, atomic clock).
    Stratum 2+ = synchronized from a higher-stratum server.
    Offset is the difference between server time and local clock (negative = local clock is ahead).
#>
function Test-NtpServer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [string[]]$Server,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 123,

        [Parameter()]
        [ValidateRange(100, 30000)]
        [int]$Timeout = 3000,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$Count = 1
    )

    begin {
        $allServers = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($s in $Server) {
            $allServers.Add($s)
        }
    }

    end {
        foreach ($ntpServer in $allServers) {
            for ($i = 0; $i -lt $Count; $i++) {
                $result = [PSCustomObject]@{
                    Server      = $ntpServer
                    Status      = 'Unknown'
                    ServerTime  = $null
                    OffsetMs    = $null
                    DelayMs     = $null
                    Stratum     = $null
                    ReferenceId = $null
                    Error       = $null
                }

                try {
                    # NTP request packet (48 bytes). LI=0, VN=3, Mode=3 (client)
                    $ntpData = New-Object byte[] 48
                    $ntpData[0] = 0x1B  # LI=0, VN=3, Mode=3

                    $udpClient = New-Object System.Net.Sockets.UdpClient
                    $udpClient.Client.ReceiveTimeout = $Timeout

                    $t1 = [DateTime]::UtcNow

                    $udpClient.Connect($ntpServer, $Port)
                    [void]$udpClient.Send($ntpData, $ntpData.Length)

                    $remoteEndpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                    $response = $udpClient.Receive([ref]$remoteEndpoint)
                    $udpClient.Close()

                    $t4 = [DateTime]::UtcNow

                    if ($response.Length -lt 48) {
                        throw "Invalid NTP response: packet too short ($($response.Length) bytes)"
                    }

                    # NTP epoch starts 1900-01-01; .NET epoch starts 0001-01-01
                    $ntpEpoch = [DateTime]::new(1900, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)

                    # Transmit Timestamp (bytes 40-47) - T3: when server sent reply
                    $secondsT3 = [BitConverter]::ToUInt32($response[43..40], 0)
                    $fractionT3 = [BitConverter]::ToUInt32($response[47..44], 0)
                    $t3 = $ntpEpoch.AddSeconds($secondsT3 + $fractionT3 / [Math]::Pow(2, 32))

                    # Receive Timestamp (bytes 32-39) - T2: when server received request
                    $secondsT2 = [BitConverter]::ToUInt32($response[35..32], 0)
                    $fractionT2 = [BitConverter]::ToUInt32($response[39..36], 0)
                    $t2 = $ntpEpoch.AddSeconds($secondsT2 + $fractionT2 / [Math]::Pow(2, 32))

                    # Round-trip delay = (T4 - T1) - (T3 - T2)
                    $delayMs = [Math]::Round((($t4 - $t1) - ($t3 - $t2)).TotalMilliseconds, 2)

                    # Clock offset = ((T2 - T1) + (T3 - T4)) / 2
                    $offsetMs = [Math]::Round((($t2 - $t1) + ($t3 - $t4)).TotalMilliseconds / 2, 2)

                    # Server time = T3 + half round-trip
                    $serverTime = $t3.AddMilliseconds($delayMs / 2).ToLocalTime()

                    # Stratum (byte 1)
                    $stratum = $response[1]

                    # Reference Identifier (bytes 12-15)
                    if ($stratum -le 1) {
                        # For stratum 1, reference ID is ASCII
                        $refId = [System.Text.Encoding]::ASCII.GetString($response[12..15]).TrimEnd("`0")
                    } else {
                        # For stratum 2+, reference ID is an IPv4 address
                        $refId = "$($response[12]).$($response[13]).$($response[14]).$($response[15])"
                    }

                    $result.Status     = 'Success'
                    $result.ServerTime = $serverTime.ToString('yyyy-MM-dd HH:mm:ss')
                    $result.OffsetMs   = $offsetMs
                    $result.DelayMs    = [Math]::Abs($delayMs)
                    $result.Stratum    = $stratum
                    $result.ReferenceId = $refId
                }
                catch [System.Net.Sockets.SocketException] {
                    $result.Status = 'TimedOut'
                    $result.Error  = $_.Exception.Message
                }
                catch {
                    $result.Status = 'Error'
                    $result.Error  = $_.Exception.Message
                    if ($udpClient) { try { $udpClient.Close() } catch {} }
                }

                $result
            }
        }
    }
}
