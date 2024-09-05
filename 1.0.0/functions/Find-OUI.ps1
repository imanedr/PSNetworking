<#
.SYNOPSIS
    Converts a MAC address to OUI format.

.DESCRIPTION
    This function takes a MAC address in any format (e.g., colons, dashes, or no separators) and converts it to a standardized OUI format.

.PARAMETER macAddress
    The MAC address to be converted to OUI format.

.EXAMPLE
    PS> Convert-MacAddressToOUI -macAddress "A8-C6-47-12-34-56"
    A8-C6-47

.EXAMPLE
    PS> Convert-MacAddressToOUI -macAddress "A8C647123456"
    A8-C6-47

.EXAMPLE
    PS> Convert-MacAddressToOUI -macAddress "A8:C6:47:12:34:56"
    A8-C6-47

#>
function Convert-MacAddressToOUI {
    param (
        [Parameter(Mandatory=$true)]
        [string]$macAddress
    )
    
    # Remove any non-hexadecimal characters
    $macAddress = $macAddress -replace '[^0-9A-Fa-f]', ''
    
    # Ensure the MAC Address is at least 6 hexadecimal characters long
    if ($macAddress.Length -lt 6) {
        throw "Invalid MAC address format"
    }
    
    # Grab the first 6 hexadecimal characters and format them into OUI
    $oui = $macAddress.Substring(0, 6) -replace "(.{2})(.{2})(.{2})", '$1-$2-$3'
    
    return $oui.ToUpper()  # Ensure it is in uppercase format
}


<#
.SYNOPSIS
    Finds the OUI and company name for a given MAC address from a CSV file.

.DESCRIPTION
    This function reads a CSV file where each line contains an OUI and a company name, 
    and finds the corresponding company name for a given MAC address.

.PARAMETER macAddress
    The MAC address to find the corresponding OUI and company name for.

.PARAMETER filePath
    The path to the CSV file containing OUI and company name mappings. Defaults to "OUI.csv" in the same directory as the script.

.EXAMPLE
    PS> Find-OUI -macAddress "A8-C6-47-12-34-56" -filePath "OUI.csv"
    MACAddress OUI      Company
    ---------- ---      -------
    A8-C6-47-12-34-56 A8-C6-47 Extreme Networks Headquarters

.NOTES
    The CSV file should have the following format:
    OUI,Company
    10-E9-92,INGRAM MICRO SERVICES
    78-F2-76,Cyklop Fastjet Technologies (Shanghai) Inc.
    ...

#>
function Find-OUI {
    param (
        [Parameter(Mandatory=$true)]
        [string]$macAddress,
        [string]$filePath = "$PSScriptRoot\OUI.csv"  # Default to the same directory as the script
    )
    
    # Check if the file exists
    if (-Not (Test-Path -Path $filePath)) {
        Write-Host "CSV file not found at path: $filePath"
        return $null
    }
    
    # Convert the MAC address to OUI format
    $oui = Convert-MacAddressToOUI -macAddress $macAddress
    
    # Use Select-String to search for the OUI in the file
    $pattern = "^$oui,"
    $match = Select-String -Path $filePath -Pattern $pattern -CaseSensitive
    
    # Process the matching line if found
    if ($match) {
        $line = $match.Line
        $splitLine = $line -split ','

        return [PSCustomObject]@{
            MACAddress = $macAddress
            OUI = $splitLine[0]
            Company = $splitLine[1]
        }
    } else {
        Write-Host "OUI not found for MAC address: $macAddress"
        return $null
    }
}

