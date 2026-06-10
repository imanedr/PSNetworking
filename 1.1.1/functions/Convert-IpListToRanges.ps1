<#
.SYNOPSIS
    Converts a list of IP addresses into contiguous IP ranges.

.DESCRIPTION
    The Convert-IpListToRanges function takes a list of IP addresses, deduplicates and sorts them, then
    groups consecutive addresses into compact range notation (startIP-endIP). Isolated addresses are
    returned as plain IP strings. The result is suitable for firewall rules, ACLs, or any system that
    accepts range-style input.

.PARAMETER IPAddressList
    An array of IPv4 addresses to be collapsed into ranges.

.EXAMPLE
    Convert-IpListToRanges -IPAddressList @("192.168.1.1","192.168.1.2","192.168.1.3","192.168.1.5")
    Output:
        192.168.1.1-192.168.1.3
        192.168.1.5

.EXAMPLE
    Convert-IpListToRanges -IPAddressList @("10.0.0.1","10.0.0.2","10.0.0.3","10.0.0.4")
    Output:
        10.0.0.1-10.0.0.4

.EXAMPLE
    $ips = Get-Content "ip_addresses.txt"
    Convert-IpListToRanges -IPAddressList $ips

.NOTES
    Author: Iman Edrisian
    Version: 1.0.0
    Requires: PowerShell 5.1 or higher

.LINK
    https://github.com/imanedr/psnetworking

.OUTPUTS
    System.String[]
    Returns an array of strings. Each element is either a single IP address or a range in
    "firstIP-lastIP" format.
#>
function Convert-IpListToRanges
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$IPAddressList
    )

    function ConvertTo-IPInt ([string]$IP) {
        $o = $IP.Split('.')
        return ([uint32]$o[0] -shl 24) -bor ([uint32]$o[1] -shl 16) -bor ([uint32]$o[2] -shl 8) -bor [uint32]$o[3]
    }

    function ConvertFrom-IPInt ([uint32]$Value) {
        return '{0}.{1}.{2}.{3}' -f (($Value -shr 24) -band 255),
                                     (($Value -shr 16) -band 255),
                                     (($Value -shr 8)  -band 255),
                                     ($Value            -band 255)
    }

    $hashSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($item in $IPAddressList) {
        [void]$hashSet.Add($item.Trim())
    }

    $sortedIPs = Sort-IpAddress -IpAddressList $hashSet

    if (-not $sortedIPs -or $sortedIPs.Count -eq 0) { return @() }

    $ipInts = @($sortedIPs | ForEach-Object { ConvertTo-IPInt $_ })

    $ranges   = @()
    $startInt = $ipInts[0]
    $endInt   = $ipInts[0]

    for ($i = 1; $i -lt $ipInts.Count; $i++) {
        if ($ipInts[$i] -eq $endInt + 1) {
            $endInt = $ipInts[$i]
        } else {
            $ranges += if ($startInt -eq $endInt) {
                ConvertFrom-IPInt $startInt
            } else {
                "$(ConvertFrom-IPInt $startInt)-$(ConvertFrom-IPInt $endInt)"
            }
            $startInt = $ipInts[$i]
            $endInt   = $ipInts[$i]
        }
    }

    $ranges += if ($startInt -eq $endInt) {
        ConvertFrom-IPInt $startInt
    } else {
        "$(ConvertFrom-IPInt $startInt)-$(ConvertFrom-IPInt $endInt)"
    }

    return $ranges
}
