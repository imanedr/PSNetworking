#Requires -Version 5.1
<#
.SYNOPSIS
    Native PowerShell TFTP client — upload and download files without tftp.exe.

.DESCRIPTION
    Implements RFC 1350 (TFTP Protocol Revision 2) plus RFC 2347/2348 option
    extensions (blksize, windowsize).  All I/O uses System.Net.Sockets.UdpClient;
    no external executables are required.  Progress is printed to the console in
    a curl-like style.

.PARAMETER Server
    Hostname or IP address of the TFTP server.

.PARAMETER RemoteFile
    Path / filename as it should appear on the server side.

.PARAMETER LocalFile
    Local filesystem path to read from (Upload) or write to (Download).

.PARAMETER Operation
    'Download' (default) or 'Upload'.

.PARAMETER Port
    UDP port on the server. Default: 69.

.PARAMETER Mode
    Transfer mode: 'octet' (binary, default) or 'netascii'.

.PARAMETER BlockSize
    Payload bytes per DATA packet (RFC 2348). Range 8-65464. Default: 512.

.PARAMETER TimeoutSeconds
    Per-packet ACK/DATA wait timeout in seconds. Default: 5.

.PARAMETER Retries
    How many times to re-send a packet before giving up. Default: 5.

.PARAMETER WindowSize
    Unacknowledged blocks in flight (RFC 7440). Default: 1 (stop-and-wait).

.PARAMETER PassThru
    Download: return [byte[]] instead of writing a file.
    Upload:   accept [byte[]] from pipeline instead of reading a file.

.EXAMPLE
    Invoke-TFTPRequest -Server 192.168.1.1 -RemoteFile 'firmware.bin' -LocalFile 'C:\firmware.bin'

.EXAMPLE
    Invoke-TFTPRequest -Server 192.168.1.1 -RemoteFile 'backup.cfg' -LocalFile 'C:\backup.cfg' -Operation Upload -BlockSize 1468
#>
function Invoke-TFTPRequest {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$RemoteFile,
        [Parameter()][string]$LocalFile,
        [Parameter()][ValidateSet('Download','Upload')][string]$Operation = 'Download',
        [Parameter()][ValidateRange(1,65535)][int]$Port = 69,
        [Parameter()][ValidateSet('octet','netascii')][string]$Mode = 'octet',
        [Parameter()][ValidateRange(8,65464)][int]$BlockSize = 512,
        [Parameter()][ValidateRange(1,60)][int]$TimeoutSeconds = 5,
        [Parameter()][ValidateRange(1,10)][int]$Retries = 5,
        [Parameter()][ValidateRange(1,65535)][int]$WindowSize = 1,
        [Parameter(ValueFromPipeline)][switch]$PassThru
    )

    # ── Opcodes (RFC 1350 §5) ────────────────────────────────────────────────
    $OP_RRQ   = [uint16]1
    $OP_WRQ   = [uint16]2
    $OP_DATA  = [uint16]3
    $OP_ACK   = [uint16]4
    $OP_ERROR = [uint16]5
    $OP_OACK  = [uint16]6

    $ErrorMessages = @{
        0='Not defined'; 1='File not found'; 2='Access violation'
        3='Disk full'; 4='Illegal TFTP operation'; 5='Unknown transfer ID'
        6='File already exists'; 7='No such user'; 8='Failed to negotiate options'
    }

    # ── Helpers ──────────────────────────────────────────────────────────────

    function NullTerm([string]$s) {
        $b = [System.Text.Encoding]::ASCII.GetBytes($s)
        $r = [byte[]]::new($b.Length + 1)
        [Buffer]::BlockCopy($b, 0, $r, 0, $b.Length)
        $r[$b.Length] = 0
        return $r
    }

    function NextBlock([uint16]$n) {
        if ($n -ge 65535) { return [uint16]0 } else { return [uint16]($n + 1) }
    }

    function New-ReqPacket([uint16]$op, [string]$file, [string]$mode, [int]$blk, [int]$win) {
        $ms = [System.IO.MemoryStream]::new()
        $ms.WriteByte([byte]($op -shr 8)); $ms.WriteByte([byte]($op -band 0xFF))
        foreach ($b in (NullTerm $file)) { $ms.WriteByte($b) }
        foreach ($b in (NullTerm $mode)) { $ms.WriteByte($b) }
        if ($blk -ne 512) {
            foreach ($b in (NullTerm 'blksize'))  { $ms.WriteByte($b) }
            foreach ($b in (NullTerm "$blk"))     { $ms.WriteByte($b) }
        }
        if ($win -gt 1) {
            foreach ($b in (NullTerm 'windowsize')) { $ms.WriteByte($b) }
            foreach ($b in (NullTerm "$win"))       { $ms.WriteByte($b) }
        }
        return $ms.ToArray()
    }

    function New-AckPacket([uint16]$n) {
        [byte[]]@([byte]($OP_ACK -shr 8), [byte]($OP_ACK -band 0xFF),
                  [byte]($n -shr 8),      [byte]($n -band 0xFF))
    }

    function New-DataPacket([uint16]$n, [byte[]]$data) {
        $hdr = [byte[]]@([byte]($OP_DATA -shr 8), [byte]($OP_DATA -band 0xFF),
                         [byte]($n -shr 8),        [byte]($n -band 0xFF))
        $pkt = [byte[]]::new(4 + $data.Length)
        [Buffer]::BlockCopy($hdr,  0, $pkt, 0, 4)
        [Buffer]::BlockCopy($data, 0, $pkt, 4, $data.Length)
        return $pkt
    }

    function New-ErrPacket([uint16]$code, [string]$msg) {
        $tail = NullTerm $msg
        $pkt  = [byte[]]::new(4 + $tail.Length)
        $pkt[0] = [byte]($OP_ERROR -shr 8); $pkt[1] = [byte]($OP_ERROR -band 0xFF)
        $pkt[2] = [byte]($code -shr 8);     $pkt[3] = [byte]($code -band 0xFF)
        [Buffer]::BlockCopy($tail, 0, $pkt, 4, $tail.Length)
        return $pkt
    }

    function ReadU16([byte[]]$b, [int]$i) {
        (([int]$b[$i]) -shl 8) -bor [int]$b[$i+1]
    }

    function Get-ErrMsg([byte[]]$pkt) {
        $ec   = ReadU16 $pkt 2
        $mlen = [math]::Max(0, $pkt.Length - 5)
        $em   = if ($mlen -gt 0) { [System.Text.Encoding]::ASCII.GetString($pkt, 4, $mlen) } else { '' }
        return "Server error $ec ($($ErrorMessages[$ec])): $em"
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

    function Parse-OAck([byte[]]$pkt) {
        $opts = @{}; $i = 2
        while ($i -lt $pkt.Length) {
            $end = [Array]::IndexOf($pkt, [byte]0, $i)
            if ($end -lt 0) { break }
            $key = [System.Text.Encoding]::ASCII.GetString($pkt, $i, $end - $i).ToLower()
            $i = $end + 1
            $end = [Array]::IndexOf($pkt, [byte]0, $i)
            if ($end -lt 0) { $end = $pkt.Length }
            $opts[$key] = [System.Text.Encoding]::ASCII.GetString($pkt, $i, $end - $i)
            $i = $end + 1
        }
        return $opts
    }

    # ── Progress helpers ─────────────────────────────────────────────────────

    function Format-Size([long]$bytes) {
        if ($bytes -ge 1GB) { return '{0:F2} GiB' -f ($bytes / 1GB) }
        if ($bytes -ge 1MB) { return '{0:F2} MiB' -f ($bytes / 1MB) }
        if ($bytes -ge 1KB) { return '{0:F2} KiB' -f ($bytes / 1KB) }
        return "$bytes B"
    }

    function Format-Speed([double]$Bps) {
        if ($Bps -ge 1GB) { return '{0:F2} GiB/s' -f ($Bps / 1GB) }
        if ($Bps -ge 1MB) { return '{0:F2} MiB/s' -f ($Bps / 1MB) }
        if ($Bps -ge 1KB) { return '{0:F2} KiB/s' -f ($Bps / 1KB) }
        return ('{0:F0} B/s' -f $Bps)
    }

    function Format-Time([double]$sec) {
        if ($sec -lt 0 -or $sec -gt 359999) { return '--:--:--' }
        $h = [int]($sec / 3600); $m = [int](($sec % 3600) / 60); $s = [int]($sec % 60)
        return '{0:D2}:{1:D2}:{2:D2}' -f $h, $m, $s
    }

    function Show-Progress([string]$op, [long]$done, [long]$total, [double]$Bps) {
        $doneStr  = Format-Size $done
        $speedStr = Format-Speed $Bps

        if ($total -gt 0) {
            $pct = [int]([math]::Min(100, $done * 100 / $total))
            $eta = if ($Bps -gt 0) { [int](($total - $done) / $Bps) } else { -1 }
            Write-Progress -Activity "TFTP $op : $RemoteFile" `
                           -Status ('{0} / {1}  ({2})' -f $doneStr, (Format-Size $total), $speedStr) `
                           -PercentComplete $pct `
                           -SecondsRemaining $eta
        } else {
            Write-Progress -Activity "TFTP $op : $RemoteFile" `
                           -Status "$doneStr transferred  ($speedStr)" `
                           -PercentComplete -1
        }
    }

    function Show-Summary([string]$op, [long]$bytes, [double]$elapsed) {
        Write-Progress -Activity "TFTP $op : $RemoteFile" -Completed
        $speed = if ($elapsed -gt 0) { $bytes / $elapsed } else { 0 }
        Write-Host ('  {0} complete.  {1} in {2}  ({3})' -f `
            $op, (Format-Size $bytes), (Format-Time $elapsed), (Format-Speed $speed)) `
            -ForegroundColor Green
    }

    function Show-Header([string]$op, [string]$server, [string]$remote, [string]$local) {
        Write-Host ""
        Write-Host ("  {0,-10} {1}" -f "${op}:", $remote) -ForegroundColor Cyan
        Write-Host ("  {0,-10} {1}:{2}" -f "Server:", $server, $Port)
        if ($local) { Write-Host ("  {0,-10} {1}" -f "Local:", $local) }
        Write-Host ""
    }

    # ── Argument validation ──────────────────────────────────────────────────

    if ($Operation -eq 'Download' -and -not $PassThru -and -not $LocalFile) {
        throw 'Specify -LocalFile or -PassThru for Download.'
    }
    if ($Operation -eq 'Upload' -and -not $PassThru -and -not $LocalFile) {
        throw 'Specify -LocalFile or -PassThru for Upload.'
    }
    if ($Operation -eq 'Upload' -and $LocalFile -and -not (Test-Path $LocalFile)) {
        throw "Upload source not found: $LocalFile"
    }

    # ── Resolve server ───────────────────────────────────────────────────────

    try {
        $srvAddr = [System.Net.Dns]::GetHostAddresses($Server) |
                   Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                   Select-Object -First 1
        if (-not $srvAddr) { throw 'No IPv4 address.' }
    } catch { throw "Cannot resolve '$Server': $_" }

    $serverEP = [System.Net.IPEndPoint]::new($srvAddr, $Port)

    # ── Load upload data ─────────────────────────────────────────────────────

    [byte[]]$uploadData = $null
    if ($Operation -eq 'Upload') {
        if ($PassThru -and $input) { $uploadData = $input }
        else { $uploadData = [System.IO.File]::ReadAllBytes((Resolve-Path $LocalFile).Path) }
    }

    # ── Open socket ──────────────────────────────────────────────────────────

    $udp    = [System.Net.Sockets.UdpClient]::new(
                  [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0))
    $tmsOut = $TimeoutSeconds * 1000
    $reqPkt = New-ReqPacket `
                  ($(if ($Operation -eq 'Download') { $OP_RRQ } else { $OP_WRQ })) `
                  $RemoteFile $Mode $BlockSize $WindowSize

    Show-Header $Operation $Server $RemoteFile $LocalFile

    try {
        if (-not $PSCmdlet.ShouldProcess("$Server`:$Port", "$Operation $RemoteFile")) { return }

        # Send the initial RRQ / WRQ
        $null = $udp.Send($reqPkt, $reqPkt.Length, $serverEP)
        Write-Verbose "Sent $(if ($Operation -eq 'Download') { 'RRQ' } else { 'WRQ' }) to $($serverEP)"

        # ── DOWNLOAD ─────────────────────────────────────────────────────────
        if ($Operation -eq 'Download') {

            $recvBlocks    = [System.Collections.Generic.List[byte[]]]::new()
            $expectedBlock = [uint16]1
            $effectiveBlk  = $BlockSize
            $done          = $false
            $totalReceived = [long]0
            $knownTotal    = [long]0
            $sw            = [System.Diagnostics.Stopwatch]::StartNew()

            # ── First reply: OACK or DATA 1 ──────────────────────────────────
            $attempt  = 0
            $firstRes = $null
            while (-not $firstRes -and $attempt -lt $Retries) {
                $firstRes = Recv $udp $tmsOut
                if (-not $firstRes) {
                    $attempt++
                    Write-Verbose "No first reply, retry $attempt/$Retries"
                    $null = $udp.Send($reqPkt, $reqPkt.Length, $serverEP)
                }
            }
            if (-not $firstRes) { throw "No response from $Server after $Retries retries." }

            $firstPkt  = $firstRes.Data
            $remEP     = $firstRes.EP
            $serverTID = $remEP.Port
            $firstOp   = ReadU16 $firstPkt 0

            Write-Verbose "First reply: opcode=$firstOp from $($remEP.Address):$($remEP.Port)"

            if ($firstOp -eq $OP_ERROR) { throw (Get-ErrMsg $firstPkt) }

            if ($firstOp -eq $OP_OACK) {
                $opts = Parse-OAck $firstPkt
                if ($opts['blksize'])    { $effectiveBlk = [int]$opts['blksize'] }
                if ($opts['windowsize']) { $WindowSize   = [int]$opts['windowsize'] }
                if ($opts['tsize'])      { $knownTotal   = [long]$opts['tsize'] }
                Write-Verbose "OACK: blksize=$effectiveBlk win=$WindowSize tsize=$knownTotal"
                $ack = New-AckPacket 0
                $null = $udp.Send($ack, $ack.Length, $remEP)
            }
            elseif ($firstOp -eq $OP_DATA) {
                $bn      = ReadU16 $firstPkt 2
                if ($bn -ne 1) { throw "Expected DATA 1, got block $bn" }
                $payload = [byte[]]::new($firstPkt.Length - 4)
                [Array]::Copy($firstPkt, 4, $payload, 0, $payload.Length)
                $recvBlocks.Add($payload)
                $totalReceived += $payload.Length
                if ($payload.Length -lt $effectiveBlk) { $done = $true }
                $ack = New-AckPacket 1
                $null = $udp.Send($ack, $ack.Length, $remEP)
                $expectedBlock = NextBlock 1
                Write-Verbose "DATA 1 received ($($payload.Length) bytes)"

                $elapsed = $sw.Elapsed.TotalSeconds
                $Bps     = if ($elapsed -gt 0) { $totalReceived / $elapsed } else { 0 }
                Show-Progress 'Download' $totalReceived $knownTotal $Bps
            }
            else { throw "Unexpected opcode $firstOp" }

            # ── Main download loop ────────────────────────────────────────────
            while (-not $done) {
                $windowReceived = 0
                $lastAcked      = if ($expectedBlock -eq 0) { [uint16]65535 } else { [uint16]($expectedBlock - 1) }

                while ($windowReceived -lt $WindowSize -and -not $done) {
                    $attempt = 0
                    $res     = $null
                    while (-not $res -and $attempt -lt $Retries) {
                        $res = Recv $udp $tmsOut
                        if (-not $res) {
                            $attempt++
                            Write-Verbose "Timeout waiting for block $expectedBlock, re-ACK $lastAcked (retry $attempt/$Retries)"
                            $ack = New-AckPacket $lastAcked
                            $null = $udp.Send($ack, $ack.Length, $remEP)
                        }
                    }
                    if (-not $res) { throw "Stalled at block $expectedBlock after $Retries retries." }

                    $pkt = $res.Data
                    $ep  = $res.EP

                    if ($ep.Port -ne $serverTID) {
                        $errPkt = New-ErrPacket 5 'Unknown TID'
                        $null = $udp.Send($errPkt, $errPkt.Length, $ep)
                        continue
                    }

                    $op = ReadU16 $pkt 0
                    if ($op -eq $OP_ERROR) { throw (Get-ErrMsg $pkt) }
                    if ($op -ne $OP_DATA)  { throw "Expected DATA, got opcode $op" }

                    $bn = ReadU16 $pkt 2
                    if ($bn -eq $expectedBlock) {
                        $payload = [byte[]]::new($pkt.Length - 4)
                        [Array]::Copy($pkt, 4, $payload, 0, $payload.Length)
                        $recvBlocks.Add($payload)
                        $totalReceived += $payload.Length

                        if ($payload.Length -lt $effectiveBlk) { $done = $true }
                        $lastAcked     = $bn
                        $expectedBlock = NextBlock $bn
                        $windowReceived++

                        Write-Verbose "DATA $bn received ($($payload.Length) bytes, total $totalReceived)"

                        $elapsed = $sw.Elapsed.TotalSeconds
                        $Bps     = if ($elapsed -gt 0) { $totalReceived / $elapsed } else { 0 }
                        Show-Progress 'Download' $totalReceived $knownTotal $Bps
                    }
                    else {
                        Write-Verbose "Out-of-order block $bn (expected $expectedBlock), ignoring"
                    }
                }

                $ack = New-AckPacket $lastAcked
                $null = $udp.Send($ack, $ack.Length, $remEP)
            }

            $elapsed = $sw.Elapsed.TotalSeconds

            $outBuf = [byte[]]::new($totalReceived)
            $pos    = 0
            foreach ($blk in $recvBlocks) {
                [Buffer]::BlockCopy($blk, 0, $outBuf, $pos, $blk.Length)
                $pos += $blk.Length
            }

            Show-Summary 'Download' $totalReceived $elapsed

            if ($PassThru) { return $outBuf }
            else {
                [System.IO.File]::WriteAllBytes($LocalFile, $outBuf)
                Write-Host "  Saved to $LocalFile" -ForegroundColor Gray
            }
        }

        # ── UPLOAD ───────────────────────────────────────────────────────────
        else {
            $effectiveBlk = $BlockSize
            $totalBytes   = [long]$uploadData.Length
            $sw           = [System.Diagnostics.Stopwatch]::StartNew()

            # ── Wait for ACK 0 / OACK ─────────────────────────────────────────
            $attempt  = 0
            $firstRes = $null
            while (-not $firstRes -and $attempt -lt $Retries) {
                $firstRes = Recv $udp $tmsOut
                if (-not $firstRes) {
                    $attempt++
                    Write-Verbose "No WRQ reply, retry $attempt/$Retries"
                    $null = $udp.Send($reqPkt, $reqPkt.Length, $serverEP)
                }
            }
            if (-not $firstRes) { throw "No response from $Server after $Retries retries." }

            $firstPkt = $firstRes.Data
            $sendEP   = $firstRes.EP
            Write-Verbose "Server TID $($sendEP.Address):$($sendEP.Port)"

            $firstOp = ReadU16 $firstPkt 0

            if ($firstOp -eq $OP_ERROR) { throw (Get-ErrMsg $firstPkt) }
            elseif ($firstOp -eq $OP_OACK) {
                $opts = Parse-OAck $firstPkt
                if ($opts['blksize'])    { $effectiveBlk = [int]$opts['blksize'] }
                if ($opts['windowsize']) { $WindowSize   = [int]$opts['windowsize'] }
                Write-Verbose "OACK: blksize=$effectiveBlk win=$WindowSize"
            }
            elseif ($firstOp -eq $OP_ACK) {
                $ab = ReadU16 $firstPkt 2
                if ($ab -ne 0) { throw "Expected ACK 0, got ACK $ab" }
                Write-Verbose "ACK 0 received — starting transfer (blksize=$effectiveBlk)"
            }
            else { throw "Expected ACK 0 or OACK, got opcode $firstOp" }

            # Show initial progress bar at 0%
            Show-Progress 'Upload' 0 $totalBytes 0

            # ── Main upload loop ──────────────────────────────────────────────
            # blockNum: the block number of the FIRST packet in the current window.
            # Inside the window loop we only advance blockNum between packets, never
            # for the last packet of a window — that increment happens in the outer
            # else-branch so the next window starts on the correct number.
            $blockNum = [uint16]1
            $offset   = [long]0
            $done     = $false

            while (-not $done) {
                $windowPkts   = [System.Collections.Generic.List[byte[]]]::new()
                $isLastWindow = $false

                # Build window: collect up to $WindowSize DATA packets.
                # blockNum is incremented between packets (not after the last one),
                # so after the loop $blockNum == the last block number sent this window.
                for ($w = 0; $w -lt $WindowSize; $w++) {
                    $remaining = $totalBytes - $offset
                    $chunkSize = [int][math]::Min($effectiveBlk, [math]::Max(0, $remaining))

                    $chunk = [byte[]]::new($chunkSize)
                    if ($chunkSize -gt 0) {
                        [Buffer]::BlockCopy($uploadData, $offset, $chunk, 0, $chunkSize)
                        $offset += $chunkSize
                    }

                    $windowPkts.Add((New-DataPacket $blockNum $chunk))
                    Write-Verbose "  Queuing DATA block $blockNum ($chunkSize bytes, offset $offset / $totalBytes)"

                    if ($chunkSize -lt $effectiveBlk) {
                        $isLastWindow = $true
                        break
                    }

                    if ($w -lt $WindowSize - 1) {
                        $blockNum = NextBlock $blockNum
                    }
                }

                # $blockNum now equals the block number of the last packet sent
                $expectedAck = $blockNum

                # Send the window
                foreach ($dp in $windowPkts) {
                    $null = $udp.Send($dp, $dp.Length, $sendEP)
                }
                Write-Verbose "Sent window, last block $blockNum, awaiting ACK $expectedAck"

                # Wait for expected ACK.  Stale ACKs (leftover from previous windows) are
                # discarded without counting as a retry — only genuine timeouts increment $attempt.
                $attempt      = 0
                $ackConfirmed = $false
                while (-not $ackConfirmed -and $attempt -lt $Retries) {
                    $r = Recv $udp $tmsOut
                    if (-not $r) {
                        $attempt++
                        Write-Verbose "Timeout waiting for ACK $expectedAck (retry $attempt/$Retries) — retransmitting window"
                        foreach ($dp in $windowPkts) {
                            $null = $udp.Send($dp, $dp.Length, $sendEP)
                        }
                        continue
                    }

                    if ($r.EP.Port -ne $sendEP.Port) {
                        $errPkt = New-ErrPacket 5 'Unknown TID'
                        $null = $udp.Send($errPkt, $errPkt.Length, $r.EP)
                        Write-Verbose "Discarding packet from unknown TID $($r.EP.Port) (expected $($sendEP.Port))"
                        continue
                    }

                    $ackPkt = $r.Data
                    $ackOp  = ReadU16 $ackPkt 0
                    if ($ackOp -eq $OP_ERROR) { throw (Get-ErrMsg $ackPkt) }
                    if ($ackOp -ne $OP_ACK) {
                        Write-Verbose "Discarding non-ACK opcode $ackOp"
                        continue
                    }

                    $ackedBlock = ReadU16 $ackPkt 2
                    Write-Verbose "Received ACK $ackedBlock (expected $expectedAck)"

                    if ($ackedBlock -eq $expectedAck) {
                        $ackConfirmed = $true
                    } else {
                        Write-Verbose "Stale ACK $ackedBlock discarded (expected $expectedAck)"
                    }
                }
                if (-not $ackConfirmed) { throw "Upload stalled after $Retries retries at block $expectedAck." }

                # Update progress on every window ACK
                $elapsed = $sw.Elapsed.TotalSeconds
                $Bps     = if ($elapsed -gt 0) { $offset / $elapsed } else { 0 }
                Show-Progress 'Upload' $offset $totalBytes $Bps

                if ($isLastWindow) {
                    $done = $true
                } else {
                    $blockNum = NextBlock $blockNum
                }
            }

            Show-Summary 'Upload' $totalBytes $sw.Elapsed.TotalSeconds
        }
    }
    finally {
        $udp.Close()
        $udp.Dispose()
    }
}
