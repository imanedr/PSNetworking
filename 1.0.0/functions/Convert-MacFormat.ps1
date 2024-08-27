<#
.SYNOPSIS
    Converts a MAC address between Cisco and Regular formats.

.DESCRIPTION
    This script allows you to convert MAC addresses between the Cisco and Regular formats. 
    A Cisco MAC address is in the format "abcd.ef12.3456", while a Regular MAC address 
    is in the format "ab:cd:ef:12:34:56". If no MAC address is provided as input, the script 
    fetches the MAC address from the clipboard content, making it convenient to use on-the-go.

.PARAMETER InputMacAddress
    The MAC address to be converted. If not provided, the script checks the clipboard.

.PARAMETER TargetFormat
    The desired output format ('Cisco' or 'Regular'). If omitted, the function will convert to the opposite format 
    based on the current format of the input.

.EXAMPLE
    Convert-MacAddressFormat -InputMacAddress "ab:cd:ef:12:34:56" -TargetFormat "Cisco"

    This example converts a Regular formatted MAC address to Cisco format.
    
.EXAMPLE
    Convert-MacAddressFormat -InputMacAddress "abcd.ef12.3456"

    This example converts a Cisco formatted MAC address to Regular format.
    
.EXAMPLE
    Set-Clipboard "ab:cd:ef:12:34:56"
    Convert-MacAddressFormat

    This example converts a Regular formatted MAC address to Cisco format by using the clipboard content.

.NOTES
    Author: Your Name
    Date: October 2023
#>

function Convert-MacAddressFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$InputMacAddress,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Cisco','Regular')]
        [string]$TargetFormat
    )

    function Detect-MacAddressFormat {
        param(
            [Parameter(Mandatory=$true)]
            [string]$MacAddress
        )

        $regexCisco = '^([0-9a-fA-F]{4}\.){2}[0-9a-fA-F]{4}$'
        $regexRegular = '^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$'

        if ($MacAddress -match $regexCisco) {
            return 'Cisco'
        } elseif ($MacAddress -match $regexRegular) {
            return 'Regular'
        } else {
            return $null
        }
    }

    # If no MAC address is specified, get it from the clipboard
    if (-not $InputMacAddress) {
        try {
            $clipboardContent = Get-Clipboard
        }
        catch {
            Write-Error "Error accessing clipboard: $_"
            return
        }
        
        # Split the clipboard content by line
        $macAddresses = $clipboardContent -split "`r?`n"
        
        foreach ($macAddress in $macAddresses) {
            $macAddress = $macAddress.Trim()

            # If the line is empty, skip it
            if (-not [string]::IsNullOrWhiteSpace($macAddress)) {
                $currentFormat = Detect-MacAddressFormat -MacAddress $macAddress
                if ($currentFormat) {
                    if (-not $TargetFormat) {
                        $TargetFormat = if ($currentFormat -eq 'Cisco') { 'Regular' } else { 'Cisco' }
                    }

                    $convertedAddress = Convert-MacAddressFormat -InputMacAddress $macAddress -TargetFormat $TargetFormat
                    Write-Host $convertedAddress
                }
                else {
                    Write-Host "Invalid MAC address: $macAddress"
                }
            }
        }
        return
    }

    # Determine input type if not explicitly specified
    if (-not $TargetFormat) {
        $currentFormat = Detect-MacAddressFormat -MacAddress $InputMacAddress

        if (-not $currentFormat) {
            Write-Error "Invalid MAC address format"
            return $null
        }

        $TargetFormat = if ($currentFormat -eq 'Cisco') { 'Regular' } else { 'Cisco' }
    }

    switch ($TargetFormat) {
        'Cisco' {
            $ConvertedMac = ($InputMacAddress -replace ':', '').ToLower() -replace '(\w{4})(\w{4})(\w{4})', '$1.$2.$3'
        }
        'Regular' {
            $ConvertedMac = ($InputMacAddress -replace '\.', '').ToLower() -replace '(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})(\w{2})', '$1:$2:$3:$4:$5:$6'
        }
        default {
            Write-Error "Unknown TargetFormat specified."
            return $null
        }
    }

    return $ConvertedMac
}