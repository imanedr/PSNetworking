function Get-IpAddressesInRange {
    <#
    .SYNOPSIS
    Returns all IP addresses in a given range.

    .DESCRIPTION
    This function takes a range of IP addresses as input and returns all IP addresses in that range. The range is specified as two IP addresses separated by a hyphen.

    .PARAMETER Range
    The range of IP addresses to return, specified as two IP addresses separated by a hyphen.

    .EXAMPLE
    Get-IpAddressesInRange -Range "192.168.1.1-192.168.1.5"
    Returns all IP addresses in the range 192.168.1.1 to 192.168.1.5.

    .OUTPUTS
    System.Net.IPAddress
    The function returns a list of System.Net.IPAddress objects.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Range
    )

    # Split the input range into start and end IP addresses
    [System.Net.IPAddress]$startIP, [System.Net.IPAddress]$endIP = $Range -split "-"

    # Get the octets of the start and end IP addresses
    $startIPOctets = $startIP.GetAddressBytes()
    $endIPOctets = $endIP.GetAddressBytes()
    $ordered = [System.Collections.Specialized.OrderedDictionary]::new()
    # Loop through the IP addresses in the range
    While ($startIP -ne $endip){
        # Output the current IP address
        $ordered.Add($startIP.IPAddressToString, $startIP.IPAddressToString)

        # Get the octets of the current IP address
        $iBytes =  $startIP.GetAddressBytes()
        
        # Reverse the octets
        [Array]::Reverse($iBytes)

        # Increment the current IP address by 1
        $nextBytes = [BitConverter]::GetBytes([UInt32]([bitconverter]::ToUInt32($iBytes,0) +1))
        
        # Reverse the octets back to their original order
        [Array]::Reverse($nextBytes)

        # Set the current IP address to the next IP address
        $startIP = [IPAddress]$nextBytes
    }
    $ordered.Values
    # Output the end IP address
    $endip.IPAddressToString
}
