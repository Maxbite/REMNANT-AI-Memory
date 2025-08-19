# SSH Tunnel Client Windows Service
# Runs the SSH tunnel client as a Windows service for persistent connectivity

#Requires -Version 5.1

param(
    [Parameter(Mandatory = $false)]
    [string]$Action = "Start"
)

# Service configuration
$script:ServiceConfig = @{
    Name = "SSHTunnelClient"
    DisplayName = "SSH Tunnel Client Service"
    InstallPath = "C:\Program Files\SSHTunnelClient"
    LogPath = "C:\Program Files\SSHTunnelClient\logs\service.log"
    ConfigPath = "C:\Program Files\SSHTunnelClient\config\client.conf"
    ModulePath = "C:\Program Files\SSHTunnelClient\bin\SSHTunnelClient.psm1"
    PidFile = "C:\Program Files\SSHTunnelClient\service.pid"
}

# Import required modules
try {
    Import-Module $script:ServiceConfig.ModulePath -Force
    . (Join-Path (Split-Path $script:ServiceConfig.ModulePath -Parent) "CommonFunctions.ps1")
}
catch {
    Write-EventLog -LogName Application -Source "SSHTunnelClient" -EventId 1001 -EntryType Error -Message "Failed to import modules: $($_.Exception.Message)"
    exit 1
}

<#
.SYNOPSIS
    Writes service events to Windows Event Log
.DESCRIPTION
    Logs service events to both file and Windows Event Log
.PARAMETER Message
    Event message
.PARAMETER Level
    Event level (Info, Warning, Error)
.PARAMETER EventId
    Windows Event ID
#>
function Write-ServiceLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [int]$EventId = 1000
    )
    
    # Write to file log
    Write-Log $Message -Level $Level -LogPath $script:ServiceConfig.LogPath
    
    # Write to Windows Event Log
    try {
        $entryType = switch ($Level) {
            "Info" { "Information" }
            "Warning" { "Warning" }
            "Error" { "Error" }
            default { "Information" }
        }
        
        # Ensure event source exists
        if (-not [System.Diagnostics.EventLog]::SourceExists("SSHTunnelClient")) {
            New-EventLog -LogName Application -Source "SSHTunnelClient"
        }
        
        Write-EventLog -LogName Application -Source "SSHTunnelClient" -EventId $EventId -EntryType $entryType -Message $Message
    }
    catch {
        # If event log fails, just continue with file logging
        Write-Log "Failed to write to event log: $($_.Exception.Message)" -Level Warning -LogPath $script:ServiceConfig.LogPath
    }
}

<#
.SYNOPSIS
    Starts the SSH tunnel client service
.DESCRIPTION
    Main service entry point that initializes and runs the tunnel client
#>
function Start-ServiceMain {
    try {
        Write-ServiceLog "SSH Tunnel Client Service starting..." -Level Info -EventId 1000
        
        # Write PID file
        $processId = $PID
        Set-Content -Path $script:ServiceConfig.PidFile -Value $processId
        
        # Initialize the tunnel client
        Initialize-SSHTunnelClient -ConfigFile $script:ServiceConfig.ConfigPath
        
        Write-ServiceLog "SSH Tunnel Client Service initialized successfully" -Level Info -EventId 1001
        
        # Start the main service loop
        Start-ServiceLoop
    }
    catch {
        Write-ServiceLog "Failed to start SSH Tunnel Client Service: $($_.Exception.Message)" -Level Error -EventId 1002
        throw
    }
    finally {
        # Clean up PID file
        if (Test-Path $script:ServiceConfig.PidFile) {
            Remove-Item $script:ServiceConfig.PidFile -Force -ErrorAction SilentlyContinue
        }
    }
}

<#
.SYNOPSIS
    Main service loop that manages tunnel connections
.DESCRIPTION
    Continuously monitors and maintains SSH tunnel connections
#>
function Start-ServiceLoop {
    Write-ServiceLog "Starting service main loop..." -Level Info -EventId 1003
    
    $lastConfigCheck = Get-Date
    $configCheckInterval = 300  # Check config every 5 minutes
    
    try {
        # Start the tunnel client service
        Start-SSHTunnelClientService
    }
    catch {
        Write-ServiceLog "Service loop terminated: $($_.Exception.Message)" -Level Error -EventId 1004
        throw
    }
}

<#
.SYNOPSIS
    Stops the SSH tunnel client service
.DESCRIPTION
    Gracefully shuts down all tunnel connections and stops the service
#>
function Stop-ServiceMain {
    try {
        Write-ServiceLog "SSH Tunnel Client Service stopping..." -Level Info -EventId 1010
        
        # Stop all active tunnels
        if ($script:TunnelProcesses) {
            foreach ($tunnelId in $script:TunnelProcesses.Keys) {
                try {
                    Stop-SSHTunnel -TunnelId $tunnelId
                    Write-ServiceLog "Stopped tunnel: $tunnelId" -Level Info -EventId 1011
                }
                catch {
                    Write-ServiceLog "Error stopping tunnel $tunnelId`: $($_.Exception.Message)" -Level Warning -EventId 1012
                }
            }
        }
        
        Write-ServiceLog "SSH Tunnel Client Service stopped successfully" -Level Info -EventId 1013
    }
    catch {
        Write-ServiceLog "Error during service shutdown: $($_.Exception.Message)" -Level Error -EventId 1014
    }
}

<#
.SYNOPSIS
    Handles service control signals
.DESCRIPTION
    Processes Windows service control commands
.PARAMETER Signal
    Service control signal (Stop, Pause, Continue)
#>
function Handle-ServiceControl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Signal
    )
    
    switch ($Signal.ToUpper()) {
        "STOP" {
            Write-ServiceLog "Received STOP signal" -Level Info -EventId 1020
            Stop-ServiceMain
            exit 0
        }
        "PAUSE" {
            Write-ServiceLog "Received PAUSE signal" -Level Info -EventId 1021
            # Implement pause logic if needed
        }
        "CONTINUE" {
            Write-ServiceLog "Received CONTINUE signal" -Level Info -EventId 1022
            # Implement continue logic if needed
        }
        default {
            Write-ServiceLog "Received unknown signal: $Signal" -Level Warning -EventId 1023
        }
    }
}

<#
.SYNOPSIS
    Monitors service health and restarts if necessary
.DESCRIPTION
    Watchdog function to ensure service reliability
#>
function Start-ServiceWatchdog {
    $watchdogInterval = 60  # Check every minute
    
    while ($true) {
        try {
            # Check if main service is still running
            $pidFile = $script:ServiceConfig.PidFile
            if (Test-Path $pidFile) {
                $servicePid = Get-Content $pidFile -ErrorAction SilentlyContinue
                if ($servicePid) {
                    $process = Get-Process -Id $servicePid -ErrorAction SilentlyContinue
                    if (-not $process) {
                        Write-ServiceLog "Main service process died, restarting..." -Level Warning -EventId 1030
                        Start-ServiceMain
                    }
                }
            }
            
            # Check tunnel health
            if ($script:TunnelProcesses) {
                $activeTunnels = 0
                foreach ($tunnelId in $script:TunnelProcesses.Keys) {
                    $process = $script:TunnelProcesses[$tunnelId]
                    if ($process -and -not $process.HasExited) {
                        $activeTunnels++
                    }
                }
                
                if ($activeTunnels -eq 0) {
                    Write-ServiceLog "No active tunnels detected, checking configuration..." -Level Warning -EventId 1031
                }
            }
            
            Start-Sleep -Seconds $watchdogInterval
        }
        catch {
            Write-ServiceLog "Watchdog error: $($_.Exception.Message)" -Level Error -EventId 1032
            Start-Sleep -Seconds $watchdogInterval
        }
    }
}

<#
.SYNOPSIS
    Installs the service event log source
.DESCRIPTION
    Creates the Windows Event Log source for the service
#>
function Install-EventLogSource {
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("SSHTunnelClient")) {
            New-EventLog -LogName Application -Source "SSHTunnelClient"
            Write-Host "Event log source 'SSHTunnelClient' created successfully" -ForegroundColor Green
        } else {
            Write-Host "Event log source 'SSHTunnelClient' already exists" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "Failed to create event log source: $($_.Exception.Message)"
    }
}

# Main service entry point
switch ($Action.ToUpper()) {
    "START" {
        try {
            # Ensure log directory exists
            $logDir = Split-Path $script:ServiceConfig.LogPath -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            # Install event log source if needed
            Install-EventLogSource
            
            # Start the main service
            Start-ServiceMain
        }
        catch {
            Write-ServiceLog "Service startup failed: $($_.Exception.Message)" -Level Error -EventId 1099
            exit 1
        }
    }
    
    "STOP" {
        Stop-ServiceMain
        exit 0
    }
    
    "INSTALL" {
        Install-EventLogSource
        Write-Host "Service components installed successfully" -ForegroundColor Green
        exit 0
    }
    
    "TEST" {
        try {
            Write-Host "Testing SSH Tunnel Client Service..." -ForegroundColor Cyan
            
            # Test module import
            Import-Module $script:ServiceConfig.ModulePath -Force
            Write-Host "✓ Module import successful" -ForegroundColor Green
            
            # Test configuration
            if (Test-Path $script:ServiceConfig.ConfigPath) {
                $config = Import-ConfigFile -Path $script:ServiceConfig.ConfigPath
                Write-Host "✓ Configuration file loaded" -ForegroundColor Green
            } else {
                Write-Host "⚠ Configuration file not found: $($script:ServiceConfig.ConfigPath)" -ForegroundColor Yellow
            }
            
            # Test SSH client
            if (Test-SSHClientAvailable) {
                Write-Host "✓ SSH client available" -ForegroundColor Green
            } else {
                Write-Host "✗ SSH client not available" -ForegroundColor Red
            }
            
            # Test network connectivity
            if (Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet) {
                Write-Host "✓ Network connectivity available" -ForegroundColor Green
            } else {
                Write-Host "⚠ Limited network connectivity" -ForegroundColor Yellow
            }
            
            Write-Host "Service test completed" -ForegroundColor Cyan
        }
        catch {
            Write-Host "Service test failed: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
        exit 0
    }
    
    default {
        Write-Host "Usage: SSHTunnelService.ps1 [-Action <Start|Stop|Install|Test>]" -ForegroundColor Yellow
        Write-Host "  Start   - Start the service (default)"
        Write-Host "  Stop    - Stop the service"
        Write-Host "  Install - Install event log source"
        Write-Host "  Test    - Test service components"
        exit 1
    }
}

