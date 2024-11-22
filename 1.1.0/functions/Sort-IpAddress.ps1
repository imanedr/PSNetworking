function Sort-IpAddress
{
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
    process
    {
        $sortedIpAddresses = $IpAddressList | ForEach-Object {
            [System.Net.IPAddress]::Parse($_) | Select-Object @{
                Name = 'Octet1'; Expression = { $_.GetAddressBytes()[0] }
            }, @{
                Name = 'Octet2'; Expression = { $_.GetAddressBytes()[1] }
            }, @{
                Name = 'Octet3'; Expression = { $_.GetAddressBytes()[2] }
            }, @{
                Name = 'Octet4'; Expression = { $_.GetAddressBytes()[3] }
            }, @{
                Name = 'IPAddress'; Expression = { $_ }
            }
        } | Sort-Object Octet1, Octet2, Octet3, Octet4 | Select-Object IPAddress
    }
    end
    {
        return ($sortedIpAddresses | ForEach-Object {$_.IPAddress.IPAddressToString})
    }
}
