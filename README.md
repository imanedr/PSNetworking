# PSNetworking PowerShell Module

A comprehensive PowerShell networking toolkit for network administrators and IT professionals.

## 🚀 Overview

PSNetworking is a feature-rich PowerShell module that provides an extensive collection of networking utilities designed to simplify and automate network administration tasks. The module delivers powerful tools across all essential networking domains:

- **IP Address Management**: Advanced subnet calculations, IP validation, range operations, and CIDR manipulation
- **Network Diagnostics**: Parallel ping utilities with history tracking, TCP port scanning, and downtime monitoring
- **Network Monitoring**: Real-time bandwidth usage, public IP tracking, and interface configuration
- **MAC Address Operations**: Format conversion, vendor identification via OUI lookup
- **Advanced Utilities**: Subnet containment testing, virtual MAC generation, and syslog messaging

Perfect for network administrators, system engineers, DevOps professionals, and IT specialists who need reliable automation tools and enhanced network visibility.

## 📦 Installation

For optimal performance, use **PowerShell 7** or later. Get the latest version here:
[Install PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)

```powershell
# Install from PowerShell Gallery
Install-Module -Name PSNetworking -Scope CurrentUser

# Import the module
Import-Module PSNetworking

# View available commands
Get-Command -Module PSNetworking
```

## 🛠 Function Reference

### IP Address Management

#### Convert-IpListToSubnets
Converts a list of IP addresses into the most efficient subnet representations using CIDR notation.

**Parameters:**
- `IPAddressList` - Array of IP addresses to convert
- `NotUseCIDRfor32` - Outputs single IPs without /32 notation

**Example:**
```powershell
PS> Convert-IpListToSubnets -IPAddressList @("192.168.1.1", "192.168.1.2", "192.168.1.3", "192.168.1.0","192.168.1.4")
192.168.1.0/30
192.168.1.4/32
```

**Use Cases:**
- Consolidating IP addresses into efficient subnet ranges
- Network documentation and IP address management
- Firewall rule optimization

---

#### Get-IPCalc
Advanced IP subnet calculator providing comprehensive network information including binary representations and subnet boundaries.

**Parameters:**
- `CIDR` - Network in CIDR notation (e.g., "192.168.1.0/24")
- `IPAddress` - IP address to analyze
- `Mask` - Subnet mask
- `PrefixLength` - Network prefix length (0-32)
- `WildCard` - Wildcard mask

**Example:**
```powershell
PS> Get-IPCalc 10.169.0.220/28

IPAddress    : 10.169.0.220
Mask         : 255.255.255.240
PrefixLength : 28
WildCard     : 0.0.0.15
Subnet       : 10.169.0.208
Broadcast    : 10.169.0.223
CIDR         : 10.169.0.208/28
ToDecimal    : 178847964
```

**Advanced Methods:**
```powershell
# Get all IP addresses in subnet
(Get-IPCalc 192.168.99.56/30).GetIPArray()

# Check if IP belongs to subnet
(Get-IPCalc 192.168.99.56/28).Compare('192.168.99.50')

# Check for overlapping subnets
(Get-IPCalc 192.168.0.0/25).Overlaps('192.168.0.0/27')

# Add to IP address
(Get-IPCalc 192.168.1.0/24).Add(10)

# Check if IP is on local network
(Get-IPCalc 192.168.1.0/24).isLocal('192.168.1.100')

# Get routing information
(Get-IPCalc 192.168.1.0/24).GetLocalRoute('192.168.1.100')
```

---

#### Get-NextSubnet
Calculates the next available subnet based on a given CIDR notation.

**Parameters:**
- `CIDR` - Current subnet in CIDR notation
- `prefixLength` - Prefix length for the next subnet (optional)

**Example:**
```powershell
PS> Get-NextSubnet -CIDR 10.0.0.0/20 -prefixLength 22
10.0.16.0/22

PS> Get-NextSubnet -CIDR "192.168.1.0/24"
192.168.2.0/24
```

**Use Cases:**
- Network planning and IP addressing schemes
- Automated subnet allocation
- IPAM (IP Address Management) tools

---

#### Get-IPAddressesInSubnet
Lists all IP addresses within a specified subnet using CIDR notation.

**Parameters:**
- `Subnet` - Subnet in CIDR notation

**Example:**
```powershell
PS> Get-IPAddressesInSubnet -Subnet 172.16.23.0/29
172.16.23.0
172.16.23.1
172.16.23.2
172.16.23.3
172.16.23.4
172.16.23.5
172.16.23.6
172.16.23.7
```

---

#### Get-IpAddressesInRange
Generates a list of IP addresses within a specified IP range.

**Parameters:**
- `Range` - IP address range in format "startIP-endIP"

**Example:**
```powershell
PS> Get-IpAddressesInRange -Range 192.168.1.13-192.168.1.19
192.168.1.13
192.168.1.14
192.168.1.15
192.168.1.16
192.168.1.17
192.168.1.18
192.168.1.19
```

---

#### Sort-IpAddress
Sorts an array of IP addresses in ascending order based on their octets.

**Parameters:**
- `IpAddressList` - Array of IP addresses to sort

**Example:**
```powershell
PS> Sort-IpAddress -IpAddressList "192.168.0.1","192.168.0.10","192.168.0.2"
192.168.0.1
192.168.0.2
192.168.0.10
```

---

#### Test-IpInSubnet
Validates if an IP address falls within a specified subnet or range.

**Parameters:**
- `IPv4Address` - IP address to validate
- `SubnetOrRange` - Subnet in CIDR format or range in x.x.x.x-x.x.x.y format

**Example:**
```powershell
PS> Test-IpInSubnet -IPv4Address "192.168.1.100" -SubnetOrRange "192.168.1.0/24"
True

PS> Test-IpInSubnet -IPv4Address "192.168.1.100" -SubnetOrRange "192.168.0.0-192.168.255.255"
True
```

---

#### Test-SubnetInSubnet
Determines if one subnet is fully contained within another subnet.

**Parameters:**
- `FirstSubnet` - Subnet to check if contained (CIDR notation)
- `SecondSubnet` - Potential containing subnet (CIDR notation)

**Example:**
```powershell
PS> Test-SubnetInSubnet -FirstSubnet "192.168.1.0/24" -SecondSubnet "192.168.0.0/16"
True

PS> Test-SubnetInSubnet -FirstSubnet "10.0.0.0/8" -SecondSubnet "192.168.0.0/16"
False
```

---

#### Test-IPv4Containment
Determines if a source IP/subnet/range is contained within a destination IP/subnet/range.

**Parameters:**
- `Source` - Source IP, subnet, or range
- `Destination` - Destination IP, subnet, or range

**Example:**
```powershell
PS> Test-IPv4Containment -Source 10.0.1.1 -Destination 10.0.0.0/24
False

PS> Test-IPv4Containment -Source 10.0.1.1 -Destination 10.0.0.0/23
True

PS> Test-IPv4Containment -Source "10.0.0.64/26" -Destination "10.0.0.0/24"
True
```

---

### Network Diagnostics

#### Ping-Ip
Advanced ping utility providing detailed connectivity testing with comprehensive statistics.

**Parameters:**
- `ComputerName` - Computer name or IP address to ping (mandatory)
- `Count` - Number of pings (default: 4)
- `BufferSize` - Packet buffer size in bytes (default: 32)
- `DontFragment` - Prevent packet fragmentation
- `Ttl` - Time-to-live value (default: 128)
- `Timeout` - Response timeout in milliseconds (default: 5000)
- `Continuous` - Send infinite number of pings
- `Short` - Shortened output format
- `OutToPipe` - Output objects to pipeline

**Example:**
```powershell
PS> Ping-Ip -ComputerName "www.google.com"
Pinging www.google.com with 32 bytes of data:
2024-11-19 14:01:24 Reply from 142.250.80.36: seq=1 bytes=32 time=18ms TTL=56
2024-11-19 14:01:25 Reply from 142.250.80.36: seq=2 bytes=32 time=17ms TTL=56
2024-11-19 14:01:26 Reply from 142.250.80.36: seq=3 bytes=32 time=19ms TTL=56
2024-11-19 14:01:27 Reply from 142.250.80.36: seq=4 bytes=32 time=18ms TTL=56

Ping statistics for www.google.com:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
Approximate round trip times in milli-seconds:
    Minimum = 17ms, Maximum = 19ms, Average = 18ms

# Continuous ping
PS> Ping-Ip -ComputerName "8.8.8.8" -Continuous

# Short format
PS> Ping-Ip -ComputerName "8.8.8.8" -Short

# Output to pipeline for further processing
PS> Ping-Ip -ComputerName "8.8.8.8" -OutToPipe | Where-Object ResponseTime -gt 50
```

---

#### Ping-IpList
**★ FEATURED FUNCTION ★**

Advanced parallel ping utility for multiple IP addresses with comprehensive monitoring capabilities including history tracking, downtime monitoring, and event logging.

**Key Features:**
- ✓ Parallel execution for high performance
- ✓ Visual ping history with symbols (! = success, . = failure)
- ✓ Real-time downtime tracking
- ✓ DNS resolution support
- ✓ Event logging for downtime/uptime events
- ✓ Flexible input (clipboard, ranges, CIDR, arrays)
- ✓ Continuous monitoring mode
- ✓ Customizable thread pool

**Parameters:**
- `FromClipBoard` - Read IP addresses from clipboard
- `ipList` - Array of IP addresses or hostnames
- `range` - IP address range (e.g., "192.168.1.1-192.168.1.254")
- `cidr` - CIDR notation subnet (e.g., "192.168.1.0/24")
- `Count` - Number of ping attempts (default: 4)
- `BufferSize` - Ping packet size (default: 32)
- `DontFragment` - Set Don't Fragment flag
- `Ttl` - Time to live (default: 128)
- `Timeout` - Timeout in milliseconds (default: 100)
- `Continuous` - Enable continuous ping mode
- `ResolveDNS` - Resolve IP addresses to hostnames
- `ShowHistory` - Display ping history with visual symbols
- `HistoryResetCount` - History length before reset (default: 100)
- `DontSortIpList` - Prevent automatic IP sorting
- `MaxThreads` - Maximum concurrent threads (default: 100)
- `OutToPipe` - Output results to pipeline
- `logEvents` - Log downtime/uptime events to file

**Examples:**

**Basic Usage - Ping from Clipboard:**
```powershell
# Copy IPs to clipboard, then:
PS> Ping-IpList -FromClipBoard -ShowHistory -Continuous

2025-10-23 15:26:36, Ping sequence: 27, Responding hosts: 4/4
1.1.1.1 [t:16ms DownFor:0s]:!!!!!!!!!!!!!!!!!!!!!!!!!!!
1.1.1.2 [t:16ms DownFor:0s]:!!!!!!!!!!!!!!!!!!!!!!!!!!!
4.2.2.4 [t:17ms DownFor:0s]:!!!!!!!!!!!!!!!!..!!!!!!!!!
8.8.8.8 [t:26ms DownFor:0s]:!!!!!!!!!!!!!!!!..!!!!!!!!!
```

**Understanding the History Display:**
- `!` = Successful ping
- `.` = Failed ping/timeout
- `t:16ms` = Current response time
- `DownFor:0s` = Total downtime in seconds
- Visual pattern shows recent ping history from left (oldest) to right (newest)

**Ping Multiple IPs:**
```powershell
PS> Ping-IpList -ipList "8.8.8.8","1.1.1.1","4.2.2.4" -Count 10

2024-11-19 13:57:24, Ping sequence: 10, Responding hosts: 3/3
IPAddress ResponsTime Result  DownTime
--------- ----------- ------  --------
1.1.1.1   18          Success 0
4.2.2.4   27          Success 0
8.8.8.8   27          Success 0
```

**Ping IP Range with History:**
```powershell
PS> Ping-IpList -range "192.168.1.1-192.168.1.10" -Continuous -ShowHistory

2024-11-19 13:57:24, Ping sequence: 7
192.168.1.1 [t:1ms DownFor:0s]:!!!!!!!
192.168.1.2 [t:-ms DownFor:9s]:.......
192.168.1.3 [t:-ms DownFor:9s]:.......
192.168.1.4 [t:2ms DownFor:0s]:!!!!!!!
```

**Ping CIDR Subnet with DNS Resolution:**
```powershell
PS> Ping-IpList -cidr "10.0.0.0/29" -ResolveDNS

2024-11-19 13:58:09, Ping sequence: 4
IPAddress          ResponsTime Result   DownTime
---------          ----------- ------   --------
10.0.0.0           -           TimedOut 4.49
host1.example.com  1           Success  0
10.0.0.2           1           Success  0
host3.example.com  1           Success  0
```

**Event Logging for Downtime Monitoring:**
```powershell
PS> Ping-IpList -fromClipBoard -ShowHistory -Continuous -logEvents -Timeout 50

# Creates log file: logs/Ping-IpList_<PID>_<date>.log
# Log entries show:
2025-10-23T15:26:26.938-05:00 [WARNING] [testuser@testpc01] 4.2.2.4 went down
2025-10-23T15:26:26.948-05:00 [WARNING] [testuser@testpc01] 8.8.8.8 went down
2025-10-23T15:26:28.032-05:00 [INFO] [testuser@testpc01] 4.2.2.4 is back online
2025-10-23T15:26:28.034-05:00 [INFO] [testuser@testpc01] 8.8.8.8 is back online
```

**Pipeline Output for Automation:**
```powershell
# Get final results for processing
PS> Ping-IpList -ipList "8.8.8.8","1.1.1.1" -Count 5 -OutToPipe | 
    Where-Object Result -eq "Success" | 
    Export-Csv -Path "successful_pings.csv"

# Monitor and alert on downtime
PS> Ping-IpList -cidr "192.168.1.0/24" -Continuous -OutToPipe | 
    Where-Object DownTime -gt 30 | 
    ForEach-Object { Send-MailMessage -To "admin@company.com" -Subject "Alert: $($_.IPAddress) down" }
```

**Performance Tuning:**
```powershell
# Fast scan with short timeout
PS> Ping-IpList -cidr "10.0.0.0/24" -Timeout 50 -MaxThreads 200

# Conservative scan for slow networks
PS> Ping-IpList -range "192.168.1.1-192.168.1.254" -Timeout 500 -MaxThreads 50
```

**Use Cases:**
- Network health monitoring and uptime tracking
- Identifying offline hosts in subnets
- Network documentation and discovery
- Performance baseline establishment
- Automated alerting for downtime events
- Post-maintenance verification
- Real-time network status dashboards

---

#### Test-TcpPorts
Tests connectivity to specified TCP ports on target hosts with parallel execution.

**Parameters:**
- `Targets` - Target hosts (IP addresses or domain names)
- `UseClipboardInput` - Use clipboard contents as targets
- `PortNumber` - Single port to test (1-65535)
- `PortRange` - Port range (e.g., "80-443")
- `Timeout` - Connection timeout in milliseconds (default: 1000)
- `UseCommon100Ports` - Test 100 most common ports
- `UseCommon1000Ports` - Test 1000 most common ports
- `SortResults` - Sort results by IP address
- `ResolveDNS` - Resolve IP addresses to hostnames
- `MaxThreads` - Maximum concurrent threads (default: 100)

**Example:**
```powershell
PS> Test-TcpPorts -Targets www.google.com -UseCommon100Ports

Hostname       Service Port Status
--------       ------- ---- ------
www.google.com http    80   Open
www.google.com https   443  Open

# Test specific port
PS> Test-TcpPorts -Targets "192.168.1.1" -PortNumber 3389

# Test port range on multiple hosts
PS> Test-TcpPorts -Targets "192.168.1.1","192.168.1.2" -PortRange "20-25"

# Scan entire subnet for web servers
PS> Test-TcpPorts -Targets "192.168.1.0/24" -PortNumber 80,443

# Use clipboard input
PS> Test-TcpPorts -UseClipboardInput -UseCommon100Ports
```

---

### Network Information & Monitoring

#### Get-IpConfig
Retrieves IP configuration for network interfaces on the local system.

**Parameters:**
- `ShowAll` - Display all network interfaces including virtual ones

**Example:**
```powershell
PS> Get-IpConfig

Interface  : Ethernet 3
IPAddress  : 192.168.1.10/22
Gateway    : 192.168.1.1
MacAddress : 00:50:56:af:7a:8d
DNSServers : {192.168.1.1, 192.168.1.2}

# Show all interfaces
PS> Get-IpConfig -ShowAll
```

---

#### Get-BandwidthUsage
Monitors real-time bandwidth usage for a specified network interface.

**Parameters:**
- `InterfaceName` - Network interface name (mandatory)
- `ShowHistory` - Enable historical logging instead of current display

**Example:**
```powershell
PS> Get-BandwidthUsage -InterfaceName "Ethernet"

Send          Receive       TotalSent TotalReceived
----          -------       --------- -------------
125 Kbps      1.5 Mbps      45.23 Mb  234.56 Mb

# Log historical data
PS> Get-BandwidthUsage -InterfaceName "Wi-Fi" -ShowHistory
```

**Features:**
- Real-time upload/download speeds
- Cumulative data transfer tracking
- Automatic unit conversion (Kbps/Mbps, Mb/Gb)
- Updates every second
- Press Ctrl+C to stop

---

#### Get-PublicIP
Continuously monitors and displays your public IP address with change detection.

**Example:**
```powershell
PS> Get-PublicIP
2024-11-19 14:30:15 - Public IP address: 203.0.113.45
2024-11-19 14:30:18 - Public IP address: 203.0.113.45
2024-11-19 14:30:21 - Public IP address changed to: 203.0.113.46
```

**Features:**
- Checks every 3 seconds
- Highlights IP changes in green
- Timeout error handling

---

#### Get-PublicIPWhois
Retrieves detailed public IP address information and WHOIS-like details from multiple providers.

**Parameters:**
- `IpAddress` - IP address to query (uses your own if omitted)
- `Provider` - Specific provider ('ip-api.com', 'ipapi.co', 'ipinfo.io')

**Example:**
```powershell
PS> Get-PublicIPWhois -IpAddress 8.8.8.8

query     : 8.8.8.8
status    : success
country   : United States
region    : California
city      : Mountain View
isp       : Google LLC
org       : Google Public DNS
as        : AS15169 Google LLC
Provider  : ip-api.com

# Query specific provider
PS> Get-PublicIPWhois -IpAddress 1.1.1.1 -Provider ipinfo.io

# Query your own IP
PS> Get-PublicIPWhois
```

---

### MAC Address Utilities

#### Convert-MacAddressFormat
Converts MAC addresses between Cisco format (xxxx.xxxx.xxxx) and regular format (xx:xx:xx:xx:xx:xx or xx-xx-xx-xx-xx-xx).

**Parameters:**
- `InputMacAddress` - MAC address or array of MAC addresses
- `GetMacFromClipboard` - Read MAC address from clipboard

**Example:**
```powershell
PS> Convert-MacAddressFormat -InputMacAddress "0050.56af.7a8d"
00:50:56:af:7a:8d

PS> Convert-MacAddressFormat -InputMacAddress "00:50:56:af:7a:8d"
0050.56af.7a8d

# Convert multiple MAC addresses
PS> $macs = @("1234.5678.9abc", "00:1A:2B:3C:4D:5E")
PS> Convert-MacAddressFormat -InputMacAddress $macs

# From clipboard
PS> Convert-MacAddressFormat -GetMacFromClipboard
```

---

#### Find-OUI
Identifies vendor information from MAC addresses using OUI (Organizationally Unique Identifier) lookup.

**Parameters:**
- `macAddress` - One or more MAC addresses to lookup
- `GetMacFromClipboard` - Read MAC address from clipboard
- `filePath` - Path to OUI database CSV file

**Example:**
```powershell
PS> Find-OUI -GetMacFromClipboard

MACAddress        OUI      Company
----------        ---      -------
00:50:56:af:7a:8d 00-50-56 VMware Inc.

# Lookup specific MAC
PS> Find-OUI -macAddress "A8-C6-47-12-34-56"

# Pipeline multiple MACs
PS> "00:11:22:33:44:55", "AA:BB:CC:DD:EE:FF" | Find-OUI
```

**Supported Formats:**
- With dashes: 00-11-22-33-44-55
- With colons: 00:11:22:33:44:55
- Without separators: 001122334455

---

#### Get-VirtualMacAddress
Generates a virtual MAC address based on an IP address using the 02:00:00 prefix.

**Parameters:**
- `IPAddress` - IP address to generate MAC from

**Example:**
```powershell
PS> Get-VirtualMacAddress -IPAddress 172.31.255.2
02:00:00:1F:FF:02

PS> "10.0.0.50" | Get-VirtualMacAddress
02:00:00:00:00:32
```

**Use Cases:**
- Virtual machine MAC address generation
- Network simulation and testing
- Consistent MAC address assignment

---

### Utility Functions

#### Send-SyslogMessage
Sends syslog messages to a syslog server via UDP or TCP.

**Parameters:**
- `Message` - Message to send (mandatory)
- `Server` - Syslog server address (mandatory)
- `Protocol` - Protocol to use: 'UDP' or 'TCP' (default: UDP)
- `Port` - Port number (default: 514)

**Example:**
```powershell
PS> Send-SyslogMessage -Message "Application started" -Server "192.168.1.100"

PS> Send-SyslogMessage -Message "Error occurred" -Server "syslog.company.com" -Protocol TCP -Port 514
```

---

#### Write-Log
Standard event logging helper that writes structured log lines to a log directory.

**Parameters:**
- `Message` - Text to log
- `Level` - Log level: INFO, WARN, WARNING, ERROR, DEBUG, TRACE
- `LogPath` - Override default file path
- `TimestampFormat` - Timestamp format string
- `Json` - Emit JSON format
- `WriteToHost` - Also write to console
- `fileNamePrefix` - Optional log file name prefix

**Example:**
```powershell
PS> "Something happened" | Write-Log -Level Info

PS> Write-Log -Message "Started process" -Level Debug -WriteToHost

PS> Write-Log -Message "Error occurred" -Level Error -Json
```

**Features:**
- Automatic log directory creation
- Structured logging with metadata
- Support for JSON output
- Color-coded console output
- Timestamped log files

---

## 🔥 Common Use Cases & Workflows

### Network Discovery and Documentation
```powershell
# Discover all active hosts in a subnet
$activeHosts = Ping-IpList -cidr "192.168.1.0/24" -Count 2 -OutToPipe | 
    Where-Object Result -eq "Success" |
    Select-Object -ExpandProperty IPAddress

# Get configuration for active hosts
foreach ($host in $activeHosts) {
    Test-TcpPorts -Targets $host -UseCommon100Ports
}
```

### Subnet Planning and Management
```powershell
# Calculate subnet information
$subnet = Get-IPCalc -CIDR "10.0.0.0/24"
Write-Host "Network: $($subnet.Subnet)"
Write-Host "Broadcast: $($subnet.Broadcast)"
Write-Host "Usable IPs: $($subnet.IPcount - 2)"

# Get next available subnet
$nextSubnet = Get-NextSubnet -CIDR "10.0.0.0/24"
Write-Host "Next subnet: $nextSubnet"

# Check if IP is in subnet
Test-IpInSubnet -IPv4Address "10.0.0.50" -SubnetOrRange "10.0.0.0/24"
```

### Network Monitoring Dashboard
```powershell
# Monitor critical servers with visual history
$criticalServers = @("192.168.1.1", "192.168.1.10", "192.168.1.20")
Ping-IpList -ipList $criticalServers -Continuous -ShowHistory -logEvents
```

### Port Scanning and Service Discovery
```powershell
# Scan network for web servers
Test-TcpPorts -Targets "192.168.1.0/24" -PortNumber 80,443 | 
    Where-Object Status -eq "Open"

# Check specific services
Test-TcpPorts -Targets "server01.company.com" -PortNumber 3389,22,445
```

### MAC Address Management
```powershell
# Convert MAC addresses from Excel/CSV
Import-Csv "mac_addresses.csv" | 
    ForEach-Object { 
        Convert-MacAddressFormat -InputMacAddress $_.MAC 
    }

# Identify vendors in your network
Get-NetAdapter | ForEach-Object {
    Find-OUI -macAddress $_.MacAddress
}
```

### IP Address Consolidation
```powershell
# Convert list of IPs to efficient subnets
$ipList = Get-Content "ip_addresses.txt"
Convert-IpListToSubnets -IPAddressList $ipList
```

---

## 💡 Pro Tips

1. **Pipeline Power**: Most functions support pipeline input for easy chaining
```powershell
Get-Content "ips.txt" | Sort-IpAddress | Ping-IpList -Count 5
```

2. **Clipboard Integration**: Use clipboard for quick ad-hoc operations
```powershell
# Copy IPs from Excel, then:
Ping-IpList -FromClipBoard -ShowHistory
```

3. **Parallel Processing**: Adjust MaxThreads based on your needs
```powershell
# Fast scan
Ping-IpList -cidr "10.0.0.0/16" -MaxThreads 500 -Timeout 50
```

4. **Event Logging**: Enable logging for long-running monitors
```powershell
Ping-IpList -cidr "192.168.1.0/24" -Continuous -logEvents
```

5. **Output to Pipeline**: Process results programmatically
```powershell
Ping-IpList -ipList $servers -OutToPipe | 
    Where-Object DownTime -gt 0 | 
    Export-Csv "downtime_report.csv"
```

---

## 🔧 Requirements

- **PowerShell**: 5.1 or higher (PowerShell 7+ recommended)
- **Administrator Privileges**: Required for some network operations
- **OUI Database**: Required for Find-OUI function (OUI.csv)
- **Ports Database**: Required for Test-TcpPorts service names (ports.csv)

---

## 📁 Module Structure

```
PSNetworking/
├── PSNetworking.psm1          # Module entry point
├── functions/                  # Function definitions
│   ├── Convert-IpListToSubnets.ps1
│   ├── Convert-MacFormat.ps1
│   ├── Find-OUI.ps1
│   ├── Get-BandwidthUsage.ps1
│   ├── Get-IPAddressesInSubnet.ps1
│   ├── Get-IpAddressesInRange.ps1
│   ├── Get-IPCalc.ps1
│   ├── Get-IpConfig.ps1
│   ├── Get-NextSubnet.ps1
│   ├── Get-PublicIP.ps1
│   ├── Get-PublicIPWhois.ps1
│   ├── Get-VirtualMacAddress.ps1
│   ├── Ping-Ip.ps1
│   ├── Ping-IpList.ps1
│   ├── Send-SyslogMessage.ps1
│
