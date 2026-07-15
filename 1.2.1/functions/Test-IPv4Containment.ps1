function Test-IPv4Containment {
    param (
        [string]$Source,
        [string]$Destination
    )

    function Convert-IPToInt {
        param (
            [string]$IP
        )
        $bytes = $IP.Split('.').ForEach{ [int]$_ }
        return ($bytes[0] -shl 24) -bor ($bytes[1] -shl 16) -bor ($bytes[2] -shl 8) -bor $bytes[3]
    }
    
    function Validate-IP {
        param (
            [string]$IP
        )
        return [System.Net.IPAddress]::TryParse($IP, [ref]([System.Net.IPAddress]$null))
    }

    function ParseInput {
        param (
            [string]$Input_
        )
        if ($Input_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$') {
            # Subnet notation
            $ip, $mask = $Input_ -split '/'
            if (-not (Validate-IP -IP $ip) -or $mask -gt 32 -or $mask -lt 0) { throw "Invalid subnet." }
            $ipInt = Convert-IPToInt -IP $ip
            $maskInt = -bnot [math]::Pow(2, (32 - $mask)) + 1
            $networkAddress = $ipInt -band $maskInt
            $broadcastAddress = $networkAddress + [math]::Pow(2, (32 - $mask)) - 1
            return @{
                Type = 'Subnet'
                Start = $networkAddress
                End = $broadcastAddress
            }
        } elseif ($Input_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\-\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            # Range notation
            $startIP, $endIP = $Input_ -split '-'
            if (-not (Validate-IP -IP $startIP) -or -not (Validate-IP -IP $endIP)) { throw "Invalid IP Range." }
            return @{
                Type = 'Range'
                Start = Convert-IPToInt -IP $startIP
                End = Convert-IPToInt -IP $endIP
            }
        } elseif ($Input_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            # Single IP
            if (-not (Validate-IP -IP $Input_)) { throw "Invalid IP." }
            $ipInt = Convert-IPToInt -IP $Input_
            return @{
                Type = 'IP'
                Start = $ipInt
                End = $ipInt
            }
        } else {
            throw $_
        }
    }

    try {
        $sourceRange = ParseInput -Input_ $Source
        $destinationRange = ParseInput -Input_ $Destination

        return ($sourceRange.Start -ge $destinationRange.Start -and $sourceRange.End -le $destinationRange.End)
    } catch {
        Write-Error $_.Exception.Message
        return $false
    }
}

# Example usage:
# Test-Containment -Source "10.0.0.0" -Destination "10.0.0.0/24"
# Test-Containment -Source "10.0.0.64/26" -Destination "10.0.0.0/24"
# Test-Containment -Source "10.0.0.30" -Destination "10.0.0.0-10.0.0.50"