# SSH Tunnel Server Packaging Script
# Creates deployment packages for SSH tunnel server

#Requires -Version 5.1

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\packages",
    
    [Parameter(Mandatory = $false)]
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

Write-Host "SSH Tunnel Server Packaging Script" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$packagePath = Join-Path $OutputPath "SSHTunnelServer-$Version"
$zipPath = "$packagePath.zip"

Write-Host "Creating server package..." -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Gray
Write-Host "Output: $packagePath" -ForegroundColor Gray
Write-Host ""

# Create package directory structure
$packageDirs = @(
    "$packagePath\bin",
    "$packagePath\config",
    "$packagePath\web",
    "$packagePath\keys",
    "$packagePath\logs",
    "$packagePath\data",
    "$packagePath\docs"
)

foreach ($dir in $packageDirs) {
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
}

# Copy server files
Write-Host "Copying server files..." -ForegroundColor Yellow

# PowerShell modules and scripts
Copy-Item "..\src\server\*" "$packagePath\bin\" -Recurse -Force
Copy-Item "..\src\common\*" "$packagePath\bin\" -Recurse -Force

# Web dashboard (built React app)
if (Test-Path "..\tunnel-dashboard\dist") {
    Copy-Item "..\tunnel-dashboard\dist\*" "$packagePath\web\" -Recurse -Force
} else {
    Write-Warning "Web dashboard not built. Run 'npm run build' in tunnel-dashboard directory first."
}

# Configuration files
Copy-Item "..\config\server.conf.example" "$packagePath\config\" -Force

# Documentation
Copy-Item "..\README.md" "$packagePath\docs\" -Force
Copy-Item "..\docs\*" "$packagePath\docs\" -Recurse -Force

# Create installation script
$installScript = @"
# SSH Tunnel Server Installation Script
# Run as Administrator

param(
    [Parameter(Mandatory = `$false)]
    [int]`$WebPort = 8080,
    
    [Parameter(Mandatory = `$false)]
    [int]`$SSHPort = 22,
    
    [Parameter(Mandatory = `$false)]
    [switch]`$AutoStart = `$false
)

`$ErrorActionPreference = "Stop"

Write-Host "Installing SSH Tunnel Server..." -ForegroundColor Green

# Check administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Installation paths
`$installPath = "C:\Program Files\SSHTunnelServer"

try {
    # Create installation directory
    if (Test-Path `$installPath) {
        Write-Host "Removing existing installation..." -ForegroundColor Yellow
        Remove-Item `$installPath -Recurse -Force
    }
    
    New-Item -Path `$installPath -ItemType Directory -Force | Out-Null
    
    # Copy files
    Write-Host "Copying files..." -ForegroundColor Yellow
    Copy-Item ".\bin\*" "`$installPath\bin\" -Recurse -Force
    Copy-Item ".\config\*" "`$installPath\config\" -Recurse -Force
    Copy-Item ".\web\*" "`$installPath\web\" -Recurse -Force
    Copy-Item ".\docs\*" "`$installPath\docs\" -Recurse -Force
    
    # Create directories
    New-Item -Path "`$installPath\logs" -ItemType Directory -Force | Out-Null
    New-Item -Path "`$installPath\keys" -ItemType Directory -Force | Out-Null
    New-Item -Path "`$installPath\data" -ItemType Directory -Force | Out-Null
    
    # Configure server
    Write-Host "Configuring server..." -ForegroundColor Yellow
    `$configPath = "`$installPath\config\server.conf"
    
    if (Test-Path "`$configPath.example") {
        Copy-Item "`$configPath.example" `$configPath -Force
        
        # Update configuration with provided settings
        `$config = Get-Content `$configPath -Raw
        `$config = `$config -replace "Port = 8080", "Port = `$WebPort"
        Set-Content `$configPath -Value `$config
    }
    
    # Install OpenSSH Server if not present
    Write-Host "Checking OpenSSH Server..." -ForegroundColor Yellow
    `$sshFeature = Get-WindowsCapability -Online -Name OpenSSH.Server*
    
    if (`$sshFeature.State -ne "Installed") {
        Write-Host "Installing OpenSSH Server..." -ForegroundColor Yellow
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    }
    
    # Configure SSH service
    Write-Host "Configuring SSH service..." -ForegroundColor Yellow
    Set-Service -Name sshd -StartupType 'Automatic'
    
    if ((Get-Service -Name sshd).Status -ne "Running") {
        Start-Service sshd
    }
    
    # Configure firewall
    Write-Host "Configuring firewall..." -ForegroundColor Yellow
    
    # SSH port
    `$sshRule = Get-NetFirewallRule -DisplayName "OpenSSH Server (sshd)" -ErrorAction SilentlyContinue
    if (-not `$sshRule) {
        New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort `$SSHPort
    }
    
    # Web interface port
    `$webRule = Get-NetFirewallRule -DisplayName "SSH Tunnel Web Interface" -ErrorAction SilentlyContinue
    if (-not `$webRule) {
        New-NetFirewallRule -Name ssh-tunnel-web -DisplayName 'SSH Tunnel Web Interface' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort `$WebPort
    }
    
    # Create tunnel user account
    Write-Host "Creating tunnel user account..." -ForegroundColor Yellow
    `$username = "tunnel-client"
    `$password = ConvertTo-SecureString "TunnelClient123!" -AsPlainText -Force
    
    `$existingUser = Get-LocalUser -Name `$username -ErrorAction SilentlyContinue
    if (-not `$existingUser) {
        New-LocalUser -Name `$username -Password `$password -Description "SSH Tunnel Client Account" -PasswordNeverExpires
        Add-LocalGroupMember -Group "Users" -Member `$username
    }
    
    # Generate SSH keys
    Write-Host "Generating SSH keys..." -ForegroundColor Yellow
    `$keyPath = "`$installPath\keys\tunnel_key"
    
    if (-not (Test-Path `$keyPath)) {
        & ssh-keygen -t rsa -b 4096 -f `$keyPath -N '""' -C "SSH Tunnel Key"
        
        # Set up authorized_keys for tunnel user
        `$userSSHDir = "C:\Users\`$username\.ssh"
        New-Item -Path `$userSSHDir -ItemType Directory -Force | Out-Null
        Copy-Item "`$keyPath.pub" "`$userSSHDir\authorized_keys" -Force
        
        # Set proper permissions
        icacls "`$userSSHDir" /inheritance:r /grant:r "`$username`:F" /grant:r "SYSTEM:F" /grant:r "Administrators:F"
        icacls "`$userSSHDir\authorized_keys" /inheritance:r /grant:r "`$username`:R" /grant:r "SYSTEM:F" /grant:r "Administrators:F"
    }
    
    # Configure SSH server for tunneling
    Write-Host "Configuring SSH server for tunneling..." -ForegroundColor Yellow
    `$sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
    `$tunnelConfig = @"

# SSH Tunnel Configuration
Match User `$username
    AllowTcpForwarding yes
    GatewayPorts yes
    X11Forwarding no
    PermitTunnel no
    AllowAgentForwarding no
"@
    
    `$currentConfig = Get-Content `$sshdConfigPath -Raw -ErrorAction SilentlyContinue
    if (`$currentConfig -notmatch "Match User `$username") {
        Add-Content -Path `$sshdConfigPath -Value `$tunnelConfig
        Restart-Service sshd
    }
    
    # Start web server if requested
    if (`$AutoStart) {
        Write-Host "Starting web server..." -ForegroundColor Yellow
        Start-Process powershell -ArgumentList "-File `"`$installPath\bin\WebAPI.ps1`" -Port `$WebPort" -WindowStyle Hidden
        
        Start-Sleep -Seconds 3
        
        # Test web interface
        try {
            `$response = Invoke-WebRequest -Uri "http://localhost:`$WebPort/api/health" -UseBasicParsing -TimeoutSec 5
            if (`$response.StatusCode -eq 200) {
                Write-Host "Web interface started successfully" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Web interface may not have started properly. Check logs for details."
        }
    }
    
    Write-Host ""
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "Installation path: `$installPath" -ForegroundColor Gray
    Write-Host "Configuration: `$installPath\config\server.conf" -ForegroundColor Gray
    Write-Host "SSH private key: `$installPath\keys\tunnel_key" -ForegroundColor Gray
    Write-Host "Web interface: http://localhost:`$WebPort" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Review configuration: `$installPath\config\server.conf" -ForegroundColor Gray
    Write-Host "2. Distribute SSH private key to clients: `$installPath\keys\tunnel_key" -ForegroundColor Gray
    Write-Host "3. Access web dashboard: http://your-server:`$WebPort" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Error "Installation failed: `$(`$_.Exception.Message)"
    exit 1
}
"@

Set-Content "$packagePath\Install.ps1" -Value $installScript -Encoding UTF8

# Create startup script
$startupScript = @"
# SSH Tunnel Server Startup Script

param(
    [Parameter(Mandatory = `$false)]
    [int]`$Port = 8080
)

`$installPath = "C:\Program Files\SSHTunnelServer"

Write-Host "Starting SSH Tunnel Server..." -ForegroundColor Green
Write-Host "Web interface will be available at: http://localhost:`$Port" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

try {
    & "`$installPath\bin\WebAPI.ps1" -Port `$Port -StaticPath "`$installPath\web"
}
catch {
    Write-Error "Failed to start server: `$(`$_.Exception.Message)"
    exit 1
}
"@

Set-Content "$packagePath\Start-Server.ps1" -Value $startupScript -Encoding UTF8

# Create package README
$packageReadme = @"
# SSH Tunnel Server Package

This package contains the SSH Tunnel Server for managing automatic SSH tunnel clients.

## Installation

1. **Run as Administrator**:
   ```powershell
   .\Install.ps1 -WebPort 8080 -AutoStart
   ```

2. **Access Web Dashboard**:
   Open browser to: http://localhost:8080

3. **Distribute Client Key**:
   Copy `keys\tunnel_key` to client installations

## Starting the Server

```powershell
.\Start-Server.ps1 -Port 8080
```

## Configuration

Edit the configuration file at:
`C:\Program Files\SSHTunnelServer\config\server.conf`

## Client Deployment

1. Access the web dashboard
2. Go to the "Deployment" tab
3. Download client installation packages
4. Deploy to target systems

## Support

See the documentation in the `docs` folder for detailed information.
"@

Set-Content "$packagePath\README.txt" -Value $packageReadme -Encoding UTF8

# Create ZIP package
Write-Host "Creating ZIP package..." -ForegroundColor Yellow

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Use PowerShell 5.0+ Compress-Archive
Compress-Archive -Path "$packagePath\*" -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host ""
Write-Host "Package created successfully!" -ForegroundColor Green
Write-Host "Location: $zipPath" -ForegroundColor Gray
Write-Host "Size: $([Math]::Round((Get-Item $zipPath).Length / 1MB, 2)) MB" -ForegroundColor Gray
Write-Host ""

# Clean up temporary directory
Remove-Item $packagePath -Recurse -Force

Write-Host "Server packaging completed!" -ForegroundColor Cyan

