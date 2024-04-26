<#
.SYNOPSIS
Get-IPAddressesInSubnet returns all IP addresses in a subnet specified by a subnet mask in CIDR notation.

.DESCRIPTION
This function takes a subnet specified in CIDR notation (e.g. 192.168.0.0/24) and returns all IP addresses in the subnet. The function uses bitwise operations to calculate the network ID and wildcard mask from the subnet mask, and then loops through all possible IP addresses in the subnet to generate a list of IP addresses.

.PARAMETER Subnet
Mandatory string parameter to specify the subnet in CIDR notation (e.g. 192.168.0.0/24)

.EXAMPLE
Get-IPAddressesInSubnet -Subnet "192.168.0.0/24"

This example returns a list of all IP addresses in the subnet specified by the subnet mask 192.168.0.0/24.
#>
function Get-IPAddressesInSubnet {
    [CmdletBinding()]
    param (
        # Parameter to specify the subnet in CIDR notation (e.g. 192.168.0.0/24)
        [Parameter(Mandatory)]
        [string]
        $Subnet
    )

    # List of subnet masks for all possible CIDR values (from /0 to /32)
    $bitMask = @('0.0.0.0',
            '128.0.0.0',
            '192.0.0.0',
            '224.0.0.0',
            '240.0.0.0',
            '248.0.0.0',
            '252.0.0.0',
            '254.0.0.0',
            '255.0.0.0',
            '255.128.0.0',
            '255.192.0.0',
            '255.224.0.0',
            '255.240.0.0',
            '255.248.0.0',
            '255.252.0.0',
            '255.254.0.0',
            '255.255.0.0',
            '255.255.128.0',
            '255.255.192.0',
            '255.255.224.0',
            '255.255.240.0',
            '255.255.248.0',
            '255.255.252.0',
            '255.255.254.0',
            '255.255.255.0',
            '255.255.255.128',
            '255.255.255.192',
            '255.255.255.224',
            '255.255.255.240',
            '255.255.255.248',
            '255.255.255.252',
            '255.255.255.254',
            '255.255.255.255')

            # Split the Subnet parameter into the network ID and CIDR value
            [System.Net.IPAddress]$netID, [int]$cidr = $Subnet -split "/"

            # Calculate the network mask based on the CIDR notation
    [System.Net.IPAddress]$mask = $bitMask[$cidr]

    # Calculate the network ID based on the network mask and the IP address
    $netID = $mask.Address -band $netID.Address   

    # Get the octets of the network ID and the network mask
    $netIdOctets = $netID.GetAddressBytes()
    $maskOctets = $mask.GetAddressBytes()

    # Calculate the wildcard mask based on the network mask
    $wildCardMaskOctets = $maskOctets.ForEach({255 - $_})
    $ordered = [System.Collections.Specialized.OrderedDictionary]::new()
    # Loop through each octet of the network ID to calculate all the IP addresses in the subnet
    for ($i= $netIdOctets[0]; $i -le ($netIdOctets[0] -bor $wildCardMaskOctets[0]); $i++){
        for ($j= $netIdOctets[1]; $j -le ($netIdOctets[1] -bor $wildCardMaskOctets[1]); $j++){
            for ($k= $netIdOctets[2]; $k -le ($netIdOctets[2] -bor $wildCardMaskOctets[2]); $k++){
                for ($l= $netIdOctets[3]; $l -le ($netIdOctets[3] -bor $wildCardMaskOctets[3]); $l++){
                    # Write the calculated IP address to the output stream
                    $ip = "$i.$j.$k.$l"
                    $ordered.Add($ip, $ip)
                }
            }
        }
    }
    Return $ordered.Values
}