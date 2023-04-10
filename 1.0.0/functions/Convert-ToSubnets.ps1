function Convert-ToSubnets
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] # The list of IP addresses is required
        [string[]]$IPAddressList
    )

    # This array contains all possible subnet masks
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


    # Sort the IP addresses
    $SortedIPs = Sort-IpAddress -IpAddressList $IPAddressList

    $subnets = @()
    $current_netID = ''
    $next_netID = ''
    $i = 0
    While ($i -lt $SortedIPs.count)
    {
        # Get the network ID of the current IP address
        $current_netID = $SortedIPs[$i]
        $tempSubnet = $SortedIPs[$i] + "/32"
        $tempIndex = ""
        for ($j = 31; $j -gt 0; $j--)
        {
            # Get the network ID of the next IP address using a specific subnet mask
            $next_netID = Get-NetID -ipaddress $SortedIPs[$i] -subnetmask $bitMask[$j]
            if ($current_netID -eq $next_netID)
            {
                # If the current and next IP addresses have the same network ID, they are in the same subnet
                # Calculate the broadcast address of the subnet
                $broadCastIndex = (([math]::pow(2, (32 - $j))) - 1 + $i)
                if ($broadCastIndex -gt ($sortedips.count - 1))
                {
                    # If the broadcast address is outside the range of the IP addresses, use the current IP address as the subnet address
                    $tempSubnet = $current_netID + "/$($j+1)"
                    Break                   
                }
                else
                {
                    # Calculate the network ID of the broadcast address
                    $broadCastNetID = Get-NetID -ipaddress $SortedIPs[$broadCastIndex] -subnetmask $bitMask[$j]
                }

                # If the broadcast address and the current IP address have the same network ID, use the current IP address as the subnet address
                if ($current_netID -eq $broadCastNetID)
                {
                    $tempSubnet = $current_netID + "/$j"
                    $tempIndex = $broadCastIndex
                }
                else
                {
                    # Otherwise, use the broadcast address as the subnet address
                    break
                }
            }
            else
            {
                # If the network IDs of the current and next IP addresses are different, they are in different subnets
                break
            }
        }
        # Add the subnet address to the list of subnets
        $subnets += $tempSubnet
        if ($tempIndex) { $i = $tempIndex + 1 } else { $i++ }
    }
    # Return the list of subnets
    Return $subnets
}


Function Get-NetID([string]$ipaddress, $subnetmask)
{
    $ip = [ipaddress]$ipaddress
    $subnet = [ipaddress]$subnetmask
    $netid = [ipaddress]($ip.address -band $subnet.address)
    Return $netid.IPAddressToString
}
