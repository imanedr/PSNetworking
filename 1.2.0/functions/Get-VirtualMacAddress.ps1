<#
.SYNOPSIS
    Generates a virtual MAC address based on an IP address.

.DESCRIPTION
    The Get-VirtualMacAddress function creates a virtual MAC address using a fixed prefix (02:00:00)
    commonly used for virtual machines, combined with the last three octets of the provided IP address.

.PARAMETER IPAddress
    Specifies the IP address to use as the basis for generating the virtual MAC address.
    The IP address must be in valid IPv4 format (e.g., 192.168.1.100).

.EXAMPLE
    Get-VirtualMacAddress -IPAddress "192.168.1.100"
    Returns: 02:00:00:A8:01:64

.EXAMPLE
    "10.0.0.50" | Get-VirtualMacAddress
    Returns: 02:00:00:00:00:32

.INPUTS
    System.String
    You can pipe a string containing an IP address to Get-VirtualMacAddress.

.OUTPUTS
    System.String
    Returns a MAC address in the format "XX:XX:XX:XX:XX:XX".

.NOTES
    Author: PSNetworking Module
    Version: 1.1.0
    The function uses a fixed prefix of 02:00:00 which is commonly associated with virtual network interfaces.

.LINK
    https://github.com/imanedr/PSNetworking
#>
function Get-VirtualMacAddress {
    param (
        [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
        [string]$IPAddress
    )

    # Validate the IP address
    if (-not [System.Net.IPAddress]::TryParse($IPAddress, [ref]$null)) {
        throw "Invalid IP address format."
    }
    
    # Split the IP address into octets
    $octets = $IPAddress -split '\.'

    # Generate the virtual MAC address using a fixed prefix (e.g., 02:00:00) common for virtual machines
    $macAddress = "02:00:00:{0:X2}:{1:X2}:{2:X2}" -f [int]$octets[1], [int]$octets[2], [int]$octets[3]

    return $macAddress
}
