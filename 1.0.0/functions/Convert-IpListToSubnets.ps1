<#
.SYNOPSIS
    Converts a list of IP addresses into the most efficient subnet representations.

.DESCRIPTION
    The Convert-IpListToSubnets function takes a list of IP addresses and converts them into the smallest possible subnet ranges that contain all the specified IPs. It can output subnets either in CIDR notation or traditional format.

.PARAMETER IPAddressList
    An array of IP addresses to be converted into subnet ranges.
    
.PARAMETER NotUseCIDRfor32
    When specified, outputs single IP addresses without the /32 CIDR notation.

.EXAMPLE
    Convert-IpListToSubnets -IPAddressList @("192.168.1.1", "192.168.1.2", "192.168.1.3")
    Output: 192.168.1.1/32
            192.168.1.2/31

.EXAMPLE
    Convert-IpListToSubnets -IPAddressList @("10.0.0.1", "10.0.0.5") -NotUseCIDRfor32
    Output: 10.0.0.1, 10.0.0.5

.EXAMPLE
    $ips = @("172.16.0.0", "172.16.0.1", "172.16.0.2", "172.16.0.3")
    Convert-IpListToSubnets -IPAddressList $ips
    Output: 172.16.0.0/30

.NOTES
    Author: Iman Edrisian
    Version: 1.0.0
    Requires: PowerShell 5.1 or higher
    
.LINK
    https://github.com/imanedr/psnetworking

.OUTPUTS
    System.String[]
    Returns an array of subnet representations in CIDR notation or IP format
#>
function Convert-IpListToSubnets
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] # The list of IP addresses is required
        [string[]]$IPAddressList,      # Input parameter: array of IP addresses
        [switch]$NotUseCIDRfor32       # Optional switch parameter to specify if /32 notation should be avoided
    )

    # List of all possible subnet masks represented in dotted-decimal format
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

    # Use a HashSet to remove duplicate IP addresses
    $hashSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($item in $IPAddressList) {
        [void]$hashSet.Add($item)  # Add each IP to the HashSet
    }
    
    # Sort the list of unique IP addresses
    $SortedIPs = Sort-IpAddress -IpAddressList $hashSet

    $ipcount = $SortedIPs.count  # Number of IP addresses
    $subnets = @()               # Initialize an array to hold the resulting subnets
    $current_netID = ''          # Placeholder for the current network ID
    $next_netID = ''             # Placeholder for the next network ID
    $i = 0                       # Initialize counter

    While ($i -lt $ipcount) {
        # Calculate the network ID for the current IP address
        $current_netID = $SortedIPs[$i]
        
        # Determine the temporary subnet representation based on the NotUseCIDRfor32 switch
        if ($NotUseCIDRfor32) {
            $tempSubnet = $SortedIPs[$i] 
        } else {
            $tempSubnet = $SortedIPs[$i] + "/32"  # Default to /32 if not specified otherwise
        }
        
        $tempIndex = ""  # Temporary index for tracking
        for ($j = 31; $j -gt 0; $j--) {
            # Determine the next network ID based on the subnet mask
            $next_netID = Get-NetID -ipaddress $SortedIPs[$i] -subnetmask $bitMask[$j]
            
            if ($current_netID -eq $next_netID) {
                # Check if the current IP and next IP share the same network ID
                
                # Calculate the potential broadcast index for this subnet size
                $broadCastIndex = (([math]::pow(2, (32 - $j))) - 1 + $i)
                if ($broadCastIndex -gt ($ipcount - 1)) {
                    # Use the calculated subnet if broadcast index exceeds the list
                    $tempSubnet = $current_netID + "/$($j+1)"
                    Break                   
                } else {
                    # Determine the network ID for the broadcast index IP
                    $broadCastNetID = Get-NetID -ipaddress $SortedIPs[$broadCastIndex] -subnetmask $bitMask[$j]
                }

                if ($current_netID -eq $broadCastNetID) {
                    # Validate if broadcast and current network IDs match
                    $tempSubnet = $current_netID + "/$j"
                    $tempIndex = $broadCastIndex  # Update the temp index
                } else {
                    # Break if broadcast addresses do not match
                    break
                }
            } else {
                # If network IDs differ, exit loop
                break
            }
        }

        # Append the calculated subnet to the list
        $subnets += $tempSubnet
        if ($tempIndex) { 
            $i = $tempIndex + 1  # Advance to the index after the broadcast if applicable
        } else { 
            $i++  # Increment the index
        }
    }

    # Output the list of calculated subnets
    Return $subnets
}

Function Get-NetID([string]$ipaddress, $subnetmask)
{
    # Converts an IP address and subnet mask into the corresponding Network ID
    $ip = [ipaddress]$ipaddress  # Convert string IP to IPAddress object
    $subnet = [ipaddress]$subnetmask  # Convert string subnet to IPAddress object
    $netid = [ipaddress]($ip.address -band $subnet.address)  # Perform a bitwise AND to get Network ID
    Return $netid.IPAddressToString  # Return the Network ID as a string
}
