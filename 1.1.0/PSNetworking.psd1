#
# Module manifest for module 'PSNetworking'
#
# Generated by: Iman Edrisian
#
# Generated on: 2022-09-29
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSNetworking.psm1'

# Version number of this module.
ModuleVersion = '1.1.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = 'a163e3fa-e224-4616-a76b-a123140ecacb'

# Author of this module
Author = 'Iman Edrisian'

# Company or vendor of this module
CompanyName = 'Unknown'

# Copyright statement for this module
Copyright = '(c) 2024 Iman Edrisian. All rights reserved.'

# Description of the functionality provided by this module
Description = 'PSNetworking is a PowerShell module that provides a comprehensive collection of networking utilities designed to simplify network administration tasks. The module delivers essential tools across key areas:

- **IP Address Management**: Subnet calculations, IP validation, and range operations
- **Network Diagnostics**: Advanced ping utilities and parallel network testing
- **Network Information**: Interface configuration and public IP monitoring
- **MAC Address Operations**: Format conversion and vendor identification

Perfect for network administrators, system engineers, and IT professionals, this module streamlines network operations with powerful automation capabilities and enhanced network visibility. Built for performance and ease of use.'

# Minimum version of the Windows PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Convert-IpListToSubnets',
'Convert-MacAddressFormat',
'Find-OUI',
'Get-BandwidthUsage',
'Get-IPAddressesInSubnet',
'Get-IPCalc',
'Get-IpAddressesInRange',
'Get-IpConfig',
'Get-PublicIP',
'Ping-Ip',
'Ping-IpList',
'Sort-IpAddress',
'Test-IpInSubnet',
'Test-SubnetInSubnet',
'Test-TcpPorts'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = ''

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/imanedr/PSNetworking'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

