<#
.SYNOPSIS
Gets the IP configuration for network interfaces on the local system.

.DESCRIPTION
The Get-IpConfig function retrieves detailed IP configuration information for network interfaces on the local system. It provides essential network details including IP addresses, gateways, MAC addresses, and DNS servers. By default, it shows only active physical interfaces, but can display all interfaces when needed.

.PARAMETER ShowAll
[Optional] Switch parameter that displays all network interfaces including virtual ones when specified. Default behavior shows only active physical interfaces.

.EXAMPLE
Get-IpConfig
# Returns IP configuration for active physical network interfaces only

.EXAMPLE
Get-IpConfig -ShowAll
# Returns IP configuration for all network interfaces, including virtual ones

.OUTPUTS
System.Management.Automation.PSCustomObject with properties:
- Interface: Network interface name
- IPAddress: IPv4 address with prefix length
- Gateway: IPv4 default gateway
- MacAddress: MAC address (lowercase, colon-separated)
- DNSServers: DNS server IP addresses

.NOTES
Requires PowerShell 5.1 or higher
Administrator rights may be required for some network operations

.LINK
https://github.com/imanedr/psnetworking
#>

function Get-IpConfig
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