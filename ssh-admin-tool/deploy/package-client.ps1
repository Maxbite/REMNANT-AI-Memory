# SSH Tunnel Client Packaging Script
# Creates deployment packages for SSH tunnel clients

#Requires -Version 5.1

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\packages",
    
    [Parameter(Mandatory = $false)]
    [string]$Version = "1.0.0",
    
    [Parameter(Mandatory = $false)]
    [string]$ServerHost = "tunnel.company.com",
    
    [Parameter(Mandatory = $false)]
    [int]$ServerPort = 22
)

$ErrorActionPreference = "Stop"

Write-Host "SSH Tunnel Client Packaging Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$packagePath = Join-Path $OutputPath "SSHTunnelClient-$Version"
$zipPath = "$packagePath.zip"

Write-Host "Creating client package..." -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Gray
Write-Host "Output: $packagePath" -ForegroundColor Gray
Write-Host ""

# Create package directory structure
$packageDirs = @(
    "$packagePath\bin",
    "$packagePath\config",
    "$packagePath\keys",
    "$packagePath\logs",
    "$packagePath\docs"
)

foreach ($dir in $packageDirs) {
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
}

# Copy client files
Write-Host "Copying client files..." -ForegroundColor Yellow

# PowerShell modules and scripts
Copy-Item "..\src\client\*" "$packagePath\bin\" -Recurse -Force
Copy-Item "..\src\common\*" "$packagePath\bin\" -Recurse -Force

# Configuration files
Copy-Item "..\config\client.conf.example" "$packagePath\config\" -Force

# Documentation
Copy-Item "..\README.md" "$packagePath\docs\" -Force
Copy-Item "..\docs\deployment-guide.md" "$packagePath\docs\" -Force

# Create installation script
$installScript = @"
# SSH Tunnel Client Installation Script
# Run as Administrator

param(
    [Parameter(Mandatory = `$false)]
    [string]`$ServerHost = "$ServerHost",
    
    [Parameter(Mandatory = `$false)]
    [int]`$ServerPort = $ServerPort,
    
    [Parameter(Mandatory = `$false)]
    [switch]`$AutoStart = `$false
)

`$ErrorActionPreference = "Stop"

Write-Host "Installing SSH Tunnel Client..." -ForegroundColor Green

# Check administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Installation paths
`$installPath = "C:\Program Files\SSHTunnelClient"
`$serviceName = "SSHTunnelClient"

try {
    # Create installation directory
    if (Test-Path `$installPath) {
        Write-Host "Removing existing installation..." -ForegroundColor Yellow
        Stop-Service -Name `$serviceName -ErrorAction SilentlyContinue
        Remove-Item `$installPath -Recurse -Force
    }
    
    New-Item -Path `$installPath -ItemType Directory -Force | Out-Null
    
    # Copy files
    Write-Host "Copying files..." -ForegroundColor Yellow
    Copy-Item ".\bin\*" "`$installPath\bin\" -Recurse -Force
    Copy-Item ".\config\*" "`$installPath\config\" -Recurse -Force
    Copy-Item ".\docs\*" "`$installPath\docs\" -Recurse -Force
    
    # Create directories
    New-Item -Path "`$installPath\logs" -ItemType Directory -Force | Out-Null
    New-Item -Path "`$installPath\keys" -ItemType Directory -Force | Out-Null
    
    # Configure client
    Write-Host "Configuring client..." -ForegroundColor Yellow
    `$configPath = "`$installPath\config\client.conf"
    
    if (Test-Path "`$configPath.example") {
        Copy-Item "`$configPath.example" `$configPath -Force
        
        # Update configuration with provided server details
        `$config = Get-Content `$configPath -Raw
        `$config = `$config -replace "tunnel\.company\.com", `$ServerHost
        `$config = `$config -replace "Port = 22", "Port = `$ServerPort"
        Set-Content `$configPath -Value `$config
    }
    
    # Install Windows service
    Write-Host "Installing Windows service..." -ForegroundColor Yellow
    & "`$installPath\bin\SSHTunnelService.ps1" -Action Install
    
    # Start service if requested
    if (`$AutoStart) {
        Write-Host "Starting service..." -ForegroundColor Yellow
        Start-Service -Name `$serviceName
        
        # Wait for service to start
        Start-Sleep -Seconds 5
        `$service = Get-Service -Name `$serviceName
        
        if (`$service.Status -eq "Running") {
            Write-Host "Service started successfully" -ForegroundColor Green
        } else {
            Write-Warning "Service failed to start. Check logs for details."
        }
    }
    
    Write-Host ""
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "Installation path: `$installPath" -ForegroundColor Gray
    Write-Host "Configuration: `$configPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Copy SSH private key to: `$installPath\keys\tunnel_key" -ForegroundColor Gray
    Write-Host "2. Review configuration: `$configPath" -ForegroundColor Gray
    Write-Host "3. Start service: Start-Service -Name `$serviceName" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Error "Installation failed: `$(`$_.Exception.Message)"
    exit 1
}
"@

Set-Content "$packagePath\Install.ps1" -Value $installScript -Encoding UTF8

# Create uninstall script
$uninstallScript = @"
# SSH Tunnel Client Uninstallation Script
# Run as Administrator

`$ErrorActionPreference = "Stop"

Write-Host "Uninstalling SSH Tunnel Client..." -ForegroundColor Yellow

# Check administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

`$installPath = "C:\Program Files\SSHTunnelClient"
`$serviceName = "SSHTunnelClient"

try {
    # Stop and remove service
    if (Get-Service -Name `$serviceName -ErrorAction SilentlyContinue) {
        Write-Host "Stopping service..." -ForegroundColor Yellow
        Stop-Service -Name `$serviceName -Force
        
        Write-Host "Removing service..." -ForegroundColor Yellow
        sc.exe delete `$serviceName
    }
    
    # Remove installation directory
    if (Test-Path `$installPath) {
        Write-Host "Removing files..." -ForegroundColor Yellow
        Remove-Item `$installPath -Recurse -Force
    }
    
    # Remove event log source
    if ([System.Diagnostics.EventLog]::SourceExists("SSHTunnelClient")) {
        Write-Host "Removing event log source..." -ForegroundColor Yellow
        Remove-EventLog -Source "SSHTunnelClient"
    }
    
    Write-Host ""
    Write-Host "Uninstallation completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Uninstallation failed: `$(`$_.Exception.Message)"
    exit 1
}
"@

Set-Content "$packagePath\Uninstall.ps1" -Value $uninstallScript -Encoding UTF8

# Create README for package
$packageReadme = @"
# SSH Tunnel Client Package

This package contains the SSH Tunnel Client for automatic establishment of reverse SSH tunnels to a parent server.

## Installation

1. **Run as Administrator**:
   ```powershell
   .\Install.ps1 -ServerHost "your-server.domain.com" -AutoStart
   ```

2. **Copy SSH Private Key**:
   Copy the SSH private key to: `C:\Program Files\SSHTunnelClient\keys\tunnel_key`

3. **Verify Installation**:
   ```powershell
   Get-Service -Name "SSHTunnelClient"
   ```

## Configuration

Edit the configuration file at:
`C:\Program Files\SSHTunnelClient\config\client.conf`

## Uninstallation

Run as Administrator:
```powershell
.\Uninstall.ps1
```

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

Write-Host "Client packaging completed!" -ForegroundColor Cyan

