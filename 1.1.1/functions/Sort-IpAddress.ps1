function Sort-IpAddress {
    <#
.Synopsis
This function takes an array of IP addresses and sorts them in ascending order based on their octets.

.DESCRIPTION
The Sort-IpAddress function sorts an array of IP addresses in ascending order based on their octets. The IP address list must be provided as an array of strings.

.PARAMETER IpAddressList
Specifies the array of IP addresses to be sorted.

.EXAMPLE
Sort-IpAddress -IpAddressList "192.168.0.1","192.168.0.10","192.168.0.2"
This example sorts an array of three IP addresses in ascending order and returns the sorted list.

.OUTPUTS
This function outputs a sorted list of IP addresses in ascending order.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$IpAddressList
    )
    process {
        $sortedIpAddresses = $IpAddressList | 
        ForEach-Object {
            $octets = $_ -split "\."
            [pscustomobject]@{
                ipadd = $_
                Key   = [int]$octets[0] * 0x1000000 -bxor [int]$octets[1] * 0x10000 -bxor [int]$octets[2] * 0x100 -bxor [int]$octets[3]
            }
        } | 
        Sort-Object Key | Select-Object -ExpandProperty ipadd
    }
    end {
        return $sortedIpAddresses 
    }
}
