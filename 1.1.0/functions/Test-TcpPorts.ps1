<#
.SYNOPSIS
    Determines if one subnet is fully contained within another subnet.

.DESCRIPTION
    The Test-SubnetInSubnet function checks whether a given subnet (FirstSubnet) is completely contained within another subnet (SecondSubnet). 
    It validates both inputs are in CIDR notation and returns true if the first subnet is fully contained within the second subnet.

.PARAMETER FirstSubnet
    The subnet to check if it's contained within the SecondSubnet. Must be in CIDR notation (e.g. 192.168.1.0/24).

.PARAMETER SecondSubnet
    The potential containing subnet. Must be in CIDR notation (e.g. 192.168.0.0/16).

.EXAMPLE
    Test-SubnetInSubnet -FirstSubnet "192.168.1.0/24" -SecondSubnet "192.168.0.0/16"
    Returns: True (because 192.168.1.0/24 is contained within 192.168.0.0/16)

.EXAMPLE
    Test-SubnetInSubnet -FirstSubnet "10.0.0.0/8" -SecondSubnet "192.168.0.0/16"
    Returns: False (because 10.0.0.0/8 is not contained within 192.168.0.0/16)

.NOTES
    File Name      : Test-SubnetInSubnet.ps1
    Prerequisite   : PowerShell 5.1 or higher
    Copyright      : MIT License

.LINK
    https://github.com/imanedr/psnetworking

.OUTPUTS
    System.Boolean
    Returns True if FirstSubnet is contained within SecondSubnet, False otherwise.
#>
function Test-TcpPorts {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $Targets,

        [switch]$UseClipboardInput,

        [Parameter(ValueFromPipeline)]
        [ValidateRange(1, 65535)]
        [int]$PortNumber,

        [ValidateScript({
                if ($_ -match '^(?:[1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])-(?:[1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$') {
                    $parts = $_ -split '-'
                    $startPort = [int]$parts[0]
                    $endPort = [int]$parts[1]

                    if ($startPort -le $endPort) {
                        $true
                    }
                    else {
                        throw "Invalid port range. Start port must be less than or equal to end port."
                    }
                }
                else {
                    throw "Invalid input format. Please use the format 'startPort-endPort'."
                }
            })]
        $PortRange,

        [int]$timeout = 1000,
        [switch]$UseCommon100Ports,
        [switch]$UseCommon1000Ports,
        [switch]$SortResults,
        [switch]$OnlyShowOpenPorts,
        [int]$MaxThreads = 100,
        [string]$filePath = "$PSScriptRoot\ports.csv"
    )

    if (-not $PortNumber -and -not $PortRange -and -not $UseCommon100Ports -and -not $UseCommon1000Ports) {
        Write-Host -ForegroundColor Red "Please specify a port number or port range using the -PortNumber or -PortRange parameter."
        return
    }

    if (-Not (Test-Path -Path $filePath)) {
        Write-Host -ForegroundColor Red "port description database CSV file not found at path: $filePath"
        return $null
    }
    else {
        $portsDB = Import-Csv -Path $filePath
        $portsDB = $portsDB | Where-Object { $_.Protocol -eq "tcp" }
    }

    $portsToTest = if ($PortNumber) {
        $PortNumber
    }
    elseif ($PortRange) {
        $PortRange.Split('-')[0]..$PortRange.Split('-')[1]
    }
    elseif ($UseCommon100Ports) {
        ($portsDB | Select-Object -First 100).port
    }
    elseif ($UseCommon1000Ports) {
        ($portsDB | Select-Object -First 1000).port
    }
    
    if ($UseClipboardInput) { 
        $Targets = Get-Clipboard 
    }

    switch ($Targets.GetType().Name) {
        "String" {
            if ($Targets -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}-\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}") { 
                $Targets = Get-IpAddressesInRange -Range $Targets
            }
            elseif ($Targets -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/([1-2][0-9]|3[0-2]|[0-9])") {
                $Targets = Get-IPAddressesInSubnet -Subnet $Targets
            }
        }
        "Object[]" {
            $Targets = $Targets -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$|^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"
            if ($SortResults -and ($Targets -notmatch "^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$").Count -eq $Targets.Count) {
                $Targets = Sort-IpAddress $Targets
            }
            elseif ($SortResults) {
                Write-Host -ForegroundColor Yellow "A mixed list of IP addresses and hostnames cannot be sorted!"
            }
        }
        Default {
            Throw "The [$Targets] is Invalid IPv4Address"
        }
    }

    $pool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $pool.Open()

    $runspaces = New-Object System.Collections.ArrayList

    $scriptBlock = {
        param($hostname, $port, $timeout)

        function Test-TcpPortHelper {
            param (
                $hostname,
                $port,
                $timeout = 1000
            )

            $objResult = [PSCustomObject]@{
                Hostname = $hostname
                Port     = $port
                Status   = "Unknown"
            }
            try {
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $asyncResult = $tcpClient.BeginConnect($hostname, $port, $null, $null)
                $success = $asyncResult.AsyncWaitHandle.WaitOne($timeout, $false)

                if ($success) {
                    $objResult.Status = "Open"
                }
                else {
                    $objResult.Status = "Closed"
                }

                $tcpClient.Close()
                $tcpClient.Dispose()
                Return $objResult
            }
            catch {
                Write-Output "Error: Port $port is closed on $hostname."
            }
        }

        Return Test-TcpPortHelper -hostname $hostname -port $port -timeout $timeout
    }

    $totalCount = $Targets.Count * $portsToTest.Count
    $completedCount = 0
    
    foreach ($hostname in $Targets) {
        foreach ($port in $portsToTest) {
            $powershell = [powershell]::Create().AddScript($scriptBlock).AddArgument($hostname).AddArgument($port).AddArgument($timeout)
            $powershell.RunspacePool = $pool
            $runspaces.Add([PSCustomObject]@{
                    Pipe        = $powershell
                    AsyncResult = $powershell.BeginInvoke()
                }) | Out-Null
        }
    }

    $resultArray = New-Object System.Collections.ArrayList
    foreach ($runspace in $runspaces) {
  
        $result = $runspace.Pipe.EndInvoke($runspace.AsyncResult)
        $runspace.Pipe.Dispose()

        if ($OnlyShowOpenPorts) {
            if ($result.Status -eq "Open") {
                $resultArray.Add(($result | Select-Object Hostname, @{Name = "Service"; Expression = { $portsDB | Where-Object { $_.port -eq $result.Port } | Select-Object -ExpandProperty Name } }, Port, Status)) | Out-Null
            }
        }
        else {
            $resultArray.Add(($result | Select-Object Hostname, @{Name = "Service"; Expression = { $portsDB | Where-Object { $_.port -eq $result.Port } | Select-Object -ExpandProperty Name } }, Port, Status)) | Out-Null
        }
        $completedCount++
        $percent = ($completedCount / $totalCount) * 100
        Write-Progress -Activity "Testing TCP Ports" -Status "$completedCount out of $totalCount"  -PercentComplete  $percent
    }

    $pool.Close()
    $pool.Dispose()
    return $resultArray
}