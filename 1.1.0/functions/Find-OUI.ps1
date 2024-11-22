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
function Convert-MacAddressToOUI
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$macAddress
    )
    
    # Remove any non-hexadecimal characters
    $macAddress = $macAddress -replace '[^0-9A-Fa-f]', ''
    
    # Ensure the MAC Address is at least 6 hexadecimal characters long
    if ($macAddress.Length -lt 6)
    {
        throw "Invalid MAC address format"
    }
    
    # Grab the first 6 hexadecimal characters and format them into OUI
    $oui = $macAddress.Substring(0, 6) -replace "(.{2})(.{2})(.{2})", '$1-$2-$3'
    
    return $oui.ToUpper()  # Ensure it is in uppercase format
}


<#
.SYNOPSIS
    Identifies vendor information from MAC addresses using OUI lookup.

.DESCRIPTION
    The Find-OUI function takes MAC addresses and identifies the vendor/manufacturer by looking up the OUI (Organizationally Unique Identifier) in a CSV database. It supports single or multiple MAC addresses, pipeline input, and can read directly from clipboard.

.PARAMETER macAddress
    One or more MAC addresses to lookup. Accepts various formats:
    - With dashes (00-11-22-33-44-55)
    - With colons (00:11:22:33:44:55)
    - Without separators (001122334455)

.PARAMETER GetMacFromClipboard
    Switch parameter to read MAC address directly from clipboard instead of providing it as parameter.

.PARAMETER filePath
    Path to the OUI database CSV file. Defaults to OUI.csv in the script's directory.

.EXAMPLE
    Find-OUI -macAddress "A8-C6-47-12-34-56"
    Looks up vendor information for a single MAC address

.EXAMPLE
    "00:11:22:33:44:55", "AA:BB:CC:DD:EE:FF" | Find-OUI
    Looks up vendor information for multiple MAC addresses via pipeline

.EXAMPLE
    Find-OUI -GetMacFromClipboard
    Reads MAC address from clipboard and performs lookup

.OUTPUTS
    PSCustomObject with properties:
    - MACAddress: The input MAC address
    - OUI: The extracted OUI
    - Company: The vendor/manufacturer name

.NOTES
    Requires:
    - OUI.csv database file in the specified path
    - Read access to the CSV file
    
.LINK
    https://github.com/imanedr/psnetworking
#>

function Find-OUI
{
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
        [Alias("MAC")]
        [String[]]$macAddress,
        [switch]$GetMacFromClipboard,
        [string]$filePath = "$PSScriptRoot\OUI.csv"  # Default to the same directory as the script
    )
    
    # Check if the file exists
    if (-Not (Test-Path -Path $filePath))
    {
        Write-Host "CSV file not found at path: $filePath"
        return $null
    }
    
    # If Get-MacFromClipboard is specified, get the MAC address from the clipboard
    if ($GetMacFromClipboard)
    {
        $macAddress = Get-Clipboard 
    }
    
    # Convert the MAC addresses to uppercase

    foreach ($mac in $macAddress)
    {
        # Convert the MAC address to OUI format
        if ($mac)
        {
            $oui = Convert-MacAddressToOUI -macAddress $mac
        
            # Use Select-String to search for the OUI in the file
            $pattern = "^$oui,"
            $match = Select-String -Path $filePath -Pattern $pattern -CaseSensitive
    
            # Process the matching line if found
            if ($match)
            {
                $line = $match.Line
                $splitLine = $line -split ','

                Write-Output ([PSCustomObject]@{
                        MACAddress = $mac
                        OUI        = $splitLine[0]
                        Company    = $splitLine[1]
                    })
            }
            else
            {
                Write-Output "OUI not found for MAC address: $macAddress"
            }
        }
    }
}

