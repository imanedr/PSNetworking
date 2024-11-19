# 🌐 PowerShell Networking Toolkit

A powerful collection of PowerShell scripts for network administrators and IT professionals to efficiently manage and automate networking tasks.

## ⭐ Key Features

- 📋 IP Address Range Management
- 🔍 Network Discovery & Scanning
- 🧮 Subnet Calculations
- 📡 Network Connectivity Testing
- 📊 IP Address Organization

## 🚀 Quick Start

1. Clone the repository:

git clone https://github.com/imanedr/psnetworking.git

2. Navigate to the project directory
3. Run scripts using PowerShell

## 📚 Available Tools

### IP Management

| Script | Description | Example |
|--------|-------------|---------|
| `Get-IpAddressesInRange.ps1` | Generate IP lists from ranges | `.\Get-IpAddressesInRange.ps1 -StartIPAddress 192.168.1.1 -EndIPAddress 192.168.1.10` |
| `Get-IPAddressesInSubnet.ps1` | List all IPs in subnet | `.\Get-IPAddressesInSubnet.ps1 -IPAddress 192.168.1.1 -SubnetMask 255.255.255.0` |
| `Get-IPCalc.ps1` | Calculate subnet details | `.\Get-IPCalc.ps1 -IPAddress 192.168.1.1 -SubnetMask 255.255.255.0` |

### Network Tools

| Script | Description | Example |
|--------|-------------|---------|
| `Get-PublicIP.ps1` | Get your public IP | `.\Get-PublicIP.ps1` |
| `Ping-Network.ps1` | Sweep network with ping | `.\Ping-Network.ps1 -StartIPAddress 192.168.1.1 -EndIPAddress 192.168.1.10` |
| `Sort-IpAddress.ps1` | Sort IPs numerically | `.\Sort-IpAddress.ps1 -IPAddressList 192.168.1.10, 192.168.1.1` |
| `Test-IpInSubnet.ps1` | Check IP subnet membership | `.\Test-IpInSubnet.ps1 -IPAddress 192.168.1.1 -SubnetMask 255.255.255.0 -TargetIPAddress 192.168.1.5` |

## 💡 Usage Tips

- All scripts support the `-Help` parameter for detailed instructions
- Run scripts from PowerShell with administrator privileges when needed
- Use tab completion for parameter names and values

## 🔧 Requirements

- PowerShell 5.1 or higher
- Windows PowerShell or PowerShell Core
- Administrator rights (for some network operations)

## 📖 Documentation

Each script includes detailed help documentation. Access it using:

Get-Help .\ScriptName.ps1 -Full

