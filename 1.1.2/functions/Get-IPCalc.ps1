<#
.SYNOPSIS
    Advanced IP subnet calculator that provides detailed network information.

.DESCRIPTION
    IP Calculator for calculation IP Subnet. Provides comprehensive network information including binary representations, 
    subnet boundaries, and advanced subnet manipulation methods.

.PARAMETER CIDR
    Specifies the network in CIDR notation (e.g., "192.168.1.0/24")

.PARAMETER IPAddress
    Specifies the IP address to analyze

.PARAMETER Mask
    Specifies the subnet mask (e.g., "255.255.255.0")

.PARAMETER PrefixLength
    Specifies the network prefix length (0-32)

.PARAMETER WildCard
    Specifies the wildcard mask

.EXAMPLE
    Get-IPCalc -CIDR 192.168.0.0/24

    Shows complete subnet information including:
    IP           : 192.168.0.0
    Mask         : 255.255.255.0
    PrefixLength : 24
    WildCard     : 0.0.0.255
    IPcount      : 256
    Subnet       : 192.168.0.0
    Broadcast    : 192.168.0.255
    CIDR         : 192.168.0.0/24
    ToDecimal    : 3232235520
    IPBin        : 11000000.10101000.00000000.00000000
    MaskBin      : 11111111.11111111.11111111.00000000
    SubnetBin    : 11000000.10101000.00000000.00000000
    BroadcastBin : 11000000.10101000.00000000.11111111

.EXAMPLE
    Get-IPCalc -IPAddress 192.168.3.0 -PrefixLength 23

    Demonstrates calculation with IP address and prefix length, showing a larger subnet (512 IPs)

.EXAMPLE
    (Get-IPCalc 192.168.99.58/30).GetIPArray()
    
    Returns all IP addresses in the specified subnet:
    192.168.99.56
    192.168.99.57
    192.168.99.58
    192.168.99.59

.EXAMPLE
    (Get-IPCalc 192.168.99.56/28).Compare('192.168.99.50')
    
    Demonstrates the Compare method to check if an IP belongs to a subnet

.EXAMPLE
    (Get-IPCalc 192.168.0.0/25).Overlaps('192.168.0.0/27')
    
    Shows how to check for overlapping subnets

.NOTES
    Advanced Methods Available:
    - Add(): Add IP addresses within the subnet
    - Compare(): Compare IP addresses within the subnet
    - Overlaps(): Check for overlapping subnets
    - GetIParray(): Get all IP addresses in the range
    - isLocal(): Check if IP is on local network
    - GetLocalRoute(): Get routing information for specific IPs
#>


Function Get-IPCalc {
    
    [CmdletBinding(DefaultParameterSetName = 'CIDR')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'CIDR', ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateScript({ $Array = ($_ -split '\\|\/'); ($Array[0] -as [IPAddress]).AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork -and [string[]](0..32) -contains $Array[1] })]
        [Alias('DestinationPrefix')]
        [string]$CIDR,
        [parameter(ParameterSetName = 'Mask')][parameter(ParameterSetName = ('PrefixLength'), ValueFromPipelineByPropertyName = $true)][parameter(ParameterSetName = ('WildCard'))]
        [ValidateScript({ ($_ -as [IPAddress]).AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork })]
        [Alias('IP')]
        [IPAddress]$IPAddress,
        [Parameter(Mandatory = $true, ParameterSetName = 'Mask')]
        [IPAddress]$Mask,
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'PrefixLength')]
        [ValidateRange(0, 32)]
        [int]$PrefixLength,
        [parameter(Mandatory = $true, ParameterSetName = 'WildCard')]
        [IPAddress]$WildCard
    )

    if ($CIDR) {
        [IPAddress]$IPAddress = ($CIDR -split '\\|\/')[0]
        [int]$PrefixLength = ($CIDR -split '\\|\/')[1]
        [IPAddress]$Mask = [IPAddress]([string](4gb - ([System.Math]::Pow(2, (32 - $PrefixLength)))))
    }
    if ($PrefixLength -and !$Mask) {
        [IPAddress]$Mask = [IPAddress]([string](4gb - ([System.Math]::Pow(2, (32 - $PrefixLength)))))
    }
    if ($WildCard) {
        [IPAddress]$Mask = $WildCard.GetAddressBytes().ForEach({ 255 - $_ }) -join '.'
    }
    if (!$PrefixLength -and $Mask) {
        $PrefixLength = 32 - ($Mask.GetAddressBytes().ForEach({ [System.Math]::Log((256 - $_), 2) }) | Measure-Object -Sum).Sum
    }

    [int[]]$SplitIPAddress = $IPAddress.GetAddressBytes()
    [int64]$ToDecimal = $SplitIPAddress[0] * 16mb + $SplitIPAddress[1] * 64kb + $SplitIPAddress[2] * 256 + $SplitIPAddress[3]

    [int[]]$SplitMask = $Mask.GetAddressBytes()
    $IPBin = ($SplitIPAddress.ForEach({ [System.Convert]::ToString($_, 2).PadLeft(8, '0') })) -join '.'
    $MaskBin = ($SplitMask.ForEach({ [System.Convert]::ToString($_, 2).PadLeft(8, '0') })) -join '.'

    if ((($MaskBin -replace '\.').TrimStart('1').Contains('1')) -and (!$WildCard)) {
        Write-Warning 'Mask Length error, you can try put WildCard'; break
    }
    if (!$WildCard) {
        [IPAddress]$WildCard = $SplitMask.ForEach({ 255 - $_ }) -join '.'
    }
    if ($WildCard) {
        [int[]]$SplitWildCard = $WildCard.GetAddressBytes()
    }

    [IPAddress]$Subnet = $IPAddress.Address -band $Mask.Address
    [int[]]$SplitSubnet = $Subnet.GetAddressBytes()
    [string]$SubnetBin = $SplitSubnet.ForEach({ [System.Convert]::ToString($_, 2).PadLeft(8, '0') }) -join '.'
    [IPAddress]$Broadcast = @(0..3).ForEach({ [int]($SplitSubnet[$_]) + [int]($SplitWildCard[$_]) }) -join '.'
    [int[]]$SplitBroadcast = $Broadcast.GetAddressBytes()
    [string]$BroadcastBin = $SplitBroadcast.ForEach({ [System.Convert]::ToString($_, 2).PadLeft(8, '0') }) -join '.'
    [string]$CIDR = "$($Subnet.IPAddressToString)/$PrefixLength"
    [int64]$IPcount = [System.Math]::Pow(2, $(32 - $PrefixLength))

    $Object = [pscustomobject][ordered]@{
        IPAddress    = $IPAddress.IPAddressToString
        Mask         = $Mask.IPAddressToString
        PrefixLength = $PrefixLength
        WildCard     = $WildCard.IPAddressToString
        IPcount      = $IPcount
        Subnet       = $Subnet
        Broadcast    = $Broadcast
        CIDR         = $CIDR
        ToDecimal    = $ToDecimal
        IPBin        = $IPBin
        MaskBin      = $MaskBin
        SubnetBin    = $SubnetBin
        BroadcastBin = $BroadcastBin
        PSTypeName   = 'NetWork.IPCalcResult'
    }

    [string[]]$DefaultProperties = @('IPAddress', 'Mask', 'PrefixLength', 'WildCard', 'Subnet', 'Broadcast', 'CIDR', 'ToDecimal')

    Add-Member -InputObject $Object -MemberType AliasProperty -Name IP -Value IPAddress

    Add-Member -InputObject $Object -MemberType:ScriptMethod -Name Add -Value {
        param([int]$Add, [int]$PrefixLength = $This.PrefixLength)
        Get-IPCalc -IPAddress ([IPAddress]([String]$($This.ToDecimal + $Add))).IPAddressToString -PrefixLength $PrefixLength
    }

    Add-Member -InputObject $Object -MemberType:ScriptMethod -Name Compare -Value {
        param ([Parameter(Mandatory = $true)][IPAddress]$IP)
        $IPBin = -join (($IP)).GetAddressBytes().ForEach({ [System.Convert]::ToString($_, 2).PadLeft(8, '0') })
        $SubnetBin = $This.SubnetBin.Replace('.', '')
        for ($i = 0; $i -lt $This.PrefixLength; $i += 1) { if ($IPBin[$i] -ne $SubnetBin[$i]) { return $false } }
        return $true
    }

    Add-Member -InputObject $Object -MemberType:ScriptMethod -Name Overlaps -Value {
        param ([Parameter(Mandatory = $true)][string]$CIDR = $This.CIDR)
        $Calc = Get-IPCalc -Cidr $CIDR
        $This.Compare($Calc.Subnet) -or $This.Compare($Calc.Broadcast)
    }

    Add-Member -InputObject $Object -MemberType:ScriptMethod -Name GetIParray -Value {
        $w = @($This.Subnet.GetAddressBytes()[0]..$This.Broadcast.GetAddressBytes()[0])
        $x = @($This.Subnet.GetAddressBytes()[1]..$This.Broadcast.GetAddressBytes()[1])
        $y = @($This.Subnet.GetAddressBytes()[2]..$This.Broadcast.GetAddressBytes()[2])
        $z = @($This.Subnet.GetAddressBytes()[3]..$This.Broadcast.GetAddressBytes()[3])
        $w.ForEach({ $wi = $_; $x.ForEach({ $xi = $_; $y.ForEach({ $yi = $_; $z.ForEach({ $zi = $_; $wi, $xi, $yi, $zi -join '.' }) }) }) })
    }

    Add-Member -InputObject $Object -MemberType:ScriptMethod -Name isLocal -Value {
        param ([Parameter(Mandatory = $true)][IPAddress]$IP = $This.IPAddress)
        [bool](@(Get-NetIPAddress -AddressFamily IPv4 -AddressState Preferred).Where({ (Get-IPCalc -IPAddress $_.IPAddress -PrefixLength $_.PrefixLength).Compare($IP) }).Count)
    }

    Add-Member -InputObject $Object -MemberType:ScriptMethod -Name GetLocalRoute -Value {
        param ([Parameter(Mandatory = $true)][IPAddress]$IP = $This.IPAddress, [int]$Count = 1)
        @(Get-NetRoute -AddressFamily IPv4).Where({ (Get-IPCalc -CIDR $_.DestinationPrefix).Compare($IP) }) | Sort-Object -Property @{Expression = { (Get-IPCalc -CIDR $_.DestinationPrefix).PrefixLength } } -Descending | Select-Object -First $Count
    }

    Add-Member -InputObject $Object -MemberType:ScriptMethod -Force -Name ToString -Value {
        $This.CIDR
    }

    $PSPropertySet = New-Object -TypeName System.Management.Automation.PSPropertySet -ArgumentList @('DefaultDisplayPropertySet', $DefaultProperties)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]$PSPropertySet
    Add-Member -InputObject $Object -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers

    $Object
}

Function IsIpAddressInRange {
<#
.EXAMPLE
IsIpAddressInRange '192.168.1.10' '192.168.1.0-192.168.1.100'
True

#>
    param(
        [string] $ipAddress,
        [string] $Range
        
    )
    $arrRange = $Range.Split("-")
    [string] $fromAddress = $arrRange[0]
    [string] $toAddress = $arrRange[1]
    $ip = [system.net.ipaddress]::Parse($ipAddress).GetAddressBytes()
    [array]::Reverse($ip)
    $ip = [system.BitConverter]::ToUInt32($ip, 0)
     
    $from = [system.net.ipaddress]::Parse($fromAddress).GetAddressBytes()
    [array]::Reverse($from)
    $from = [system.BitConverter]::ToUInt32($from, 0)
     
    $to = [system.net.ipaddress]::Parse($toAddress).GetAddressBytes()
    [array]::Reverse($to)
    $to = [system.BitConverter]::ToUInt32($to, 0)
     
    $from -le $ip -and $ip -le $to
}