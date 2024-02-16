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