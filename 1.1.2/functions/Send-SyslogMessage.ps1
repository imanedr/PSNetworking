function Send-SyslogMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$Server,

        [ValidateSet('UDP', 'TCP')]
        [string]$Protocol = 'UDP',

        [int]$Port
    )

    # Default syslog port
    if (-not $Port) {
        $Port = 514
    }

     $bytes = [System.Text.Encoding]::UTF8.GetBytes($Message)

    if ($Protocol -eq 'UDP') {
        $udpClient = New-Object System.Net.Sockets.UdpClient
        try {
            $udpClient.Connect($Server, $Port)
            $udpClient.Send($bytes, $bytes.Length) | Out-Null
        } finally {
            $udpClient.Close()
        }
    } elseif ($Protocol -eq 'TCP') {
        # Append newline for TCP syslog
        $tcpMessage = "$Message`n"
        $tcpBytes = [System.Text.Encoding]::UTF8.GetBytes($tcpMessage)
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        try {
            $tcpClient.Connect($Server, $Port)
            $stream = $tcpClient.GetStream()
            $stream.Write($tcpBytes, 0, $tcpBytes.Length)
            $stream.Flush()
            $stream.Close()
        } finally {
            $tcpClient.Close()
        }
    }
}