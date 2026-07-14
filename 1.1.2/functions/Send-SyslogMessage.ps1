function Send-SyslogMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$Server,

        [ValidateSet('UDP', 'TCP')]
        [string]$Protocol = 'UDP',

        [int]$Port,

        [string]$Hostname,

        [ValidateSet('RFC5424', 'RFC3164')]
        [string]$SyslogFormat = 'RFC5424',

        [ValidateRange(0, 23)]
        [int]$Facility = 1,

        [ValidateRange(0, 7)]
        [int]$Severity = 6
    )

    if (-not $Port) {
        $Port = 514
    }

    $payload = if ($Hostname) {
        $pri = ($Facility * 8) + $Severity
        if ($SyslogFormat -eq 'RFC5424') {
            $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
            "<$pri>1 $timestamp $Hostname - - - - $Message"
        } else {
            $en = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
            $now = Get-Date
            $timestamp = '{0} {1,2} {2}' -f $now.ToString('MMM', $en), $now.Day, $now.ToString('HH:mm:ss')
            "<$pri>$timestamp $Hostname $Message"
        }
    } else {
        $Message
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)

    if ($Protocol -eq 'UDP') {
        $udpClient = New-Object System.Net.Sockets.UdpClient
        try {
            $udpClient.Connect($Server, $Port)
            $udpClient.Send($bytes, $bytes.Length) | Out-Null
        } finally {
            $udpClient.Close()
        }
    } elseif ($Protocol -eq 'TCP') {
        $tcpBytes = [System.Text.Encoding]::UTF8.GetBytes("$payload`n")
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