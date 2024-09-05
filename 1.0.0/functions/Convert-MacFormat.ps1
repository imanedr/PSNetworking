<#
.SYNOPSIS
    Converts MAC addresses between Cisco format (xxxx.xxxx.xxxx) and regular format (xx:xx:xx:xx:xx:xx or xx-xx-xx-xx-xx-xx).

.DESCRIPTION
    The Convert-MacAddressFormat function accepts either a single MAC address or a list of MAC addresses and converts them from one format to another automatically.
    It can detect Cisco format (xxxx.xxxx.xxxx) and convert it to regular format (xx:xx:xx:xx:xx:xx or xx-xx-xx-xx-xx-xx) and vice versa.

.PARAMETER InputMacAddress
    A single MAC address or a list of MAC addresses to be converted.
    Accepts both individual MAC addresses and lists of MAC addresses as input.

.PARAMETER GetMacFromClipboard
    When this switch is provided, the function will retrieve MAC addresses from the clipboard instead of the InputMacAddress parameter.

.EXAMPLE
    Convert-MacAddressFormat -InputMacAddress "1234.5678.9abc"
    Converts a Cisco formatted MAC address to regular format and outputs "12:34:56:78:9a:bc".

.EXAMPLE
    Convert-MacAddressFormat -InputMacAddress "00:1A:2B:3C:4D:5E"
    Converts a regular formatted MAC address to Cisco format and outputs "001a.2b3c.4d5e".

.EXAMPLE
    $macAddresses = @("1234.5678.9abc", "00:1A:2B:3C:4D:5E")
    Convert-MacAddressFormat -InputMacAddress $macAddresses
    Converts a list of MAC addresses and outputs both in their converted formats.

.EXAMPLE
    Convert-MacAddressFormat -GetMacFromClipboard
    Retrieves a MAC address or list of MAC addresses from the clipboard, converts them to the alternate format, and outputs the result.

.INPUTS
    [String[]] 
    A single MAC address or an array of MAC addresses.

.OUTPUTS
    [String] 
    The formatted MAC address in the alternate format.

.NOTES
    Author: Your Name
    Date:   2023-09-04
#>
function Convert-MacAddressFormat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
        [Alias("MAC")]
        [String[]]$InputMacAddress,

        [Parameter(Mandatory = $false)]
        [switch]$GetMacFromClipboard
    )

    process {
        if ($GetMacFromClipboard) {
            $InputMacAddress = Get-Clipboard
        }
        
        foreach ($macAddress in $InputMacAddress) {
            if ($macAddress -match '^([0-9a-fA-F]{4}\.){2}[0-9a-fA-F]{4}$') {
                # Cisco format xxxx.xxxx.xxxx to xx:xx:xx:xx:xx:xx
                $normalizedMac = $macAddress -replace '\.', ''
                $formattedMac = ($normalizedMac -split '(?<=\G..)(?!$)') -join ':'
                Write-Output $formattedMac
            } elseif ($macAddress -match '^([0-9a-f]{2}(:|-)){5}[0-9a-f]{2}$') {
                # Regular format xx:xx:xx:xx:xx:xx or xx-xx-xx-xx-xx-xx to Cisco format xxxx.xxxx.xxxx
                $cleanedMac = $macAddress -replace '[:|-]', ''
                $formattedMac = $cleanedMac -replace '(.{4})(.{4})(.{4})', '$1.$2.$3'
                Write-Output $formattedMac
            } else {
                Write-Error "Invalid MAC address format: $macAddress"
            }
        }
    }
}