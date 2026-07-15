#Requires -Version 5.1
function Invoke-DhcpTest {
    <#
    .SYNOPSIS
        Sends DHCP DISCOVER (and optionally REQUEST) packets to test DHCP servers, without dhcptest.exe.

    .DESCRIPTION
        Implements RFC 2131/2132 DHCP DISCOVER/OFFER and optional REQUEST/ACK exchanges over
        System.Net.Sockets.UdpClient. Supports spoofing the client MAC address (chaddr), injecting
        arbitrary DHCP options, requesting specific options back from the server (option 55), and
        targeting either a broadcast segment or a specific server/relay IP.

        By default only DISCOVER/OFFER is performed — this is read-only and never causes a server to
        commit a lease. The REQUEST/ACK phase (which can cause the server to reserve/commit the
        offered address) is opt-in via -SendRequest and is gated by ShouldProcess. This function never
        binds the resulting address to a local network adapter or changes OS routing/interface
        configuration — it only sends packets and returns a result object.

    .PARAMETER ServerAddress
        DHCP server or relay IP to send to. Default '255.255.255.255' (broadcast).

    .PARAMETER ServerPort
        UDP port on the DHCP server. Default: 67.

    .PARAMETER ClientPort
        Local UDP port to bind. Must be 68 to receive the server's reply (servers always reply to
        port 68). Default: 68.

    .PARAMETER ClientMac
        Spoofed client MAC address (chaddr), any of xx:xx:xx:xx:xx:xx, xx-xx-xx-xx-xx-xx, or Cisco
        xxxx.xxxx.xxxx format. If omitted, a random locally-administered MAC is generated.

    .PARAMETER Bind
        Local IP address to bind the UDP socket to, for multi-NIC/VLAN hosts. Default: any address.

    .PARAMETER RelayAgentIPAddress
        Sets the BOOTP 'giaddr' field, simulating a relay agent for the given subnet so the server can
        select a scope other than the one matching this host's own network position. Per RFC 2131 §4.1,
        when giaddr is non-zero the server sends its reply to giaddr's address on port 67 (the DHCP
        server port), not to the client's port 68. To actually receive that reply you must also pass
        -Bind and -ClientPort 67 with the same address as -RelayAgentIPAddress, and that address must
        be one this host can genuinely receive traffic on (e.g. a real secondary IP/alias on the
        target subnet). Otherwise the server does reply, but never to us, and the exchange times out.
        Default: 0.0.0.0 (no relay simulation).

    .PARAMETER Hostname
        Convenience for DHCP option 12 (Host Name).

    .PARAMETER VendorClassIdentifier
        Convenience for DHCP option 60 (Vendor Class Identifier).

    .PARAMETER ClientIdentifier
        Convenience for DHCP option 61 (Client Identifier), sent as an ASCII string value.

    .PARAMETER CircuitId
        Convenience for DHCP option 82 (Relay Agent Information) sub-option 1, Agent Circuit ID.
        Many switches with DHCP snooping/relay enabled insert this (and RemoteId) into every real
        client's DISCOVER, and some DHCP servers use it to select the subnet/pool within a shared
        network — a spoofed packet without it may land in a different, possibly exhausted, pool even
        with a correct -RelayAgentIPAddress. Encoded per -CircuitIdType (default ASCII String); use
        'HexString' if your network expects the vendor-specific binary format a real switch sends
        (check with your network team, e.g. by comparing to a real relayed packet capture).

    .PARAMETER CircuitIdType
        Encoding for -CircuitId: 'String' (ASCII, default) or 'HexString' (raw bytes from hex digits).

    .PARAMETER RemoteId
        Convenience for DHCP option 82 (Relay Agent Information) sub-option 2, Agent Remote ID —
        typically the relaying switch's own identifier (e.g. its MAC address). See -CircuitId.

    .PARAMETER RemoteIdType
        Encoding for -RemoteId: 'String' (ASCII, default) or 'HexString' (raw bytes from hex digits).

    .PARAMETER RequestOptions
        DHCP option codes (0-255) to request via option 55 (Parameter Request List).
        Default: 1,3,6,15,51,54,58,59 (subnet mask, router, DNS, domain name, lease time, server id,
        renewal/rebinding time).

    .PARAMETER Option
        Additional raw DHCP options to inject, as an array of hashtables with keys Code, Type, Value.
        Type must be one of Byte, UInt16, UInt32, String, IPAddress, HexString, ByteArray.
        Example: -Option @{Code=43;Type='HexString';Value='0102FF'}, @{Code=125;Type='IPAddress';Value='10.0.0.1'}

    .PARAMETER TransactionId
        Transaction ID (xid) to use. Default: a randomly generated value.

    .PARAMETER SendRequest
        After receiving an OFFER, send a REQUEST for the offered address and wait for ACK/NAK.
        This is the only phase that can cause a server to actually commit/reserve a lease, so it is
        gated by ShouldProcess (-WhatIf/-Confirm).

    .PARAMETER RequestedIPAddress
        Requested address (option 50). If given, it is included as a hint in the DISCOVER packet and
        used as the requested address in the REQUEST packet (defaulting there to the offered address
        if this override isn't also intended for REQUEST). Note most DHCP servers do not select a
        scope based on this hint — see -RelayAgentIPAddress for actual scope selection.

    .PARAMETER TimeoutSeconds
        Per-attempt wait for a reply, in seconds. Default: 5.

    .PARAMETER Retries
        Number of send attempts before giving up on a phase. Default: 3.

    .PARAMETER LogActivity
        Also write DISCOVER/OFFER/REQUEST/ACK events via Write-Log.

    .EXAMPLE
        Invoke-DhcpTest -Verbose

        Status           : OfferReceived
        OfferedAddress   : 192.168.1.87
        ServerIdentifier : 192.168.1.1
        LeaseTimeSeconds : 86400

    .EXAMPLE
        Invoke-DhcpTest -ClientMac '02:11:22:33:44:55' -Hostname 'dhcptest-probe' -RequestOptions 1,3,6,15,51

    .EXAMPLE
        Invoke-DhcpTest -SendRequest -Confirm:$false -Verbose

        Completes the full DISCOVER/OFFER/REQUEST/ACK handshake — will consume a real lease from the
        server's pool if it ACKs.

    .EXAMPLE
        Invoke-DhcpTest -ServerAddress 10.0.0.5 -Bind 10.0.1.20

        Unicasts the DISCOVER to a specific DHCP server/relay from a specific local interface.

    .EXAMPLE
        Invoke-DhcpTest -ServerAddress 172.31.3.174 -RelayAgentIPAddress 10.55.2.1 -Bind 10.55.2.1 -ClientPort 67

        Simulates a relay agent for the 10.55.2.0/24 scope so the server offers from that subnet
        instead of the one matching this host's own address. Requires 10.55.2.1 to be a real,
        reachable address on this host (e.g. a secondary IP/alias) and -ClientPort 67, since replies
        to a non-zero giaddr go to port 67, not 68. See -RelayAgentIPAddress notes.

    .EXAMPLE
        Invoke-DhcpTest -ServerAddress 172.31.3.179 -RelayAgentIPAddress 10.55.2.1 -Bind 10.55.2.1 -ClientPort 67 -CircuitIdType HexString -CircuitId '0004' -RemoteIdType HexString -RemoteId '0006AABBCCDDEEFF'

        Simulates a relay agent that also inserts Option 82 sub-options, for DHCP servers that use
        circuit-id/remote-id (not just giaddr) to select the pool within a shared network.

    .NOTES
        The BOOTP broadcast flag (0x8000) is always set in outgoing packets. With ciaddr=0 and
        giaddr=0 and no address bound to a real interface, an RFC-compliant server always replies via
        broadcast — there is no scenario in this tool where a unicast reply back to us would work,
        since we don't own the offered address at the network layer.

        Binding local UDP port 68 usually conflicts with the Windows DHCP Client service, which holds
        that port on any DHCP-enabled adapter. This function sets SO_REUSEADDR so it can coexist with
        it; if binding still fails, run PowerShell elevated and/or temporarily stop the service:
        Stop-Service Dhcp -Force (Start-Service Dhcp afterward).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()][string]$ServerAddress = '255.255.255.255',
        [Parameter()][ValidateRange(1, 65535)][int]$ServerPort = 67,
        [Parameter()][ValidateRange(1, 65535)][int]$ClientPort = 68,
        [Parameter()][Alias('MAC')][string]$ClientMac,
        [Parameter()][string]$Bind,
        [Parameter()][Alias('GiAddr')][string]$RelayAgentIPAddress,
        [Parameter()][string]$Hostname,
        [Parameter()][string]$VendorClassIdentifier,
        [Parameter()][string]$ClientIdentifier,
        [Parameter()][string]$CircuitId,
        [Parameter()][ValidateSet('String', 'HexString')][string]$CircuitIdType = 'String',
        [Parameter()][string]$RemoteId,
        [Parameter()][ValidateSet('String', 'HexString')][string]$RemoteIdType = 'String',
        [Parameter()][Alias('ParameterRequestList')][int[]]$RequestOptions = @(1, 3, 6, 15, 51, 54, 58, 59),
        [Parameter()][object[]]$Option = @(),
        [Parameter()][uint32]$TransactionId,
        [Parameter()][switch]$SendRequest,
        [Parameter()][string]$RequestedIPAddress,
        [Parameter()][ValidateRange(1, 60)][int]$TimeoutSeconds = 5,
        [Parameter()][ValidateRange(1, 10)][int]$Retries = 3,
        [Parameter()][switch]$LogActivity
    )

    # ── DHCP message types (RFC 2132 §9.6) ─────────────────────────────────────
    $MSG_DISCOVER = [byte]1
    $MSG_OFFER    = [byte]2
    $MSG_REQUEST  = [byte]3
    $MSG_ACK      = [byte]5
    $MSG_NAK      = [byte]6
    $MsgTypeNames = @{ 1 = 'Discover'; 2 = 'Offer'; 3 = 'Request'; 4 = 'Decline'; 5 = 'Ack'; 6 = 'Nak'; 7 = 'Release'; 8 = 'Inform' }

    $MagicCookie = [byte[]]@(99, 130, 83, 99)

    # ── Big-endian helpers ───────────────────────────────────────────────────

    function WriteU16BE([uint16]$v) {
        [byte[]]@([byte]($v -shr 8), [byte]($v -band 0xFF))
    }

    function WriteU32BE([uint32]$v) {
        [byte[]]@([byte](($v -shr 24) -band 0xFF), [byte](($v -shr 16) -band 0xFF),
                   [byte](($v -shr 8) -band 0xFF), [byte]($v -band 0xFF))
    }

    function ReadU16BE([byte[]]$b, [int]$i) {
        (([int]$b[$i]) -shl 8) -bor [int]$b[$i + 1]
    }

    function ReadU32BE([byte[]]$b, [int]$i) {
        ([uint32]$b[$i] -shl 24) -bor ([uint32]$b[$i + 1] -shl 16) -bor ([uint32]$b[$i + 2] -shl 8) -bor [uint32]$b[$i + 3]
    }

    # ── MAC helpers ───────────────────────────────────────────────────────────

    function ConvertTo-MacBytes([string]$mac) {
        $cisco = $mac -imatch '^([0-9a-f]{4}\.){2}[0-9a-f]{4}$'
        $colonDash = $mac -imatch '^([0-9a-f]{2}(:|-)){5}[0-9a-f]{2}$'
        if (-not $cisco -and -not $colonDash) {
            throw "Invalid MAC address format: '$mac'. Expected xx:xx:xx:xx:xx:xx, xx-xx-xx-xx-xx-xx, or xxxx.xxxx.xxxx."
        }
        $hex = ($mac -replace '[:\-.]', '')
        $bytes = [byte[]]::new(6)
        for ($i = 0; $i -lt 6; $i++) { $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
        return $bytes
    }

    function Format-MacBytes([byte[]]$b) {
        (($b | ForEach-Object { $_.ToString('x2') }) -join ':')
    }

    function New-RandomMacBytes() {
        $b = [byte[]]::new(6)
        (New-Object System.Random).NextBytes($b)
        $b[0] = [byte](($b[0] -band 0xFE) -bor 0x02)   # locally-administered, unicast
        return $b
    }

    # ── DHCP option encode/decode ────────────────────────────────────────────

    function ConvertTo-DhcpOptionBytes([int]$Code, [string]$Type, $Value) {
        switch ($Type) {
            'Byte' { return [byte[]]@([byte]$Value) }
            'UInt16' { return WriteU16BE ([uint16]$Value) }
            'UInt32' { return WriteU32BE ([uint32]$Value) }
            'String' { return [System.Text.Encoding]::ASCII.GetBytes([string]$Value) }
            'IPAddress' {
                $ip = [System.Net.IPAddress]::Parse([string]$Value)
                return $ip.GetAddressBytes()
            }
            'HexString' {
                $hex = ([string]$Value) -replace '[^0-9a-fA-F]', ''
                if ($hex.Length % 2 -ne 0) { throw "HexString value for option $Code has an odd number of hex digits." }
                $out = [byte[]]::new($hex.Length / 2)
                for ($i = 0; $i -lt $out.Length; $i++) { $out[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
                return $out
            }
            'ByteArray' { return [byte[]]$Value }
            default { throw "Unknown option Type '$Type' for option $Code. Valid: Byte, UInt16, UInt32, String, IPAddress, HexString, ByteArray." }
        }
    }

    function Add-DhcpOption([System.IO.MemoryStream]$ms, [int]$Code, [byte[]]$ValueBytes) {
        if ($ValueBytes.Length -gt 255) { throw "Option $Code value is $($ValueBytes.Length) bytes, exceeds the 255-byte TLV length limit." }
        $ms.WriteByte([byte]$Code)
        $ms.WriteByte([byte]$ValueBytes.Length)
        if ($ValueBytes.Length -gt 0) { $ms.Write($ValueBytes, 0, $ValueBytes.Length) }
    }

    function Read-DhcpOptions([byte[]]$pkt) {
        $opts = @{}
        $i = 240
        while ($i -lt $pkt.Length) {
            $code = $pkt[$i]
            if ($code -eq 255) { break }
            if ($code -eq 0) { $i++; continue }
            if ($i + 1 -ge $pkt.Length) { break }
            $len = $pkt[$i + 1]
            $start = $i + 2
            if ($start + $len -gt $pkt.Length) { break }
            $value = [byte[]]::new($len)
            if ($len -gt 0) { [Array]::Copy($pkt, $start, $value, 0, $len) }
            $opts[[int]$code] = $value
            $i = $start + $len
        }
        return $opts
    }

    function Format-IPBytes([byte[]]$b, [int]$offset) {
        "{0}.{1}.{2}.{3}" -f $b[$offset], $b[$offset + 1], $b[$offset + 2], $b[$offset + 3]
    }

    function Format-HexBytes([byte[]]$v) {
        ($v | ForEach-Object { $_.ToString('x2') }) -join ''
    }

    function ConvertFrom-DhcpOptions([hashtable]$rawOptions) {
        # Deliberately a plain hashtable, not [ordered]: OrderedDictionary has both an
        # object-key indexer and a positional int-index indexer, and since our keys are
        # integers, $decoded[$code] resolves to the positional one and throws
        # ArgumentOutOfRangeException ("index") the moment a code doesn't match an
        # existing position.
        $decoded = @{}
        foreach ($code in $rawOptions.Keys) {
            $v = $rawOptions[$code]
            $decoded[$code] = switch ($code) {
                1 { if ($v.Length -ge 4) { Format-IPBytes $v 0 } else { Format-HexBytes $v } }
                3 {
                    if ($v.Length -ge 4) {
                        $routers = New-Object System.Collections.Generic.List[string]
                        for ($o = 0; $o + 3 -lt $v.Length; $o += 4) { $routers.Add((Format-IPBytes $v $o)) }
                        , $routers.ToArray()
                    } else { Format-HexBytes $v }
                }
                6 {
                    $servers = New-Object System.Collections.Generic.List[string]
                    for ($o = 0; $o + 3 -lt $v.Length; $o += 4) { $servers.Add((Format-IPBytes $v $o)) }
                    , $servers.ToArray()
                }
                15 { [System.Text.Encoding]::ASCII.GetString($v) }
                51 { if ($v.Length -ge 4) { ReadU32BE $v 0 } else { $null } }
                53 { if ($v.Length -ge 1) { $MsgTypeNames[[int]$v[0]] } else { $null } }
                54 { if ($v.Length -ge 4) { Format-IPBytes $v 0 } else { Format-HexBytes $v } }
                56 { [System.Text.Encoding]::ASCII.GetString($v) }
                58 { if ($v.Length -ge 4) { ReadU32BE $v 0 } else { $null } }
                59 { if ($v.Length -ge 4) { ReadU32BE $v 0 } else { $null } }
                default { Format-HexBytes $v }
            }
        }
        return $decoded
    }

    function Get-DhcpMessageTypeName([hashtable]$rawOptions) {
        if ($rawOptions.ContainsKey(53) -and $rawOptions[53].Length -ge 1) {
            return $MsgTypeNames[[int]$rawOptions[53][0]]
        }
        return $null
    }

    # Returns @{Data=[byte[]]; EP=[IPEndPoint]} or $null on timeout
    function Recv([System.Net.Sockets.UdpClient]$u, [int]$ms) {
        $u.Client.ReceiveTimeout = $ms
        $ep = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
        try {
            $data = $u.Receive([ref]$ep)
            return @{ Data = $data; EP = $ep }
        } catch [System.Net.Sockets.SocketException] {
            if ($_.Exception.SocketErrorCode -eq [System.Net.Sockets.SocketError]::TimedOut) {
                return $null
            }
            throw
        }
    }

    function New-DhcpPacket {
        param(
            [byte]$MessageType,
            [uint32]$Xid,
            [byte[]]$ChaddrBytes,
            [System.Collections.Generic.List[hashtable]]$Options,
            [string]$RequestedIP,
            [string]$ServerId,
            [byte[]]$GiaddrBytes
        )

        $hdr = [byte[]]::new(236)
        $hdr[0] = 1                      # op = BOOTREQUEST
        $hdr[1] = 1                      # htype = Ethernet
        $hdr[2] = 6                      # hlen
        $hdr[3] = 0                      # hops
        [Buffer]::BlockCopy([byte[]](WriteU32BE $Xid), 0, $hdr, 4, 4)
        [Buffer]::BlockCopy([byte[]](WriteU16BE 0), 0, $hdr, 8, 2)        # secs
        [Buffer]::BlockCopy([byte[]](WriteU16BE 0x8000), 0, $hdr, 10, 2)  # flags: broadcast bit always set
        # ciaddr/yiaddr/siaddr left zero
        if ($GiaddrBytes) { [Buffer]::BlockCopy($GiaddrBytes, 0, $hdr, 24, 4) }
        [Buffer]::BlockCopy($ChaddrBytes, 0, $hdr, 28, 6)         # chaddr, remaining 10 bytes zero-padded

        $ms = [System.IO.MemoryStream]::new()
        $ms.Write($hdr, 0, $hdr.Length)
        $ms.Write($MagicCookie, 0, $MagicCookie.Length)

        Add-DhcpOption $ms 53 ([byte[]]@($MessageType))

        if ($MessageType -eq $MSG_REQUEST) {
            Add-DhcpOption $ms 50 ([System.Net.IPAddress]::Parse($RequestedIP).GetAddressBytes())
            Add-DhcpOption $ms 54 ([System.Net.IPAddress]::Parse($ServerId).GetAddressBytes())
        } elseif ($RequestedIP) {
            Add-DhcpOption $ms 50 ([System.Net.IPAddress]::Parse($RequestedIP).GetAddressBytes())
        }

        if ($RequestOptions -and $RequestOptions.Count -gt 0) {
            $prl = [byte[]]::new($RequestOptions.Count)
            for ($i = 0; $i -lt $RequestOptions.Count; $i++) {
                if ($RequestOptions[$i] -lt 0 -or $RequestOptions[$i] -gt 255) { throw "RequestOptions value $($RequestOptions[$i]) is out of range 0-255." }
                $prl[$i] = [byte]$RequestOptions[$i]
            }
            Add-DhcpOption $ms 55 $prl
        }

        foreach ($opt in $Options) {
            $valueBytes = ConvertTo-DhcpOptionBytes -Code $opt.Code -Type $opt.Type -Value $opt.Value
            Add-DhcpOption $ms $opt.Code $valueBytes
        }

        $ms.WriteByte(255)  # End option

        $bytes = $ms.ToArray()
        if ($bytes.Length -lt 300) {
            $padded = [byte[]]::new(300)
            [Buffer]::BlockCopy($bytes, 0, $padded, 0, $bytes.Length)
            return $padded
        }
        return $bytes
    }

    # ── Argument validation / option assembly ────────────────────────────────

    $xid = if ($PSBoundParameters.ContainsKey('TransactionId')) { $TransactionId } else { [uint32](Get-Random -Minimum 1 -Maximum ([int64]4294967295)) }

    $clientMacBytes = if ($ClientMac) { ConvertTo-MacBytes $ClientMac } else { New-RandomMacBytes }
    $clientMacString = Format-MacBytes $clientMacBytes

    $allOptions = [System.Collections.Generic.List[hashtable]]::new()
    $usedCodes = [System.Collections.Generic.HashSet[int]]::new()

    function Add-NamedOption([int]$Code, [string]$Type, $Value, [string]$Name) {
        if ($null -eq $Value -or $Value -eq '') { return }
        if (-not $usedCodes.Add($Code)) { throw "Option $Code specified both via -$Name and -Option; use only one." }
        $allOptions.Add(@{ Code = $Code; Type = $Type; Value = $Value })
    }

    foreach ($opt in $Option) {
        if (-not $opt.ContainsKey('Code')) { throw "Each -Option entry must include a 'Code' key." }
        if (-not $opt.ContainsKey('Type')) { throw "Each -Option entry must include a 'Type' key." }
        if (-not $opt.ContainsKey('Value')) { throw "Each -Option entry must include a 'Value' key." }
        $code = [int]$opt.Code
        if ($code -le 0 -or $code -ge 255) { throw "Option code $code is invalid; valid custom option codes are 1-254." }
        if (-not $usedCodes.Add($code)) { throw "Option $code specified more than once." }
        $allOptions.Add(@{ Code = $code; Type = $opt.Type; Value = $opt.Value })
    }

    Add-NamedOption 12 'String' $Hostname 'Hostname'
    Add-NamedOption 60 'String' $VendorClassIdentifier 'VendorClassIdentifier'
    Add-NamedOption 61 'String' $ClientIdentifier 'ClientIdentifier'

    if ($CircuitId -or $RemoteId) {
        if (-not $usedCodes.Add(82)) { throw "Option 82 specified both via -CircuitId/-RemoteId and -Option; use only one." }
        $subMs = [System.IO.MemoryStream]::new()
        if ($CircuitId) {
            $cidBytes = ConvertTo-DhcpOptionBytes -Code 82 -Type $CircuitIdType -Value $CircuitId
            if ($cidBytes.Length -gt 255) { throw "CircuitId value is $($cidBytes.Length) bytes, exceeds the 255-byte sub-option limit." }
            $subMs.WriteByte(1)
            $subMs.WriteByte([byte]$cidBytes.Length)
            $subMs.Write($cidBytes, 0, $cidBytes.Length)
        }
        if ($RemoteId) {
            $ridBytes = ConvertTo-DhcpOptionBytes -Code 82 -Type $RemoteIdType -Value $RemoteId
            if ($ridBytes.Length -gt 255) { throw "RemoteId value is $($ridBytes.Length) bytes, exceeds the 255-byte sub-option limit." }
            $subMs.WriteByte(2)
            $subMs.WriteByte([byte]$ridBytes.Length)
            $subMs.Write($ridBytes, 0, $ridBytes.Length)
        }
        $allOptions.Add(@{ Code = 82; Type = 'ByteArray'; Value = $subMs.ToArray() })
    }

    $bindAddr = if ($Bind) {
        $parsed = $null
        if (-not [System.Net.IPAddress]::TryParse($Bind, [ref]$parsed)) { throw "Invalid -Bind address: '$Bind'." }
        $parsed
    } else { [System.Net.IPAddress]::Any }

    $giaddrBytes = if ($RelayAgentIPAddress) {
        $parsed = $null
        if (-not [System.Net.IPAddress]::TryParse($RelayAgentIPAddress, [ref]$parsed)) { throw "Invalid -RelayAgentIPAddress: '$RelayAgentIPAddress'." }
        $parsed.GetAddressBytes()
    } else { $null }

    $serverIP = $null
    try { $serverIP = [System.Net.IPAddress]::Parse($ServerAddress) }
    catch {
        try {
            $serverIP = [System.Net.Dns]::GetHostAddresses($ServerAddress) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
            if (-not $serverIP) { throw "No IPv4 address." }
        } catch { throw "Cannot resolve -ServerAddress '$ServerAddress': $_" }
    }
    $destEP = [System.Net.IPEndPoint]::new($serverIP, $ServerPort)

    # ── Result object ─────────────────────────────────────────────────────────

    $result = [PSCustomObject]@{
        Status           = 'Unknown'
        TransactionId    = '0x' + $xid.ToString('X8')
        ClientMac        = $clientMacString
        ServerAddress    = $ServerAddress
        ResponderAddress = $null
        ServerIdentifier = $null
        OfferedAddress   = $null
        AckAddress       = $null
        LeaseTimeSeconds = $null
        LeaseTime        = $null
        SubnetMask       = $null
        Router           = $null
        DnsServers       = $null
        DomainName       = $null
        RenewalTimeT1    = $null
        RebindingTimeT2  = $null
        RequestSent      = $false
        NakMessage       = $null
        Options          = $null
        Attempts         = 0
        ElapsedMs        = $null
        Error            = $null
    }

    # ── Socket setup ─────────────────────────────────────────────────────────

    $udp = [System.Net.Sockets.UdpClient]::new()
    try {
        $udp.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
        $udp.EnableBroadcast = $true
        try {
            $udp.Client.Bind([System.Net.IPEndPoint]::new($bindAddr, $ClientPort))
        } catch [System.Net.Sockets.SocketException] {
            throw "Failed to bind UDP port $ClientPort ($($_.Exception.Message)). This usually means the Windows 'Dhcp' client service or another instance of this tool holds the port, or you are not running elevated. Try: (1) run PowerShell as Administrator, and/or (2) temporarily stop the DHCP Client service: Stop-Service Dhcp -Force (Start-Service Dhcp afterward)."
        }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            # ── DISCOVER → OFFER ─────────────────────────────────────────────
            $discoverPkt = New-DhcpPacket -MessageType $MSG_DISCOVER -Xid $xid -ChaddrBytes $clientMacBytes -Options $allOptions -RequestedIP $RequestedIPAddress -GiaddrBytes $giaddrBytes

            $attempt = 0
            $offer = $null
            while (-not $offer -and $attempt -lt $Retries) {
                $null = $udp.Send($discoverPkt, $discoverPkt.Length, $destEP)
                $result.Attempts++
                Write-Verbose "Sent DHCPDISCOVER (xid=$($result.TransactionId), chaddr=$clientMacString) to $($destEP), attempt $($attempt + 1)/$Retries"

                $r = Recv $udp ($TimeoutSeconds * 1000)
                if (-not $r) {
                    $attempt++
                    Write-Verbose "No reply within $TimeoutSeconds s (retry $attempt/$Retries)"
                    continue
                }

                $rawOpts = Read-DhcpOptions $r.Data
                $rxXid = ReadU32BE $r.Data 4
                $msgType = Get-DhcpMessageTypeName $rawOpts

                if ($rxXid -ne $xid -or $msgType -ne 'Offer') {
                    Write-Verbose "Ignoring unrelated packet (xid=0x$($rxXid.ToString('X8')), type=$msgType) from $($r.EP.Address)"
                    continue
                }

                $offer = $r
            }

            if ($LogActivity) { Write-Log -Message "DISCOVER sent, xid=$($result.TransactionId), attempts=$($result.Attempts)" -Level INFO -fileNamePrefix 'Invoke-DhcpTest' }

            if (-not $offer) {
                $result.Status = 'Timeout'
                $result.Error = "No DHCPOFFER received after $Retries attempt(s) ($TimeoutSeconds sec each)."
                $result.ElapsedMs = $sw.Elapsed.TotalMilliseconds
                return $result
            }

            $offerRaw = Read-DhcpOptions $offer.Data
            $offerDecoded = ConvertFrom-DhcpOptions $offerRaw
            $offeredAddress = Format-IPBytes $offer.Data 16
            $serverIdentifier = if ($offerDecoded.Contains(54)) { $offerDecoded[54] } else { $offer.EP.Address.ToString() }

            $result.Status = 'OfferReceived'
            $result.ResponderAddress = $offer.EP.Address.ToString()
            $result.ServerIdentifier = $serverIdentifier
            $result.OfferedAddress = $offeredAddress
            $result.LeaseTimeSeconds = if ($offerDecoded.Contains(51)) { [int]$offerDecoded[51] } else { $null }
            $result.LeaseTime = if ($result.LeaseTimeSeconds) { [TimeSpan]::FromSeconds($result.LeaseTimeSeconds) } else { $null }
            $result.SubnetMask = if ($offerDecoded.Contains(1)) { $offerDecoded[1] } else { $null }
            $result.Router = if ($offerDecoded.Contains(3)) { $offerDecoded[3] } else { $null }
            $result.DnsServers = if ($offerDecoded.Contains(6)) { $offerDecoded[6] } else { $null }
            $result.DomainName = if ($offerDecoded.Contains(15)) { $offerDecoded[15] } else { $null }
            $result.RenewalTimeT1 = if ($offerDecoded.Contains(58)) { [int]$offerDecoded[58] } else { $null }
            $result.RebindingTimeT2 = if ($offerDecoded.Contains(59)) { [int]$offerDecoded[59] } else { $null }
            $result.Options = $offerDecoded

            Write-Verbose "DHCPOFFER received: address=$offeredAddress server=$serverIdentifier lease=$($result.LeaseTimeSeconds)s"

            if (-not $SendRequest) {
                $result.ElapsedMs = $sw.Elapsed.TotalMilliseconds
                return $result
            }

            # ── REQUEST → ACK/NAK ────────────────────────────────────────────
            $requestedIP = if ($RequestedIPAddress) { $RequestedIPAddress } else { $offeredAddress }

            if (-not $PSCmdlet.ShouldProcess("$ServerAddress`:$ServerPort", "Request lease $requestedIP via server $serverIdentifier")) {
                $result.ElapsedMs = $sw.Elapsed.TotalMilliseconds
                return $result
            }

            $requestPkt = New-DhcpPacket -MessageType $MSG_REQUEST -Xid $xid -ChaddrBytes $clientMacBytes -Options $allOptions -RequestedIP $requestedIP -ServerId $serverIdentifier -GiaddrBytes $giaddrBytes
            $result.RequestSent = $true

            $attempt = 0
            $final = $null
            while (-not $final -and $attempt -lt $Retries) {
                $null = $udp.Send($requestPkt, $requestPkt.Length, $destEP)
                Write-Verbose "Sent DHCPREQUEST for $requestedIP (xid=$($result.TransactionId)), attempt $($attempt + 1)/$Retries"

                $r = Recv $udp ($TimeoutSeconds * 1000)
                if (-not $r) {
                    $attempt++
                    Write-Verbose "No reply within $TimeoutSeconds s (retry $attempt/$Retries)"
                    continue
                }

                $rawOpts = Read-DhcpOptions $r.Data
                $rxXid = ReadU32BE $r.Data 4
                $msgType = Get-DhcpMessageTypeName $rawOpts

                if ($rxXid -ne $xid -or ($msgType -ne 'Ack' -and $msgType -ne 'Nak')) {
                    Write-Verbose "Ignoring unrelated packet (xid=0x$($rxXid.ToString('X8')), type=$msgType) from $($r.EP.Address)"
                    continue
                }

                $final = @{ Reply = $r; RawOpts = $rawOpts; MsgType = $msgType }
            }

            if ($LogActivity) { Write-Log -Message "REQUEST sent for $requestedIP, xid=$($result.TransactionId)" -Level INFO -fileNamePrefix 'Invoke-DhcpTest' }

            if (-not $final) {
                $result.Status = 'NoAckResponse'
                $result.Error = "No DHCPACK/DHCPNAK received after $Retries attempt(s) ($TimeoutSeconds sec each)."
                $result.ElapsedMs = $sw.Elapsed.TotalMilliseconds
                return $result
            }

            $finalDecoded = ConvertFrom-DhcpOptions $final.RawOpts
            $result.ResponderAddress = $final.Reply.EP.Address.ToString()
            $result.Options = $finalDecoded

            if ($final.MsgType -eq 'Nak') {
                $result.Status = 'NakReceived'
                $result.NakMessage = if ($finalDecoded.Contains(56)) { $finalDecoded[56] } else { $null }
                Write-Verbose "DHCPNAK received: $($result.NakMessage)"
            } else {
                $ackAddress = Format-IPBytes $final.Reply.Data 16
                $result.Status = 'AckReceived'
                $result.AckAddress = $ackAddress
                $result.LeaseTimeSeconds = if ($finalDecoded.Contains(51)) { [int]$finalDecoded[51] } else { $result.LeaseTimeSeconds }
                $result.LeaseTime = if ($result.LeaseTimeSeconds) { [TimeSpan]::FromSeconds($result.LeaseTimeSeconds) } else { $null }
                $result.ServerIdentifier = if ($finalDecoded.Contains(54)) { $finalDecoded[54] } else { $result.ServerIdentifier }
                Write-Verbose "DHCPACK received: address=$ackAddress lease=$($result.LeaseTimeSeconds)s"
            }

            $result.ElapsedMs = $sw.Elapsed.TotalMilliseconds
            return $result
        }
        catch [System.Net.Sockets.SocketException] {
            $result.Status = 'Error'
            $result.Error = $_.Exception.Message
            $result.ElapsedMs = $sw.Elapsed.TotalMilliseconds
            return $result
        }
    }
    finally {
        $udp.Close()
        $udp.Dispose()
    }
}
