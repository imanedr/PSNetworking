function Test-IpInSubnet
{
    <#
    .SYNOPSIS
    Validates if an IP address falls within a specified subnet or range.

    .DESCRIPTION
    The Test-IpInSubnet cmdlet validates if a given IPv4 address falls within a specified subnet or range.
    It accepts an IPv4 address and a subnet or range as input, and returns a Boolean value indicating whether the IP address is within the subnet or range.

    .PARAMETER IPv4Address
    Specifies the IPv4 address to validate. This parameter is mandatory and accepts the value from pipeline.

    .PARAMETER SubnetOrRange
    Specifies the subnet or range to validate the IPv4 address against. This parameter accepts either a subnet in CIDR format or a range in x.x.x.x-x.x.x.y format.

    .EXAMPLE
    PS C:\> Test-IpInSubnet -IPv4Address "192.168.1.100" -SubnetOrRange "192.168.1.0/24"
    True

    PS C:\> Test-IpInSubnet -IPv4Address "192.168.1.100" -SubnetOrRange "192.168.0.0-192.168.255.255"
    True

    .OUTPUTS
    System.Boolean

    .NOTES
    This cmdlet requires .NET Framework to be installed.
    #>
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({
            if ($_ -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$")
            {
                $true
            }
            else
            {
                throw "The IP address ($_) format is not valid."
            }
        })]
        [System.Net.IPAddress]$IPv4Address,
        
        [ValidateScript({
                if (($_ -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") -or($_ -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}") -or ($_ -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}-\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"))
                {
                    $true
                }
                else
                {
                    throw "$_ is invalid. Use CIDR format for subnets or x.x.x.x-x.x.x.y for ranges."
                }
            })]
        [string]$SubnetOrRange
    )

    begin
    {
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
       
    }

    process
    {
        if ($SubnetOrRange -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$")
        {
            $SubnetOrRange = $SubnetOrRange + "/32"
        }
        if ($SubnetOrRange -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}")
        {
            [System.Net.IPAddress]$netID, [int]$cidr = $SubnetOrRange -split "/"
            [System.Net.IPAddress]$mask = $bitMask[$cidr]
            $netID = $mask.Address -band $netID.Address
            $netID.Address -eq ($IPv4Address.Address -band $mask.Address)
        }
        elseif ($SubnetOrRange -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}-\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}")
        {
            [System.Net.IPAddress]$ipStart, [System.Net.IPAddress]$ipEnd = $SubnetOrRange -split "-"
            [version]$ipStart.IPAddressToString -le [version]$IPv4Address.IPAddressToString -and [version]$IPv4Address.IPAddressToString -le [version]$ipEnd.IPAddressToString
        }
        else
        {
            $false
        }
        
    }
}