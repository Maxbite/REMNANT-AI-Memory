# SSH Tunnel Client Module
# Provides automatic SSH reverse tunnel functionality for network administrators

#Requires -Version 5.1

# Module variables
$script:ModuleRoot = $PSScriptRoot
$script:ConfigPath = Join-Path $ModuleRoot "..\..\config\client.conf"
$script:LogPath = Join-Path $ModuleRoot "..\..\logs\client.log"
$script:TunnelProcesses = @{}
$script:ClientConfig = $null

# Import common functions
. (Join-Path $ModuleRoot "..\common\CommonFunctions.ps1")

<#
.SYNOPSIS
    Initializes the SSH tunnel client with configuration
.DESCRIPTION
    Loads configuration, sets up logging, and prepares the client for tunnel operations
.PARAMETER ConfigFile
    Path to the client configuration file
.EXAMPLE
    Initialize-SSHTunnelClient -ConfigFile "C:\config\client.conf"
#>
function Initialize-SSHTunnelClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigFile = $script:ConfigPath
    )
    
    try {
        Write-Log "Initializing SSH Tunnel Client..." -Level Info
        
        # Load configuration
        if (Test-Path $ConfigFile) {
            $script:ClientConfig = Import-PowerShellDataFile $ConfigFile
            Write-Log "Configuration loaded from: $ConfigFile" -Level Info
        } else {
            Write-Log "Configuration file not found: $ConfigFile" -Level Warning
            $script:ClientConfig = Get-DefaultClientConfig
            Write-Log "Using default configuration" -Level Info
        }
        
        # Ensure log directory exists
        $logDir = Split-Path $script:LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        # Test SSH client availability
        if (-not (Test-SSHClientAvailable)) {
            throw "SSH client is not available. Please install OpenSSH client."
        }
        
        Write-Log "SSH Tunnel Client initialized successfully" -Level Info
        return $true
    }
    catch {
        Write-Log "Failed to initialize SSH Tunnel Client: $($_.Exception.Message)" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Establishes a reverse SSH tunnel to the parent server
.DESCRIPTION
    Creates a persistent reverse SSH tunnel connection to allow remote access
.PARAMETER ServerHost
    The parent server hostname or IP address
.PARAMETER ServerPort
    The SSH port on the parent server (default: 22)
.PARAMETER Username
    Username for SSH authentication
.PARAMETER LocalPort
    Local port to forward (default: 22 for SSH)
.PARAMETER RemotePort
    Remote port on the parent server to bind to
.EXAMPLE
    Start-SSHTunnel -ServerHost "parent.company.com" -Username "tunnel-client" -RemotePort 10022
#>
function Start-SSHTunnel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerHost,
        
        [Parameter(Mandatory = $false)]
        [int]$ServerPort = 22,
        
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $false)]
        [int]$LocalPort = 22,
        
        [Parameter(Mandatory = $true)]
        [int]$RemotePort,
        
        [Parameter(Mandatory = $false)]
        [string]$PrivateKeyPath = $null
    )
    
    try {
        $tunnelId = "$ServerHost`:$RemotePort->localhost:$LocalPort"
        Write-Log "Starting SSH tunnel: $tunnelId" -Level Info
        
        # Check if tunnel already exists
        if ($script:TunnelProcesses.ContainsKey($tunnelId)) {
            $process = $script:TunnelProcesses[$tunnelId]
            if (-not $process.HasExited) {
                Write-Log "Tunnel already running: $tunnelId" -Level Warning
                return $process
            } else {
                $script:TunnelProcesses.Remove($tunnelId)
            }
        }
        
        # Build SSH command
        $sshArgs = @(
            "-N"  # Don't execute remote command
            "-R", "$RemotePort`:localhost:$LocalPort"  # Reverse tunnel
            "-p", $ServerPort
            "-o", "StrictHostKeyChecking=no"
            "-o", "UserKnownHostsFile=/dev/null"
            "-o", "ServerAliveInterval=30"
            "-o", "ServerAliveCountMax=3"
            "-o", "ExitOnForwardFailure=yes"
        )
        
        # Add private key if specified
        if ($PrivateKeyPath -and (Test-Path $PrivateKeyPath)) {
            $sshArgs += @("-i", $PrivateKeyPath)
        }
        
        # Add user and host
        $sshArgs += "$Username@$ServerHost"
        
        Write-Log "SSH command: ssh $($sshArgs -join ' ')" -Level Debug
        
        # Start SSH process
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "ssh"
        $processInfo.Arguments = $sshArgs -join " "
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        # Set up event handlers for output
        $process.add_OutputDataReceived({
            param($sender, $e)
            if ($e.Data) {
                Write-Log "SSH Output: $($e.Data)" -Level Debug
            }
        })
        
        $process.add_ErrorDataReceived({
            param($sender, $e)
            if ($e.Data) {
                Write-Log "SSH Error: $($e.Data)" -Level Warning
            }
        })
        
        # Start the process
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        
        # Wait a moment to check if the process started successfully
        Start-Sleep -Seconds 2
        
        if ($process.HasExited) {
            throw "SSH tunnel process exited immediately with code: $($process.ExitCode)"
        }
        
        # Store the process
        $script:TunnelProcesses[$tunnelId] = $process
        
        Write-Log "SSH tunnel started successfully: $tunnelId (PID: $($process.Id))" -Level Info
        return $process
    }
    catch {
        Write-Log "Failed to start SSH tunnel: $($_.Exception.Message)" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Stops a running SSH tunnel
.DESCRIPTION
    Gracefully terminates an SSH tunnel process
.PARAMETER TunnelId
    The tunnel identifier (ServerHost:RemotePort->localhost:LocalPort)
.EXAMPLE
    Stop-SSHTunnel -TunnelId "parent.company.com:10022->localhost:22"
#>
function Stop-SSHTunnel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TunnelId
    )
    
    try {
        if (-not $script:TunnelProcesses.ContainsKey($TunnelId)) {
            Write-Log "Tunnel not found: $TunnelId" -Level Warning
            return
        }
        
        $process = $script:TunnelProcesses[$TunnelId]
        
        if ($process.HasExited) {
            Write-Log "Tunnel already stopped: $TunnelId" -Level Info
            $script:TunnelProcesses.Remove($TunnelId)
            return
        }
        
        Write-Log "Stopping SSH tunnel: $TunnelId" -Level Info
        
        # Try graceful termination first
        $process.CloseMainWindow()
        
        # Wait for graceful exit
        if (-not $process.WaitForExit(5000)) {
            Write-Log "Forcefully terminating tunnel: $TunnelId" -Level Warning
            $process.Kill()
            $process.WaitForExit(2000)
        }
        
        $script:TunnelProcesses.Remove($TunnelId)
        Write-Log "SSH tunnel stopped: $TunnelId" -Level Info
    }
    catch {
        Write-Log "Error stopping SSH tunnel: $($_.Exception.Message)" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Monitors tunnel health and automatically reconnects if needed
.DESCRIPTION
    Continuously monitors active tunnels and restarts them if they fail
.PARAMETER IntervalSeconds
    How often to check tunnel health (default: 30 seconds)
.EXAMPLE
    Start-TunnelMonitoring -IntervalSeconds 60
#>
function Start-TunnelMonitoring {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$IntervalSeconds = 30
    )
    
    Write-Log "Starting tunnel monitoring (interval: $IntervalSeconds seconds)" -Level Info
    
    while ($true) {
        try {
            $deadTunnels = @()
            
            foreach ($tunnelId in $script:TunnelProcesses.Keys) {
                $process = $script:TunnelProcesses[$tunnelId]
                
                if ($process.HasExited) {
                    Write-Log "Tunnel died: $tunnelId (Exit Code: $($process.ExitCode))" -Level Warning
                    $deadTunnels += $tunnelId
                }
            }
            
            # Remove dead tunnels and attempt restart
            foreach ($tunnelId in $deadTunnels) {
                $script:TunnelProcesses.Remove($tunnelId)
                
                # Attempt to restart tunnel if auto-restart is enabled
                if ($script:ClientConfig.AutoRestart) {
                    Write-Log "Attempting to restart tunnel: $tunnelId" -Level Info
                    try {
                        # Parse tunnel ID to extract connection details
                        if ($tunnelId -match "^(.+):(\d+)->localhost:(\d+)$") {
                            $serverHost = $matches[1]
                            $remotePort = [int]$matches[2]
                            $localPort = [int]$matches[3]
                            
                            # Find server config
                            $serverConfig = $script:ClientConfig.ParentServers | Where-Object { $_.Host -eq $serverHost }
                            if ($serverConfig) {
                                Start-Sleep -Seconds 5  # Brief delay before restart
                                Start-SSHTunnel -ServerHost $serverHost -ServerPort $serverConfig.Port -Username $script:ClientConfig.Username -LocalPort $localPort -RemotePort $remotePort -PrivateKeyPath $script:ClientConfig.PrivateKeyPath
                            }
                        }
                    }
                    catch {
                        Write-Log "Failed to restart tunnel $tunnelId`: $($_.Exception.Message)" -Level Error
                    }
                }
            }
            
            Start-Sleep -Seconds $IntervalSeconds
        }
        catch {
            Write-Log "Error in tunnel monitoring: $($_.Exception.Message)" -Level Error
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
}

<#
.SYNOPSIS
    Discovers parent servers on the network
.DESCRIPTION
    Uses various methods to discover available parent servers
.EXAMPLE
    $servers = Find-ParentServers
#>
function Find-ParentServers {
    [CmdletBinding()]
    param()
    
    Write-Log "Discovering parent servers..." -Level Info
    $discoveredServers = @()
    
    try {
        # Method 1: DNS SRV record lookup
        try {
            $srvRecords = Resolve-DnsName -Name "_ssh-tunnel._tcp.$($env:USERDNSDOMAIN)" -Type SRV -ErrorAction SilentlyContinue
            foreach ($record in $srvRecords) {
                $discoveredServers += @{
                    Host = $record.NameTarget
                    Port = $record.Port
                    Priority = $record.Priority
                    Method = "DNS-SRV"
                }
            }
        }
        catch {
            Write-Log "DNS SRV lookup failed: $($_.Exception.Message)" -Level Debug
        }
        
        # Method 2: Configuration file servers
        if ($script:ClientConfig.ParentServers) {
            foreach ($server in $script:ClientConfig.ParentServers) {
                $discoveredServers += @{
                    Host = $server.Host
                    Port = $server.Port
                    Priority = $server.Priority
                    Method = "Config"
                }
            }
        }
        
        # Method 3: Network scan for SSH services (limited scope)
        if ($script:ClientConfig.EnableNetworkScan) {
            $networkRange = Get-LocalNetworkRange
            $sshHosts = Find-SSHHosts -NetworkRange $networkRange
            foreach ($host in $sshHosts) {
                $discoveredServers += @{
                    Host = $host.IP
                    Port = 22
                    Priority = 100
                    Method = "NetworkScan"
                }
            }
        }
        
        # Sort by priority and test connectivity
        $discoveredServers = $discoveredServers | Sort-Object Priority
        $availableServers = @()
        
        foreach ($server in $discoveredServers) {
            if (Test-SSHConnectivity -Host $server.Host -Port $server.Port) {
                $availableServers += $server
                Write-Log "Found available parent server: $($server.Host):$($server.Port) (via $($server.Method))" -Level Info
            }
        }
        
        return $availableServers
    }
    catch {
        Write-Log "Error discovering parent servers: $($_.Exception.Message)" -Level Error
        return @()
    }
}

<#
.SYNOPSIS
    Tests SSH connectivity to a host
.DESCRIPTION
    Verifies that SSH service is available on the specified host and port
.PARAMETER Host
    Target hostname or IP address
.PARAMETER Port
    SSH port (default: 22)
.EXAMPLE
    Test-SSHConnectivity -Host "server.company.com" -Port 22
#>
function Test-SSHConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Host,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 22
    )
    
    try {
        $result = Test-NetConnection -ComputerName $Host -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
        return $result
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Gets the default client configuration
.DESCRIPTION
    Returns a default configuration object for the SSH tunnel client
.EXAMPLE
    $config = Get-DefaultClientConfig
#>
function Get-DefaultClientConfig {
    return @{
        ClientId = [System.Guid]::NewGuid().ToString()
        ParentServers = @(
            @{ Host = "tunnel.company.com"; Port = 22; Priority = 1 }
            @{ Host = "backup.company.com"; Port = 443; Priority = 2 }
        )
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
}

<#
.SYNOPSIS
    Starts the SSH tunnel client service
.DESCRIPTION
    Main entry point for the SSH tunnel client service
.EXAMPLE
    Start-SSHTunnelClientService
#>
function Start-SSHTunnelClientService {
    [CmdletBinding()]
    param()
    
    try {
        Write-Log "Starting SSH Tunnel Client Service..." -Level Info
        
        # Initialize client
        Initialize-SSHTunnelClient
        
        # Discover parent servers
        $parentServers = Find-ParentServers
        
        if ($parentServers.Count -eq 0) {
            throw "No parent servers found"
        }
        
        # Establish tunnels to the primary server
        $primaryServer = $parentServers[0]
        Write-Log "Connecting to primary server: $($primaryServer.Host):$($primaryServer.Port)" -Level Info
        
        # Start tunnels for configured ports
        foreach ($portName in $script:ClientConfig.TunnelPorts.Keys) {
            $localPort = $script:ClientConfig.TunnelPorts[$portName]
            $remotePort = 10000 + $localPort  # Simple port mapping strategy
            
            try {
                Start-SSHTunnel -ServerHost $primaryServer.Host -ServerPort $primaryServer.Port -Username $script:ClientConfig.Username -LocalPort $localPort -RemotePort $remotePort -PrivateKeyPath $script:ClientConfig.PrivateKeyPath
            }
            catch {
                Write-Log "Failed to start tunnel for $portName (port $localPort): $($_.Exception.Message)" -Level Warning
            }
        }
        
        # Start monitoring
        Start-TunnelMonitoring -IntervalSeconds $script:ClientConfig.HealthCheckInterval
    }
    catch {
        Write-Log "Failed to start SSH Tunnel Client Service: $($_.Exception.Message)" -Level Error
        throw
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-SSHTunnelClient',
    'Start-SSHTunnel',
    'Stop-SSHTunnel',
    'Start-TunnelMonitoring',
    'Find-ParentServers',
    'Test-SSHConnectivity',
    'Get-DefaultClientConfig',
    'Start-SSHTunnelClientService'
)

