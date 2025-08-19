# SSH Tunnel Client Installation Script
# Network Administrator Tool - Automatic SSH Tunnel Client
# 
# CONSENT AND AUTHORIZATION:
# By running this installation script, you acknowledge and agree that:
# 1. You have administrative authority to install network management tools on this system
# 2. This tool will create outbound SSH connections to designated parent servers
# 3. The tool will establish reverse tunnels for remote network administration
# 4. Installation and usage is authorized by your organization's IT policies
# 5. You understand this tool is for legitimate network administration purposes

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$InstallPath = "C:\Program Files\SSHTunnelClient",
    
    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "SSHTunnelClient",
    
    [Parameter(Mandatory = $false)]
    [string]$ParentServer = $null,
    
    [Parameter(Mandatory = $false)]
    [switch]$Silent = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$AcceptLicense = $false
)

# Installation configuration
$script:InstallConfig = @{
    InstallPath = $InstallPath
    ServiceName = $ServiceName
    ServiceDisplayName = "SSH Tunnel Client Service"
    ServiceDescription = "Automatic SSH reverse tunnel client for network administration"
    ConfigPath = Join-Path $InstallPath "config"
    LogPath = Join-Path $InstallPath "logs"
    BinPath = Join-Path $InstallPath "bin"
}

function Show-LicenseAndConsent {
    if ($Silent -and $AcceptLicense) {
        Write-Host "Silent installation with license acceptance..." -ForegroundColor Green
        return $true
    }
    
    Clear-Host
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "SSH TUNNEL CLIENT - NETWORK ADMINISTRATOR TOOL" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "INSTALLATION CONSENT AND AUTHORIZATION" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This tool creates automatic SSH reverse tunnels for network administration." -ForegroundColor White
    Write-Host "By proceeding with installation, you acknowledge and agree that:" -ForegroundColor White
    Write-Host ""
    Write-Host "✓ You have administrative authority to install this tool" -ForegroundColor Green
    Write-Host "✓ You understand this tool creates outbound SSH connections" -ForegroundColor Green
    Write-Host "✓ Installation is authorized by your organization's IT policies" -ForegroundColor Green
    Write-Host "✓ This tool is for legitimate network administration purposes only" -ForegroundColor Green
    Write-Host "✓ You accept responsibility for proper configuration and usage" -ForegroundColor Green
    Write-Host ""
    Write-Host "TECHNICAL DETAILS:" -ForegroundColor Yellow
    Write-Host "• Creates reverse SSH tunnels to parent servers" -ForegroundColor Gray
    Write-Host "• Enables remote access for network troubleshooting" -ForegroundColor Gray
    Write-Host "• Runs as a Windows service for persistent connectivity" -ForegroundColor Gray
    Write-Host "• Uses standard SSH protocols and authentication" -ForegroundColor Gray
    Write-Host "• Logs all connection attempts and status changes" -ForegroundColor Gray
    Write-Host ""
    Write-Host "INSTALLATION LOCATION: $InstallPath" -ForegroundColor Cyan
    Write-Host ""
    
    if ($Silent) {
        Write-Host "ERROR: Silent installation requires -AcceptLicense parameter" -ForegroundColor Red
        return $false
    }
    
    $response = Read-Host "Do you accept these terms and authorize installation? (Y/N)"
    return ($response -match "^[Yy]")
}

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        throw "PowerShell 5.1 or higher is required"
    }
    Write-Host "✓ PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Green
    
    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator"
    }
    Write-Host "✓ Running as Administrator" -ForegroundColor Green
    
    # Check for SSH client
    try {
        $sshVersion = ssh -V 2>&1
        Write-Host "✓ SSH client available: $sshVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠ SSH client not found - will attempt to install OpenSSH" -ForegroundColor Yellow
        Install-OpenSSHClient
    }
    
    # Check network connectivity
    if (Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet) {
        Write-Host "✓ Network connectivity available" -ForegroundColor Green
    } else {
        Write-Host "⚠ Limited network connectivity detected" -ForegroundColor Yellow
    }
}

function Install-OpenSSHClient {
    Write-Host "Installing OpenSSH Client..." -ForegroundColor Yellow
    
    try {
        # For Windows 10/11 with Windows Features
        if (Get-Command "Get-WindowsCapability" -ErrorAction SilentlyContinue) {
            $sshClient = Get-WindowsCapability -Online | Where-Object Name -like "OpenSSH.Client*"
            if ($sshClient.State -ne "Installed") {
                Add-WindowsCapability -Online -Name $sshClient.Name
                Write-Host "✓ OpenSSH Client installed via Windows Features" -ForegroundColor Green
            }
        }
        # Alternative: Download from GitHub releases
        else {
            Write-Host "Please install OpenSSH Client manually from:" -ForegroundColor Yellow
            Write-Host "https://github.com/PowerShell/Win32-OpenSSH/releases" -ForegroundColor Cyan
            throw "OpenSSH Client installation required"
        }
    }
    catch {
        throw "Failed to install OpenSSH Client: $($_.Exception.Message)"
    }
}

function New-InstallationDirectories {
    Write-Host "Creating installation directories..." -ForegroundColor Yellow
    
    foreach ($path in @($script:InstallConfig.InstallPath, $script:InstallConfig.ConfigPath, $script:InstallConfig.LogPath, $script:InstallConfig.BinPath)) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            Write-Host "✓ Created: $path" -ForegroundColor Green
        } else {
            Write-Host "✓ Exists: $path" -ForegroundColor Green
        }
    }
}

function Copy-ClientFiles {
    Write-Host "Installing client files..." -ForegroundColor Yellow
    
    $sourceFiles = @{
        "SSHTunnelClient.psm1" = Join-Path $script:InstallConfig.BinPath "SSHTunnelClient.psm1"
        "SSHTunnelService.ps1" = Join-Path $script:InstallConfig.BinPath "SSHTunnelService.ps1"
        "..\common\CommonFunctions.ps1" = Join-Path $script:InstallConfig.BinPath "CommonFunctions.ps1"
    }
    
    foreach ($source in $sourceFiles.Keys) {
        $destination = $sourceFiles[$source]
        $sourcePath = Join-Path $PSScriptRoot $source
        
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $destination -Force
            Write-Host "✓ Copied: $(Split-Path $destination -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "⚠ Source file not found: $source" -ForegroundColor Yellow
        }
    }
}

function New-ClientConfiguration {
    Write-Host "Creating client configuration..." -ForegroundColor Yellow
    
    $configFile = Join-Path $script:InstallConfig.ConfigPath "client.conf"
    
    # Generate unique client ID
    $clientId = [System.Guid]::NewGuid().ToString()
    
    # Default configuration
    $config = @{
        ClientId = $clientId
        ParentServers = @()
        Username = "tunnel-client"
        PrivateKeyPath = "$env:USERPROFILE\.ssh\id_rsa"
        TunnelPorts = @{
            SSH = 22
            RDP = 3389
            HTTP = 80
            HTTPS = 443
        }
        AutoRestart = $true
        ReconnectInterval = 30
        HealthCheckInterval = 60
        EnableNetworkScan = $false
        LogLevel = "Info"
    }
    
    # Add parent server if provided
    if ($ParentServer) {
        $config.ParentServers += @{
            Host = $ParentServer
            Port = 22
            Priority = 1
        }
        Write-Host "✓ Added parent server: $ParentServer" -ForegroundColor Green
    } else {
        # Add example servers
        $config.ParentServers += @(
            @{ Host = "tunnel.company.com"; Port = 22; Priority = 1 }
            @{ Host = "backup.company.com"; Port = 443; Priority = 2 }
        )
        Write-Host "⚠ Using example parent servers - please update configuration" -ForegroundColor Yellow
    }
    
    # Save configuration
    $config | Export-Clixml -Path $configFile -Force
    Write-Host "✓ Configuration saved: $configFile" -ForegroundColor Green
    
    return $configFile
}

function Install-WindowsService {
    Write-Host "Installing Windows service..." -ForegroundColor Yellow
    
    $servicePath = Join-Path $script:InstallConfig.BinPath "SSHTunnelService.ps1"
    $serviceCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$servicePath`""
    
    try {
        # Remove existing service if it exists
        $existingService = Get-Service -Name $script:InstallConfig.ServiceName -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-Host "Removing existing service..." -ForegroundColor Yellow
            Stop-Service -Name $script:InstallConfig.ServiceName -Force -ErrorAction SilentlyContinue
            sc.exe delete $script:InstallConfig.ServiceName | Out-Null
        }
        
        # Create new service
        New-Service -Name $script:InstallConfig.ServiceName -BinaryPathName $serviceCommand -DisplayName $script:InstallConfig.ServiceDisplayName -Description $script:InstallConfig.ServiceDescription -StartupType Automatic
        
        Write-Host "✓ Windows service installed: $($script:InstallConfig.ServiceName)" -ForegroundColor Green
        
        # Set service to restart on failure
        sc.exe failure $script:InstallConfig.ServiceName reset= 86400 actions= restart/5000/restart/5000/restart/5000 | Out-Null
        
        return $true
    }
    catch {
        Write-Host "✗ Failed to install Windows service: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Set-FirewallRules {
    Write-Host "Configuring firewall rules..." -ForegroundColor Yellow
    
    try {
        # Allow outbound SSH connections
        $ruleName = "SSH Tunnel Client - Outbound"
        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        
        if (-not $existingRule) {
            New-NetFirewallRule -DisplayName $ruleName -Direction Outbound -Protocol TCP -LocalPort Any -RemotePort 22,443,80 -Action Allow -Profile Any
            Write-Host "✓ Firewall rule created: $ruleName" -ForegroundColor Green
        } else {
            Write-Host "✓ Firewall rule exists: $ruleName" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "⚠ Could not configure firewall rules: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Please ensure outbound SSH connections are allowed" -ForegroundColor Yellow
    }
}

function New-SSHKeyPair {
    Write-Host "Setting up SSH authentication..." -ForegroundColor Yellow
    
    $sshDir = "$env:USERPROFILE\.ssh"
    $privateKeyPath = Join-Path $sshDir "id_rsa"
    $publicKeyPath = Join-Path $sshDir "id_rsa.pub"
    
    # Create .ssh directory if it doesn't exist
    if (-not (Test-Path $sshDir)) {
        New-Item -Path $sshDir -ItemType Directory -Force | Out-Null
    }
    
    # Generate SSH key pair if it doesn't exist
    if (-not (Test-Path $privateKeyPath)) {
        Write-Host "Generating SSH key pair..." -ForegroundColor Yellow
        $keyComment = "SSH-Tunnel-Client-$env:COMPUTERNAME"
        
        try {
            ssh-keygen -t rsa -b 4096 -f $privateKeyPath -N '""' -C $keyComment
            Write-Host "✓ SSH key pair generated" -ForegroundColor Green
            Write-Host "  Private key: $privateKeyPath" -ForegroundColor Gray
            Write-Host "  Public key: $publicKeyPath" -ForegroundColor Gray
        }
        catch {
            Write-Host "⚠ Could not generate SSH key pair: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  Please generate manually: ssh-keygen -t rsa -b 4096" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✓ SSH key pair already exists" -ForegroundColor Green
    }
    
    # Display public key for server configuration
    if (Test-Path $publicKeyPath) {
        Write-Host ""
        Write-Host "PUBLIC KEY FOR SERVER CONFIGURATION:" -ForegroundColor Cyan
        Write-Host "=" * 60 -ForegroundColor Cyan
        Get-Content $publicKeyPath | Write-Host -ForegroundColor White
        Write-Host "=" * 60 -ForegroundColor Cyan
        Write-Host "Copy this public key to the parent server's authorized_keys file" -ForegroundColor Yellow
        Write-Host ""
    }
}

function Show-PostInstallInstructions {
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host "INSTALLATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Green
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. CONFIGURE PARENT SERVER:" -ForegroundColor Cyan
    Write-Host "   • Copy the public key above to parent server" -ForegroundColor White
    Write-Host "   • Add to ~/.ssh/authorized_keys for tunnel-client user" -ForegroundColor White
    Write-Host "   • Configure SSH server for reverse tunneling" -ForegroundColor White
    Write-Host ""
    Write-Host "2. UPDATE CLIENT CONFIGURATION:" -ForegroundColor Cyan
    Write-Host "   • Edit: $($script:InstallConfig.ConfigPath)\client.conf" -ForegroundColor White
    Write-Host "   • Update ParentServers with actual server addresses" -ForegroundColor White
    Write-Host "   • Adjust tunnel ports as needed" -ForegroundColor White
    Write-Host ""
    Write-Host "3. START THE SERVICE:" -ForegroundColor Cyan
    Write-Host "   • Start-Service -Name '$($script:InstallConfig.ServiceName)'" -ForegroundColor White
    Write-Host "   • Or use Services.msc GUI" -ForegroundColor White
    Write-Host ""
    Write-Host "4. MONITOR OPERATION:" -ForegroundColor Cyan
    Write-Host "   • Check logs: $($script:InstallConfig.LogPath)" -ForegroundColor White
    Write-Host "   • Monitor service status" -ForegroundColor White
    Write-Host "   • Verify tunnel connectivity" -ForegroundColor White
    Write-Host ""
    Write-Host "MANAGEMENT COMMANDS:" -ForegroundColor Yellow
    Write-Host "Start Service:  Start-Service -Name '$($script:InstallConfig.ServiceName)'" -ForegroundColor Gray
    Write-Host "Stop Service:   Stop-Service -Name '$($script:InstallConfig.ServiceName)'" -ForegroundColor Gray
    Write-Host "Check Status:   Get-Service -Name '$($script:InstallConfig.ServiceName)'" -ForegroundColor Gray
    Write-Host "View Logs:      Get-Content '$($script:InstallConfig.LogPath)\client.log' -Tail 50" -ForegroundColor Gray
    Write-Host ""
}

# Main installation process
try {
    Write-Host "SSH Tunnel Client Installation" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host ""
    
    # Show license and get consent
    if (-not (Show-LicenseAndConsent)) {
        Write-Host "Installation cancelled by user." -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "Starting installation..." -ForegroundColor Green
    Write-Host ""
    
    # Run installation steps
    Test-Prerequisites
    New-InstallationDirectories
    Copy-ClientFiles
    $configFile = New-ClientConfiguration
    Install-WindowsService
    Set-FirewallRules
    New-SSHKeyPair
    
    # Show completion message
    Show-PostInstallInstructions
    
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    
    if (-not $Silent) {
        $startNow = Read-Host "Would you like to start the service now? (Y/N)"
        if ($startNow -match "^[Yy]") {
            Start-Service -Name $script:InstallConfig.ServiceName
            Write-Host "Service started successfully!" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host ""
    Write-Host "INSTALLATION FAILED" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error message above and try again." -ForegroundColor Yellow
    Write-Host "For support, contact your network administrator." -ForegroundColor Yellow
    exit 1
}

