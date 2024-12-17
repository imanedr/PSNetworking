<#
.SYNOPSIS
    Tests connectivity to specified TCP ports on target hosts.

.DESCRIPTION
    This function allows you to test connectivity to TCP ports for a list of target hosts.
    You can specify a single port, a range of ports, or use a list of 100 or 1000 most common TCP ports.
    The function can receive target inputs and port numbers via the pipeline and can also use the clipboard
    for target input. Results can be sorted or filtered to show only open ports.

.PARAMETER Targets
    Target hosts (IP addresses or domain names) that need to be tested.
    This parameter can receive input from the pipeline.

.PARAMETER UseClipboardInput
    If specified, it uses clipboard contents as target input.

.PARAMETER PortNumber
    A single port number to test, validated to be in the range of 1 to 65535.

.PARAMETER PortRange
    A range of ports to test, specified in "startPort-endPort" format, validated to ensure range is correct.

.PARAMETER Timeout
    Timeout for connections, default is 1000 milliseconds.

.PARAMETER UseCommon100Ports
    If specified, test against the 100 most common TCP ports.

.PARAMETER UseCommon1000Ports
    If specified, test against the 1000 most common TCP ports.

.PARAMETER SortResults
    If specified, results will be sorted by IP address.

.PARAMETER MaxThreads
    Maximum number of concurrent threads.

.PARAMETER FilePath
    File path for the ports database. Defaults to a CSV file named `ports.csv` in the script's directory.

.EXAMPLE
    Test-TcpPorts -Targets '192.168.1.1' -PortNumber 80
    Tests connectivity on port 80 for the IP address 192.168.1.1.

.EXAMPLE
    '192.168.1.1', '192.168.1.2' | Test-TcpPorts -UseCommon100Ports
    Tests connectivity on the 100 most common TCP ports for the given IP addresses.

.EXAMPLE
    Test-TcpPorts -Targets '192.168.1.1/24' -PortRange '80-85' -OnlyShowOpenPorts -SortResults
    Tests connectivity on ports 80 to 85 within the given subnet, sorts the results, and shows only open ports.

.EXAMPLE
    Test-TcpPorts -UseClipboardInput -UseCommon1000Ports
    Uses clipboard contents as target IP addresses or hostnames and tests the most common 1000 TCP ports.

.NOTES
    Ensure the port description database CSV file exists at the specified file path.

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
        [switch]$ResolveDNS,
        [int]$MaxThreads = 100,
        [string]$filePath = "$PSScriptRoot\ports.csv"
    )

    # Validate input parameters and port configurations
    if (-not $PortNumber -and -not $PortRange -and -not $UseCommon100Ports -and -not $UseCommon1000Ports) {
        Write-Host -ForegroundColor Red "Please specify a port number or port range using the -PortNumber or -PortRange parameter."
        return
    }

    # Import and filter TCP ports database
    if (-Not (Test-Path -Path $filePath)) {
        Write-Host -ForegroundColor Red "port description database CSV file not found at path: $filePath"
        return $null
    }
    else {
        $portsDB = Import-Csv -Path $filePath
        # Filter only TCP protocol entries
        $portsDB = $portsDB | Where-Object { $_.Protocol -eq "tcp" }
    }

    # Determine which ports to test based on input parameters
    $portsToTest = if ($PortNumber) {
        $PortNumber
    }
    elseif ($PortRange) {
        # Convert port range string to array of ports
        $PortRange.Split('-')[0]..$PortRange.Split('-')[1]
    }
    elseif ($UseCommon100Ports) {
        # Get first 100 most common ports
        ($portsDB | Select-Object -First 100).port
    }
    elseif ($UseCommon1000Ports) {
        # Get first 1000 most common ports
        ($portsDB | Select-Object -First 1000).port
    }

    # Handle clipboard input if specified
    if ($UseClipboardInput) { 
        $Targets = Get-Clipboard 
    }

    # Process target inputs based on their type
    switch ($Targets.GetType().Name) {
        "String" {
            # Handle IP range format (e.g., 192.168.1.1-192.168.1.254)
            if ($Targets -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}-\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}") { 
                $Targets = Get-IpAddressesInRange -Range $Targets
            }
            # Handle CIDR notation (e.g., 192.168.1.0/24)
            elseif ($Targets -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/([1-2][0-9]|3[0-2]|[0-9])") {
                $Targets = Get-IPAddressesInSubnet -Subnet $Targets
            }
        }
        "Object[]" {
            # Filter valid IP addresses and hostnames
            $Targets = $Targets -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$|^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"
            # Sort IP addresses if requested and all targets are IPs
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

    # Resolve DNS names if requested
    if ($ResolveDNS) {
        for ($i = 0; $i -lt $Targets.Count; $i++) {
            if ($Targets[$i] -match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}") {
                $NameHost = (Resolve-DnsName $Targets[$i] -Type PTR -DnsOnly -ErrorAction SilentlyContinue).NameHost
                if ($NameHost) { 
                    if ($NameHost.Count -gt 1) { $ipList[$i] = $NameHost[0] } else { $Targets[$i] = $NameHost }
                }
            }
        }
    }

    # Initialize runspace pool for parallel processing
    $pool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $pool.Open()

    # Create array list for tracking runspaces
    $runspaces = New-Object System.Collections.ArrayList

    # Define the TCP port testing script block
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

    # Track progress variables
    $totalCount = $Targets.Count * $portsToTest.Count
    $completedCount = 0

    # Create and start runspaces for each target/port combination
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

    # Collect and process results
    $resultArray = New-Object System.Collections.ArrayList
    foreach ($runspace in $runspaces) {
        $result = $runspace.Pipe.EndInvoke($runspace.AsyncResult)
        $runspace.Pipe.Dispose()

        # Add results based on filter settings
        if ($result.Status -eq "Open") {
            $resultArray.Add(($result | Select-Object Hostname, @{Name = "Service"; Expression = { $portsDB | Where-Object { $_.port -eq $result.Port } | Select-Object -ExpandProperty Name } }, Port, Status)) | Out-Null
        }
    
        # Update progress bar
        $completedCount++
        $percent = ($completedCount / $totalCount) * 100
        Write-Progress -Activity "Testing TCP Ports" -Status "$completedCount out of $totalCount" -PercentComplete $percent
    }

    # Clean up resources
    $pool.Close()
    $pool.Dispose()
    if ($resultArray.Count -eq 0) {
        Write-Host -ForegroundColor Yellow "No open ports found."
    }
    else {
        return $resultArray
    }
}