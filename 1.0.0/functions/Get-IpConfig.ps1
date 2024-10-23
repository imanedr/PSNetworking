function Get-IpConfig
<#
.SYNOPSIS
Gets the IP configuration for network interfaces on the local system.

.DESCRIPTION
The Get-IpConfig function retrieves the IP configuration for network interfaces on the local system. It can optionally show all interfaces, including virtual interfaces, or only show active physical interfaces.

.PARAMETER ShowAll
If specified, the function will return IP configuration for all network interfaces, including virtual interfaces. If not specified, the function will only return IP configuration for active physical interfaces.

.EXAMPLE
Get-IpConfig
Returns IP configuration for active physical network interfaces.

.EXAMPLE
Get-IpConfig -ShowAll
Returns IP configuration for all network interfaces, including virtual interfaces.

.OUTPUTS
System.Management.Automation.PSCustomObject
The function returns a custom object with the following properties:
- Interface: The name of the network interface
- IPAddress: The IPv4 address and prefix length of the interface
- Gateway: The IPv4 default gateway for the interface
- MacAddress: The MAC address of the interface
- DNSServers: The IP addresses of the DNS servers for the interface
#>
{
   
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]
        $ShowAll
    )
    $ipConfig = Get-NetIPConfiguration
    
    if (-not $ShowAll)
    {
        $ipConfig = $ipConfig | Where-Object { ($_.NetAdapter.Status -eq "Up") -and ($_.InterfaceDescription -notlike "*Virtual*") }
        foreach ($ip in $ipConfig)
        {
            [pscustomobject]@{
                Interface = $ip.InterfaceAlias
                IPAddress = $ip.IPv4Address.IPAddress + "/" + $ip.IPv4Address.PrefixLength
                Gateway = $ip.IPv4DefaultGateway.NextHop
                MacAddress = ($ip.NetAdapter.macAddress -replace "-", ":").ToLower()
                DNSServers = $ip.DNSServer.ServerAddresses
            }
        }
    }else {
        foreach ($ip in $ipConfig)
        {
            [pscustomobject]@{
                Interface = $ip.InterfaceAlias
                IPAddress = $ip.IPv4Address.IPAddress + "/" + $ip.IPv4Address.PrefixLength
                Gateway = $ip.IPv4DefaultGateway.NextHop
                MacAddress = ($ip.NetAdapter.macAddress -replace "-", ":").ToLower()
                DNSServers = $ip.DNSServer.ServerAddresses
            }
        }
    }
}