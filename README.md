# PSNetworking PowerShell Module

A comprehensive PowerShell networking toolkit for network administrators and IT professionals.

## 🚀 Overview

PSNetworking is a powerful PowerShell module that provides a collection of networking utilities for IP address management, network diagnostics, and network information retrieval.

## 📦 Installation

```powershell
# Install from PowerShell Gallery (coming soon)
Install-Module -Name PSNetworking
```

## 🛠 Functions

### IP Address Management

1. **Convert-IpListToSubnets**
   - Converts a list of IP addresses into the most efficient subnet representations
   - Supports CIDR notation and traditional IP formats
   ```powershell
   Convert-IpListToSubnets -IPAddressList @("192.168.1.1", "192.168.1.2", "192.168.1.3")
   ```

2. **Get-IPAddressesInSubnet**
   - Lists all IP addresses within a specified subnet using CIDR notation
   ```powershell
   Get-IPAddressesInSubnet -Subnet "192.168.1.0/24"
   ```

3. **Get-IpAddressesInRange**
   - Generates a list of IP addresses within a specified IP range
   ```powershell
   Get-IpAddressesInRange -Range "192.168.1.1-192.168.1.5"
   ```

4. **Sort-IpAddress**
   - Sorts an array of IP addresses in ascending order
   ```powershell
   Sort-IpAddress -IpAddressList "192.168.0.1","192.168.0.10","192.168.0.2"
   ```

5. **Test-IpInSubnet**
   - Validates if an IP address falls within a specified subnet or range
   ```powershell
   Test-IpInSubnet -IPv4Address "192.168.1.100" -SubnetOrRange "192.168.1.0/24"
   ```

6. **Test-SubnetInSubnet**
   - Determines if one subnet is fully contained within another subnet
   ```powershell
   Test-SubnetInSubnet -FirstSubnet "192.168.1.0/24" -SecondSubnet "192.168.0.0/16"
   ```

### Network Diagnostics

1. **Ping-Ip**
   - Advanced ping utility with detailed connectivity testing
   ```powershell
   Ping-Ip -ComputerName "www.google.com"
   ```

2. **Ping-IpList**
   - Parallel ping utility for multiple IP addresses
   ```powershell
   Ping-IpList -ipList "8.8.8.8","1.1.1.1" -Count 10
   ```

### Network Information

1. **Get-IpConfig**
   - Retrieves IP configuration for network interfaces
   ```powershell
   Get-IpConfig  # Shows active physical interfaces
   Get-IpConfig -ShowAll  # Shows all interfaces
   ```

2. **Get-PublicIP**
   - Monitors and displays your public IP address
   ```powershell
   Get-PublicIP
   ```

### MAC Address Utilities

1. **Convert-MacAddressFormat**
   - Converts MAC addresses between Cisco and regular formats
   ```powershell
   Convert-MacAddressFormat -InputMacAddress "1234.5678.9abc"
   ```

2. **Find-OUI**
   - Identifies vendor information from MAC addresses
   ```powershell
   Find-OUI -macAddress "A8-C6-47-12-34-56"
   ```

### Network Performance

1. **Get-BandwidthUsage**
   - Monitors real-time bandwidth usage for network interfaces
   ```powershell
   Get-BandwidthUsage -InterfaceName "Ethernet"
   ```

## 🔧 Requirements

- PowerShell 5.1 or higher
- Administrator privileges for some network operations

## 📄 License

[MIT License](https://github.com/imanedr/psnetworking/blob/main/LICENSE)

## 🤝 Contributing

Contributions are welcome! Please check the [GitHub repository](https://github.com/imanedr/psnetworking) for guidelines.

## 📞 Support

For issues and feature requests, please file an issue on the [GitHub repository](https://github.com/imanedr/psnetworking).

## 👨‍💻 Author

Iman Edrisian

