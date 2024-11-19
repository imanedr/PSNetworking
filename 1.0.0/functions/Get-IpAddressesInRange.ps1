<#
.SYNOPSIS
    Generates a list of IP addresses within a specified IP range.

.DESCRIPTION
    The Get-IpAddressesInRange function takes a range of IP addresses and returns all IP addresses within that range inclusively. 
    It handles IPv4 addresses and outputs them in ascending order.

.PARAMETER Range
    Specifies the IP address range in the format "startIP-endIP".
    Example: "192.168.1.1-192.168.1.10"

.EXAMPLE
    Get-IpAddressesInRange -Range "192.168.1.1-192.168.1.5"
    
    Returns:
    192.168.1.1
    192.168.1.2
    192.168.1.3
    192.168.1.4
    192.168.1.5

.NOTES
    Author: Iman Edrisian
    Version: 1.0.0
    Requires: PowerShell 5.1 or higher

.LINK
    https://github.com/imanedr/psnetworking

.INPUTS
    System.String

.OUTPUTS
    System.String[]
#>

function Get-IpAddressesInRange {
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
