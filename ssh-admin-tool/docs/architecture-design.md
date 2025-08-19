# SSH Auto-Tunneling Client-Server Architecture Design

## Overview

This document outlines the design for a desktop application that creates clients which automatically establish SSH tunnels back to a parent/central server. This is designed for network administrators who need persistent, auto-reconnecting SSH tunnels for remote management.

## Architecture Components

### 1. Parent/Central Server
- **Role**: Central hub that receives incoming SSH tunnel connections from clients
- **Location**: Server with public IP address or accessible through network
- **Responsibilities**:
  - Accept reverse SSH tunnel connections from clients
  - Manage client authentication and authorization
  - Provide management interface for administrators
  - Monitor tunnel health and client status
  - Distribute configuration updates to clients

### 2. Auto-Tunneling Clients
- **Role**: Lightweight agents deployed on remote systems
- **Responsibilities**:
  - Automatically discover parent server
  - Establish reverse SSH tunnels to parent server
  - Maintain persistent connections with auto-reconnect
  - Handle network interruptions gracefully
  - Self-configure based on parent server instructions

## Technical Architecture

### Core Technologies

**PowerShell-Based Implementation**
- **Primary Language**: PowerShell (cross-platform support)
- **SSH Library**: SSH.NET (Renci.SshNet.dll) for .NET integration
- **Network Discovery**: PowerShell native cmdlets (Test-NetConnection, etc.)
- **Service Management**: Windows Services / systemd for persistence
- **Configuration**: PowerShell configuration files and registry

### SSH Tunnel Architecture

**Reverse SSH Tunnel Pattern**
```
[Client] ---(SSH Tunnel)---> [Parent Server]
         <---(Management)---
```

**Key Features**:
- **Reverse Tunnels**: Clients initiate connections to parent server
- **Auto-Reconnect**: Automatic reconnection on network failures
- **Persistent**: Runs as system service for reliability
- **Secure**: SSH key-based authentication
- **Configurable**: Dynamic port allocation and routing

## Implementation Details

### Client Component Architecture

**1. Core Client Service**
```powershell
# Main client service structure
- SSH Tunnel Manager
  - Connection establishment
  - Health monitoring
  - Auto-reconnection logic
- Configuration Manager
  - Parent server discovery
  - SSH key management
  - Local configuration
- Network Discovery
  - Parent server location
  - Network connectivity testing
  - Proxy detection and handling
```

**2. SSH Tunnel Implementation**
Based on research findings, using SSH.NET library:

```powershell
# Core tunnel establishment
[void][reflection.assembly]::LoadFrom("Renci.SshNet.dll")

$connectionInfo = New-Object Renci.SshNet.PasswordConnectionInfo($targetHost, $targetPort, $username, $password)
$sshClient = New-Object Renci.SshNet.SshClient($connectionInfo)

# Establish reverse tunnel
$forwardedPort = New-Object Renci.SshNet.ForwardedPortRemote($bindHost, $bindPort, $localHost, $localPort)
$sshClient.AddForwardedPort($forwardedPort)
$sshClient.Connect()
$forwardedPort.Start()
```

**3. Auto-Reconnection Logic**
Inspired by autossh implementation:

```powershell
# Continuous monitoring and reconnection
while ($true) {
    try {
        if (-not $sshClient.IsConnected) {
            Write-Log "(re)starting SSH tunnel"
            Establish-SSHTunnel
        }
        Test-TunnelHealth
        Start-Sleep -Seconds 30
    }
    catch {
        Write-Log "Tunnel failed: $($_.Exception.Message)"
        Start-Sleep -Seconds 10
    }
}
```

### Parent Server Component Architecture

**1. SSH Server Configuration**
```bash
# SSH server configuration for tunnel users
Match User tunnel-client
    AllowTcpForwarding yes
    X11Forwarding no
    PermitTunnel no
    GatewayPorts yes
    AllowAgentForwarding no
    PermitOpen localhost:* server.domain.com:*
    ForceCommand echo 'Tunnel client connected'
```

**2. Management Interface**
- **PowerShell-based admin console**
- **Web-based dashboard (optional)**
- **Client status monitoring**
- **Configuration distribution**
- **Tunnel health reporting**

### Network Discovery and Auto-Configuration

**1. Parent Server Discovery Methods**
```powershell
# Multiple discovery methods
1. DNS-based discovery (SRV records)
2. Network broadcast discovery
3. Configuration file with fallback servers
4. DHCP option-based discovery
5. Manual configuration override
```

**2. Auto-Configuration Process**
```powershell
# Client auto-configuration workflow
1. Discover parent server location
2. Test connectivity to parent server
3. Request configuration from parent
4. Generate or receive SSH keys
5. Establish initial tunnel
6. Register with parent server
7. Begin health monitoring loop
```

## Security Considerations

### Authentication and Authorization
- **SSH Key-Based Authentication**: No password-based authentication
- **Client Certificates**: Optional client certificate validation
- **Restricted Shell Access**: Tunnel-only access for client users
- **Network Segmentation**: Isolated tunnel network segments

### Network Security
- **Firewall-Friendly**: Uses standard SSH ports (22, 443, 80)
- **Proxy Support**: HTTP/SOCKS proxy traversal capability
- **Encrypted Communication**: All traffic encrypted via SSH
- **Port Restrictions**: Limited port forwarding permissions

## Deployment Architecture

### Client Deployment
```powershell
# Client deployment package structure
ssh-tunnel-client/
├── bin/
│   ├── SSHTunnelClient.ps1      # Main client script
│   ├── Renci.SshNet.dll         # SSH.NET library
│   └── Install-Client.ps1       # Installation script
├── config/
│   ├── client.conf              # Client configuration
│   └── servers.conf             # Parent server list
├── service/
│   ├── SSHTunnelService.ps1     # Windows service wrapper
│   └── install-service.ps1      # Service installation
└── docs/
    └── README.md                # Installation instructions
```

### Server Deployment
```powershell
# Server deployment structure
ssh-tunnel-server/
├── bin/
│   ├── TunnelManager.ps1        # Server management
│   └── ClientMonitor.ps1        # Client monitoring
├── config/
│   ├── sshd_config.tunnel       # SSH server config
│   └── server.conf              # Server configuration
├── web/
│   └── dashboard/               # Web management interface
└── scripts/
    ├── setup-server.ps1         # Server setup script
    └── add-client.ps1           # Client registration
```

## Configuration Management

### Client Configuration
```powershell
# client.conf example
@{
    ParentServers = @(
        @{ Host = "tunnel.company.com"; Port = 22; Priority = 1 }
        @{ Host = "backup.company.com"; Port = 443; Priority = 2 }
    )
    ClientId = "auto-generated-uuid"
    TunnelPorts = @{
        SSH = 22
        RDP = 3389
        HTTP = 80
        HTTPS = 443
    }
    ReconnectInterval = 30
    HealthCheckInterval = 60
    LogLevel = "Info"
}
```

### Server Configuration
```powershell
# server.conf example
@{
    ListenPorts = @(22, 443)
    ClientPortRange = @{ Start = 10000; End = 20000 }
    MaxClients = 1000
    TunnelTimeout = 300
    LogRetention = 30
    WebInterface = @{
        Enabled = $true
        Port = 8080
        SSL = $true
    }
}
```

## Monitoring and Management

### Health Monitoring
- **Tunnel Status**: Active/inactive tunnel monitoring
- **Client Connectivity**: Last seen timestamps and status
- **Network Performance**: Latency and throughput metrics
- **Error Tracking**: Connection failures and retry attempts

### Management Features
- **Remote Configuration**: Push configuration updates to clients
- **Tunnel Control**: Start/stop/restart individual tunnels
- **Client Management**: Add/remove/configure clients
- **Reporting**: Usage statistics and health reports

## Scalability Considerations

### Performance Optimization
- **Connection Pooling**: Reuse SSH connections where possible
- **Load Balancing**: Multiple parent servers for redundancy
- **Resource Management**: CPU and memory usage optimization
- **Network Efficiency**: Compression and keep-alive optimization

### High Availability
- **Multiple Parent Servers**: Automatic failover between servers
- **Health Checks**: Continuous monitoring and automatic recovery
- **Graceful Degradation**: Fallback modes for partial failures
- **Backup Connectivity**: Multiple network paths and protocols

## Development Phases

### Phase 1: Core Infrastructure
- SSH tunnel establishment and management
- Basic auto-reconnection logic
- Simple configuration management
- Windows service integration

### Phase 2: Discovery and Auto-Configuration
- Parent server discovery mechanisms
- Automatic client configuration
- SSH key management and distribution
- Network proxy support

### Phase 3: Management Interface
- Server-side client monitoring
- Web-based management dashboard
- Configuration distribution system
- Health monitoring and alerting

### Phase 4: Advanced Features
- Load balancing and failover
- Advanced security features
- Performance optimization
- Cross-platform support (Linux/macOS)

## Technology Stack Summary

**Client Side**:
- PowerShell 5.1+ / PowerShell Core 7+
- SSH.NET library (Renci.SshNet.dll)
- Windows Services / systemd
- .NET Framework / .NET Core

**Server Side**:
- OpenSSH server
- PowerShell management scripts
- Optional web interface (ASP.NET Core)
- Database for client management (SQLite/SQL Server)

**Network Protocols**:
- SSH (primary tunnel protocol)
- HTTP/HTTPS (management interface)
- DNS (service discovery)
- DHCP (auto-configuration)

This architecture provides a robust, scalable solution for automatic SSH tunnel management in enterprise network environments.

