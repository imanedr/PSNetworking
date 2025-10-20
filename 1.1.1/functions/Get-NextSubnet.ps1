<#
.SYNOPSIS
    Calculates the next available subnet based on a given CIDR notation.

.DESCRIPTION
    The Get-NextSubnet function takes a subnet in CIDR notation and calculates the next available subnet
    with either the same prefix length or a specified one. It handles IPv4 addresses and ensures proper
    subnet boundary calculations.

.PARAMETER CIDR
    Specifies the current subnet in CIDR notation (e.g., "192.168.1.0/24").
    Must be a valid IPv4 CIDR notation.

.PARAMETER prefixLength
    Specifies the prefix length for the next subnet. Must be between 1 and 32.
    If not specified, uses the same prefix length as the input CIDR.

.EXAMPLE
    Get-NextSubnet -CIDR "192.168.1.0/24"
    Returns: "192.168.2.0/24"

.EXAMPLE
    Get-NextSubnet -CIDR "192.168.1.0/24" -prefixLength 23
    Returns: "192.168.3.0/23"

.NOTES
    Author: PSNetworking
    Version: 1.1.0
    Requires: get-ipcalc function

.OUTPUTS
    System.String
    Returns the next subnet in CIDR notation
#>
Function Get-NextSubnet {
    param (
        [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}/[1-9][0-9]?$')]
        [string]$CIDR,
        [ValidateRange(1, 32)]
        [int]$prefixLength
    )
    try {
        # Get details of the current subnet
        $subnetDetails = get-ipcalc $cidr | Select-Object *
   
        if (-not $prefixLength) {
            $prefixLength = $subnetDetails.PrefixLength
        }
        elseif ($prefixLength -lt $subnetDetails.PrefixLength) {
            $subnetDetails = get-ipcalc -IPAddress $subnetDetails.IPAddress -PrefixLength $prefixLength
        }

        # Retrieve necessary data
        $currentBaseDecimal = $subnetDetails.ToDecimal
        $ipCount = $subnetDetails.IPcount

        # Calculate the next subnet's base IP in decimal
        $nextBaseDecimal = $currentBaseDecimal + $ipCount
        # Function to convert decimal back to dotted decimal format
        function ConvertToDottedDecimal($decimal) {
            $octet1 = [math]::Floor($decimal / 16777216)
            $octet2 = [math]::Floor(($decimal % 16777216) / 65536)
            $octet3 = [math]::Floor(($decimal % 65536) / 256)
            $octet4 = $decimal % 256
            return "$octet1.$octet2.$octet3.$octet4"
        }
        # Convert the next base IP to dotted decimal
        $nextBaseIP = ConvertToDottedDecimal $nextBaseDecimal
        # Return the next subnet in CIDR notation
        return "$nextBaseIP/$prefixLength"
    }
    catch {
       Write-Error "Failed to calculate next subnet: $_"
    }
   
}