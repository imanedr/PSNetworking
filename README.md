**README.md**

```markdown
# PowerShell Networking Toolkit

A comprehensive collection of PowerShell networking utilities designed to streamline network management and automate common networking tasks.

## Core Features

- IP Address Management
- Network Scanning
- Subnet Calculations
- Network Testing
- IP Address Sorting

## Available Scripts

### IP Address Management

- `Get-IpAddressesInRange.ps1`: Generate IP address lists from specified ranges.
  Example:
  ```powershell
  .\Get-IpAddressesInRange.ps1 -StartIPAddress 192.168.1.1 -EndIPAddress 192.168.1.10
  ```

- `Get-IPAddressesInSubnet.ps1`: Enumerate all IP addresses within a subnet.
  Example:
  ```powershell
  .\Get-IPAddressesInSubnet.ps1 -IPAddress 192.168.1.1 -SubnetMask 255.255.255.0
  ```

- `Get-IPCalc.ps1`: Advanced IP calculator for subnet details.
  Example:
  ```powershell
  .\Get-IPCalc.ps1 -IPAddress 192.168.1.1 -SubnetMask 255.255.255.0
  ```

### Network Discovery

- `Get-PublicIP.ps1`: Retrieve your current public IP address.
  Example:
  ```powershell
  .\Get-PublicIP.ps1
  ```

- `Ping-Network.ps1`: Perform network sweep with ping functionality.
  Example:
  ```powershell
  .\Ping-Network.ps1 -StartIPAddress 192.168.1.1 -EndIPAddress 192.168.1.10
  ```

### Network Tools

- `Sort-IpAddress.ps1`: Sort IP addresses numerically.
  Example:
  ```powershell
  .\Sort-IpAddress.ps1 -IPAddressList 192.168.1.10, 192.168.1.1, 192.168.1.5
  ```

- `Test-IpInSubnet.ps1`: Validate IP address subnet membership.
  Example:
  ```powershell
  .\Test-IpInSubnet.ps1 -IPAddress 192.168.1.1 -SubnetMask 255.255.255.0 -TargetIPAddress 192.168.1.5
  ```

## Quick Start

1. Clone this repository:

   ```bash
   git clone https://github.com/yourusername/psnetworking.git
   ```

2. Open a PowerShell window and navigate to the functions directory.

3. Run the desired script using the PowerShell command line.

## Usage

Each script has its own set of parameters and usage instructions. Run the script with the `-Help` parameter to view usage information.
```

This README file provides a comprehensive overview of the PowerShell Networking Toolkit, including the core features, available scripts, and usage examples. It also includes a quick start guide and instructions for running the scripts.