# SSH Tunnel Management System

A comprehensive network administration tool for automatic SSH tunnel establishment and management between remote stations and central servers.

## 🚀 Features

- **Automatic Tunnel Establishment**: Clients automatically establish reverse SSH tunnels to parent servers
- **Auto-Reconnection**: Intelligent reconnection with exponential backoff on connection failures
- **Network Discovery**: Multiple discovery methods including DNS SRV, broadcast, and network scanning
- **Web Management Dashboard**: Professional React-based interface for monitoring and managing tunnels
- **Windows Service Integration**: Runs as persistent Windows service with proper logging
- **Implied Consent Architecture**: Installation implies administrative consent for tunnel operations
- **Multi-Server Support**: Load balancing and failover across multiple tunnel servers
- **Comprehensive Logging**: Detailed logging with Windows Event Log integration

## 🏗️ Architecture

```
┌─────────────────┐    SSH Reverse Tunnels    ┌─────────────────┐
│   Remote Client │◄─────────────────────────►│  Parent Server  │
│                 │                           │                 │
│ • Auto-connect  │                           │ • Web Dashboard │
│ • Service Mode  │                           │ • Client Mgmt   │
│ • Discovery     │                           │ • Monitoring    │
└─────────────────┘                           └─────────────────┘
```

### Components

1. **SSH Tunnel Client** (`src/client/`)
   - PowerShell module for tunnel management
   - Windows service wrapper
   - Auto-discovery and configuration
   - Connection monitoring and recovery

2. **SSH Tunnel Server** (`src/server/`)
   - Central management server
   - Client registration and tracking
   - Web API for dashboard integration
   - Statistics and monitoring

3. **Web Dashboard** (`tunnel-dashboard/`)
   - React-based management interface
   - Real-time client monitoring
   - Tunnel visualization and statistics
   - Deployment tools and configuration

4. **Common Libraries** (`src/common/`)
   - Shared PowerShell functions
   - Network discovery utilities
   - Configuration management
   - Logging and error handling

## 📋 Requirements

### Server Requirements
- Windows Server 2016+ or Linux with PowerShell Core
- PowerShell 5.1+
- OpenSSH Server
- 2GB RAM, 10GB disk space
- Static IP or FQDN

### Client Requirements
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1+
- OpenSSH Client (included in Windows 10 1809+)
- Administrator privileges for installation

## 🚀 Quick Start

### 1. Server Setup

```powershell
# Install OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType 'Automatic'

# Configure firewall
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
New-NetFirewallRule -Name ssh-tunnel-web -DisplayName 'SSH Tunnel Web' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 8080

# Start SSH Tunnel Server
cd src/server
.\WebAPI.ps1 -Port 8080
```

### 2. Client Installation

```powershell
# Run as Administrator
.\Install-SSHTunnelClient.ps1 -ServerHost "your-server.domain.com" -AutoStart
```

### 3. Access Web Dashboard

Open your browser and navigate to:
```
http://your-server:8080
```

## 📖 Documentation

- **[Deployment Guide](docs/deployment-guide.md)** - Complete installation and configuration guide
- **[Architecture Design](docs/architecture-design.md)** - Technical architecture and design decisions
- **[API Documentation](docs/api-reference.md)** - REST API reference for integration
- **[Troubleshooting Guide](docs/troubleshooting.md)** - Common issues and solutions

## 🔧 Configuration

### Client Configuration (`config/client.conf`)

```powershell
@{
    # Server connection settings
    ParentServers = @(
        @{ Host = "tunnel.company.com"; Port = 22; Priority = 1 }
        @{ Host = "backup.company.com"; Port = 443; Priority = 2 }
    )
    
    # Authentication
    Username = "tunnel-client"
    PrivateKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
    
    # Tunnel configuration
    TunnelPorts = @{
        SSH = 22
        RDP = 3389
        HTTP = 80
        HTTPS = 443
    }
    
    # Behavior settings
    AutoRestart = $true
    ReconnectInterval = 30
    MaxReconnectAttempts = 10
}
```

### Server Configuration (`config/server.conf`)

```powershell
@{
    # Server settings
    ListenPorts = @(22, 443)
    ClientPortRange = @{ Start = 10000; End = 20000 }
    MaxClients = 1000
    
    # Web interface
    WebInterface = @{
        Enabled = $true
        Port = 8080
        SSL = $false
    }
    
    # Security
    Security = @{
        AllowedUsers = @("tunnel-client")
        RequireKeyAuth = $true
        MaxConnectionsPerClient = 10
    }
}
```

## 🔍 Network Discovery

The system supports multiple discovery methods:

### DNS SRV Records
```dns
_ssh-tunnel._tcp.company.com. 300 IN SRV 10 5 22 tunnel.company.com.
```

### Broadcast Discovery
```powershell
# Automatic broadcast discovery on local network
Find-ServersByBroadcast -Timeout 10
```

### Network Scanning
```powershell
# Scan network range for SSH tunnel servers
Find-ServersByNetworkScan -NetworkRange "192.168.1.0/24"
```

## 🖥️ Web Dashboard

The web dashboard provides comprehensive monitoring and management:

### Features
- **Client Overview**: Real-time status of all connected clients
- **Tunnel Monitoring**: Active tunnel visualization and statistics
- **Connection History**: Historical connection data and trends
- **Deployment Tools**: Client installation package generation
- **System Health**: Server performance and resource monitoring

### Screenshots

#### Client Management
![Client Management](docs/images/dashboard-clients.png)

#### Tunnel Visualization
![Tunnel Visualization](docs/images/dashboard-tunnels.png)

#### Monitoring Dashboard
![Monitoring](docs/images/dashboard-monitoring.png)

## 🔐 Security

### Authentication
- SSH key-based authentication (RSA 4096-bit recommended)
- Dedicated user account for tunnel clients
- Key rotation support

### Network Security
- Reverse tunnel architecture (clients initiate connections)
- Firewall-friendly operation
- Optional proxy support for restricted environments

### System Security
- Windows service isolation
- Minimal privilege operation
- Comprehensive audit logging

## 🛠️ Development

### Building the Dashboard

```bash
cd tunnel-dashboard
npm install
npm run build
```

### Running Tests

```powershell
# Test client functionality
Import-Module src/client/SSHTunnelClient.psm1
Test-SSHTunnelClient

# Test server functionality
Import-Module src/server/SSHTunnelServer.psm1
Test-SSHTunnelServer

# Test network discovery
Import-Module src/common/NetworkDiscovery.ps1
Test-NetworkDiscovery
```

### Development Mode

```powershell
# Start server in development mode
.\WebAPI.ps1 -Port 8080 -Development

# Start React development server
cd tunnel-dashboard
npm run dev
```

## 📊 Monitoring

### Key Metrics
- **Active Clients**: Number of connected tunnel clients
- **Tunnel Count**: Total active tunnels across all clients
- **Connection Success Rate**: Percentage of successful connections
- **Reconnection Frequency**: Rate of connection recovery events
- **Resource Usage**: Server CPU, memory, and network utilization

### Logging
- **Client Logs**: `C:\Program Files\SSHTunnelClient\logs\`
- **Server Logs**: `C:\Program Files\SSHTunnelServer\logs\`
- **Windows Event Log**: Application log with source "SSHTunnelClient"

### Health Checks
```powershell
# Check system health
Get-SSHTunnelHealth

# View connection statistics
Get-SSHTunnelStatistics

# Test connectivity
Test-SSHTunnelConnectivity
```

## 🔧 Troubleshooting

### Common Issues

1. **Client Cannot Connect**
   ```powershell
   # Test network connectivity
   Test-NetConnection -ComputerName "server" -Port 22
   
   # Verify SSH authentication
   ssh -i "key" tunnel-client@server
   ```

2. **Service Won't Start**
   ```powershell
   # Check service status
   Get-Service -Name "SSHTunnelClient"
   
   # View event logs
   Get-EventLog -LogName Application -Source "SSHTunnelClient"
   ```

3. **Tunnels Not Establishing**
   ```powershell
   # Test manual tunnel
   ssh -i "key" -R 10022:localhost:22 tunnel-client@server
   
   # Check SSH server config
   Get-Content "C:\ProgramData\ssh\sshd_config"
   ```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow PowerShell best practices and style guidelines
- Include comprehensive error handling and logging
- Write unit tests for new functionality
- Update documentation for any changes
- Test on multiple Windows versions

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- OpenSSH project for the underlying SSH implementation
- PowerShell team for the automation framework
- React and shadcn/ui for the web dashboard components
- Network administrators who provided requirements and feedback

## 📞 Support

For support and questions:

- **Documentation**: Check the [docs/](docs/) directory
- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions for questions
- **Security**: Report security issues privately

## 🗺️ Roadmap

### Version 1.1
- [ ] Linux client support
- [ ] Certificate-based authentication
- [ ] Advanced load balancing
- [ ] Mobile dashboard app

### Version 1.2
- [ ] Kubernetes integration
- [ ] REST API expansion
- [ ] Advanced monitoring and alerting
- [ ] Multi-tenant support

### Version 2.0
- [ ] Zero-trust architecture
- [ ] Cloud service integration
- [ ] Advanced analytics
- [ ] Machine learning for optimization

---

**SSH Tunnel Management System** - Secure, reliable, and manageable remote access for network administrators.

