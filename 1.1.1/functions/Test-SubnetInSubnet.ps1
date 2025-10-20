<#
.SYNOPSIS
    Determines if one subnet is fully contained within another subnet.

.DESCRIPTION
    The Test-SubnetInSubnet function checks whether a given subnet (FirstSubnet) is completely contained within another subnet (SecondSubnet). 
    It validates both inputs are in CIDR notation and returns true if the first subnet is fully contained within the second subnet.

.PARAMETER FirstSubnet
    The subnet to check if it's contained within the SecondSubnet. Must be in CIDR notation (e.g. 192.168.1.0/24).

.PARAMETER SecondSubnet
    The potential containing subnet. Must be in CIDR notation (e.g. 192.168.0.0/16).

.EXAMPLE
    Test-SubnetInSubnet -FirstSubnet "192.168.1.0/24" -SecondSubnet "192.168.0.0/16"
    Returns: True (because 192.168.1.0/24 is contained within 192.168.0.0/16)

.EXAMPLE
    Test-SubnetInSubnet -FirstSubnet "10.0.0.0/8" -SecondSubnet "192.168.0.0/16"
    Returns: False (because 10.0.0.0/8 is not contained within 192.168.0.0/16)

.NOTES
    File Name      : Test-SubnetInSubnet.ps1
    Prerequisite   : PowerShell 5.1 or higher
    Copyright      : MIT License

.LINK
    https://github.com/imanedr/psnetworking

.OUTPUTS
    System.Boolean
    Returns True if FirstSubnet is contained within SecondSubnet, False otherwise.
#>

function Test-SubnetInSubnet {
    [CmdletBinding()]
    param (
        [ValidateScript({
            if ($_ -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}")
            {
                $true
            }
            else
            {
                throw "$_ is invalid. Use CIDR format for subnets or x.x.x.x-x.x.x.y for ranges."
            }
        })]
    [string]$FirstSubnet,

    [ValidateScript({
        if ($_ -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}")
        {
            $true
        }
        else
        {
            throw "$_ is invalid. Use CIDR format for subnets or x.x.x.x-x.x.x.y for ranges."
        }
    })]
[string]$SecondSubnet
    )
    
    $ipCalc = Get-IPCalc -CIDR $FirstSubnet
    $firstCheck = Test-IpInSubnet -IPv4Address $ipCalc.Subnet.IPAddressToString -SubnetOrRange $SecondSubnet
    $secondCheck = Test-IpInSubnet -IPv4Address $ipCalc.Broadcast.IPAddressToString -SubnetOrRange $SecondSubnet

    if ($firstCheck -and $secondCheck){
        Write-Output $true
    } else {
        Write-Output $false
    }
}