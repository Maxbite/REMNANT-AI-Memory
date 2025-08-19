# SSH Tunnel Server Management Module
# Provides centralized management for SSH tunnel clients

#Requires -Version 5.1

# Module variables
$script:ModuleRoot = $PSScriptRoot
$script:ConfigPath = Join-Path $ModuleRoot "..\..\config\server.conf"
$script:LogPath = Join-Path $ModuleRoot "..\..\logs\server.log"
$script:ClientDatabase = Join-Path $ModuleRoot "..\..\data\clients.json"
$script:ServerConfig = $null
$script:ConnectedClients = @{}

# Import common functions
. (Join-Path $ModuleRoot "..\common\CommonFunctions.ps1")

<#
.SYNOPSIS
    Initializes the SSH tunnel server
.DESCRIPTION
    Loads configuration and prepares the server for client management
.PARAMETER ConfigFile
    Path to the server configuration file
.EXAMPLE
    Initialize-SSHTunnelServer -ConfigFile "C:\config\server.conf"
#>
function Initialize-SSHTunnelServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigFile = $script:ConfigPath
    )
    
    try {
        Write-Log "Initializing SSH Tunnel Server..." -Level Info -LogPath $script:LogPath
        
        # Load configuration
        if (Test-Path $ConfigFile) {
            $script:ServerConfig = Import-ConfigFile -Path $ConfigFile
            Write-Log "Configuration loaded from: $ConfigFile" -Level Info -LogPath $script:LogPath
        } else {
            Write-Log "Configuration file not found: $ConfigFile" -Level Warning -LogPath $script:LogPath
            $script:ServerConfig = Get-DefaultServerConfig
            Write-Log "Using default configuration" -Level Info -LogPath $script:LogPath
        }
        
        # Ensure required directories exist
        $requiredDirs = @(
            (Split-Path $script:LogPath -Parent),
            (Split-Path $script:ClientDatabase -Parent),
            $script:ServerConfig.WebInterface.StaticPath
        )
        
        foreach ($dir in $requiredDirs) {
            if ($dir -and -not (Test-Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
            }
        }
        
        # Initialize client database
        Initialize-ClientDatabase
        
        # Load existing client data
        Load-ClientDatabase
        
        Write-Log "SSH Tunnel Server initialized successfully" -Level Info -LogPath $script:LogPath
        return $true
    }
    catch {
        Write-Log "Failed to initialize SSH Tunnel Server: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        throw
    }
}

<#
.SYNOPSIS
    Registers a new tunnel client
.DESCRIPTION
    Adds a new client to the management database
.PARAMETER ClientInfo
    Hashtable containing client information
.EXAMPLE
    Register-TunnelClient -ClientInfo $clientData
#>
function Register-TunnelClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ClientInfo
    )
    
    try {
        $clientId = $ClientInfo.ClientId
        if (-not $clientId) {
            $clientId = [System.Guid]::NewGuid().ToString()
            $ClientInfo.ClientId = $clientId
        }
        
        # Add registration timestamp
        $ClientInfo.RegisteredAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $ClientInfo.LastSeen = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $ClientInfo.Status = "Registered"
        $ClientInfo.TunnelCount = 0
        $ClientInfo.ActiveTunnels = @()
        
        # Store in memory
        $script:ConnectedClients[$clientId] = $ClientInfo
        
        # Persist to database
        Save-ClientDatabase
        
        Write-Log "Client registered: $clientId ($($ClientInfo.HostName))" -Level Info -LogPath $script:LogPath
        return $clientId
    }
    catch {
        Write-Log "Failed to register client: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        throw
    }
}

<#
.SYNOPSIS
    Updates client status and connection information
.DESCRIPTION
    Updates the status of a connected tunnel client
.PARAMETER ClientId
    Unique client identifier
.PARAMETER Status
    Client status (Connected, Disconnected, Error)
.PARAMETER TunnelInfo
    Information about active tunnels
.EXAMPLE
    Update-ClientStatus -ClientId $id -Status "Connected" -TunnelInfo $tunnels
#>
function Update-ClientStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientId,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Connected", "Disconnected", "Error", "Reconnecting")]
        [string]$Status,
        
        [Parameter(Mandatory = $false)]
        [array]$TunnelInfo = @()
    )
    
    try {
        if (-not $script:ConnectedClients.ContainsKey($ClientId)) {
            Write-Log "Unknown client ID: $ClientId" -Level Warning -LogPath $script:LogPath
            return
        }
        
        $client = $script:ConnectedClients[$ClientId]
        $client.Status = $Status
        $client.LastSeen = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $client.TunnelCount = $TunnelInfo.Count
        $client.ActiveTunnels = $TunnelInfo
        
        # Update connection statistics
        if ($Status -eq "Connected") {
            if (-not $client.FirstConnected) {
                $client.FirstConnected = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $client.LastConnected = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $client.ConnectionCount = ($client.ConnectionCount -as [int]) + 1
        }
        
        # Persist changes
        Save-ClientDatabase
        
        Write-Log "Client status updated: $ClientId -> $Status (Tunnels: $($TunnelInfo.Count))" -Level Info -LogPath $script:LogPath
    }
    catch {
        Write-Log "Failed to update client status: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
    }
}

<#
.SYNOPSIS
    Gets information about all registered clients
.DESCRIPTION
    Returns a list of all clients and their current status
.EXAMPLE
    $clients = Get-AllClients
#>
function Get-AllClients {
    try {
        $clientList = @()
        
        foreach ($clientId in $script:ConnectedClients.Keys) {
            $client = $script:ConnectedClients[$clientId].Clone()
            
            # Calculate uptime and connection duration
            if ($client.LastConnected) {
                $lastConnected = [DateTime]::Parse($client.LastConnected)
                $client.UptimeMinutes = [Math]::Round(((Get-Date) - $lastConnected).TotalMinutes, 1)
            }
            
            if ($client.FirstConnected) {
                $firstConnected = [DateTime]::Parse($client.FirstConnected)
                $client.TotalUptimeHours = [Math]::Round(((Get-Date) - $firstConnected).TotalHours, 1)
            }
            
            $clientList += $client
        }
        
        return $clientList | Sort-Object LastSeen -Descending
    }
    catch {
        Write-Log "Failed to get client list: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        return @()
    }
}

<#
.SYNOPSIS
    Gets detailed information about a specific client
.DESCRIPTION
    Returns comprehensive information about a single client
.PARAMETER ClientId
    Unique client identifier
.EXAMPLE
    $client = Get-ClientDetails -ClientId $id
#>
function Get-ClientDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientId
    )
    
    try {
        if (-not $script:ConnectedClients.ContainsKey($ClientId)) {
            return $null
        }
        
        $client = $script:ConnectedClients[$ClientId].Clone()
        
        # Add computed fields
        if ($client.LastSeen) {
            $lastSeen = [DateTime]::Parse($client.LastSeen)
            $client.MinutesSinceLastSeen = [Math]::Round(((Get-Date) - $lastSeen).TotalMinutes, 1)
        }
        
        # Get tunnel statistics
        $client.TunnelStatistics = Get-ClientTunnelStatistics -ClientId $ClientId
        
        return $client
    }
    catch {
        Write-Log "Failed to get client details: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        return $null
    }
}

<#
.SYNOPSIS
    Removes a client from the management system
.DESCRIPTION
    Unregisters a client and cleans up associated data
.PARAMETER ClientId
    Unique client identifier
.EXAMPLE
    Remove-TunnelClient -ClientId $id
#>
function Remove-TunnelClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientId
    )
    
    try {
        if (-not $script:ConnectedClients.ContainsKey($ClientId)) {
            Write-Log "Client not found: $ClientId" -Level Warning -LogPath $script:LogPath
            return
        }
        
        $client = $script:ConnectedClients[$ClientId]
        $script:ConnectedClients.Remove($ClientId)
        
        # Persist changes
        Save-ClientDatabase
        
        Write-Log "Client removed: $ClientId ($($client.HostName))" -Level Info -LogPath $script:LogPath
    }
    catch {
        Write-Log "Failed to remove client: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        throw
    }
}

<#
.SYNOPSIS
    Gets server statistics and health information
.DESCRIPTION
    Returns comprehensive server statistics
.EXAMPLE
    $stats = Get-ServerStatistics
#>
function Get-ServerStatistics {
    try {
        $stats = @{
            ServerStartTime = $script:ServerConfig.StartTime
            TotalClients = $script:ConnectedClients.Count
            ConnectedClients = ($script:ConnectedClients.Values | Where-Object { $_.Status -eq "Connected" }).Count
            DisconnectedClients = ($script:ConnectedClients.Values | Where-Object { $_.Status -eq "Disconnected" }).Count
            ErrorClients = ($script:ConnectedClients.Values | Where-Object { $_.Status -eq "Error" }).Count
            TotalTunnels = ($script:ConnectedClients.Values | Measure-Object -Property TunnelCount -Sum).Sum
            ServerUptime = if ($script:ServerConfig.StartTime) { 
                [Math]::Round(((Get-Date) - [DateTime]::Parse($script:ServerConfig.StartTime)).TotalHours, 1) 
            } else { 0 }
            LastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        # Add port usage statistics
        $portUsage = @{}
        foreach ($client in $script:ConnectedClients.Values) {
            foreach ($tunnel in $client.ActiveTunnels) {
                $port = $tunnel.RemotePort
                if ($portUsage.ContainsKey($port)) {
                    $portUsage[$port]++
                } else {
                    $portUsage[$port] = 1
                }
            }
        }
        $stats.PortUsage = $portUsage
        
        return $stats
    }
    catch {
        Write-Log "Failed to get server statistics: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        return @{}
    }
}

<#
.SYNOPSIS
    Initializes the client database
.DESCRIPTION
    Creates the client database file if it doesn't exist
#>
function Initialize-ClientDatabase {
    try {
        if (-not (Test-Path $script:ClientDatabase)) {
            $emptyDatabase = @{
                Version = "1.0"
                CreatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Clients = @{}
            }
            
            $emptyDatabase | ConvertTo-Json -Depth 10 | Set-Content -Path $script:ClientDatabase -Encoding UTF8
            Write-Log "Client database initialized: $script:ClientDatabase" -Level Info -LogPath $script:LogPath
        }
    }
    catch {
        Write-Log "Failed to initialize client database: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
    }
}

<#
.SYNOPSIS
    Loads client data from the database
.DESCRIPTION
    Reads client information from the persistent database
#>
function Load-ClientDatabase {
    try {
        if (Test-Path $script:ClientDatabase) {
            $database = Get-Content -Path $script:ClientDatabase -Raw | ConvertFrom-Json
            
            if ($database.Clients) {
                # Convert PSCustomObject to hashtable
                $database.Clients.PSObject.Properties | ForEach-Object {
                    $clientData = @{}
                    $_.Value.PSObject.Properties | ForEach-Object {
                        $clientData[$_.Name] = $_.Value
                    }
                    $script:ConnectedClients[$_.Name] = $clientData
                }
            }
            
            Write-Log "Loaded $($script:ConnectedClients.Count) clients from database" -Level Info -LogPath $script:LogPath
        }
    }
    catch {
        Write-Log "Failed to load client database: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
    }
}

<#
.SYNOPSIS
    Saves client data to the database
.DESCRIPTION
    Persists current client information to the database
#>
function Save-ClientDatabase {
    try {
        $database = @{
            Version = "1.0"
            LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Clients = $script:ConnectedClients
        }
        
        $database | ConvertTo-Json -Depth 10 | Set-Content -Path $script:ClientDatabase -Encoding UTF8
    }
    catch {
        Write-Log "Failed to save client database: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
    }
}

<#
.SYNOPSIS
    Gets the default server configuration
.DESCRIPTION
    Returns a default configuration object for the SSH tunnel server
.EXAMPLE
    $config = Get-DefaultServerConfig
#>
function Get-DefaultServerConfig {
    return @{
        StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ListenPorts = @(22, 443)
        ClientPortRange = @{ Start = 10000; End = 20000 }
        MaxClients = 1000
        TunnelTimeout = 300
        LogRetention = 30
        WebInterface = @{
            Enabled = $true
            Port = 8080
            SSL = $false
            StaticPath = Join-Path $script:ModuleRoot "..\..\web"
        }
        Security = @{
            AllowedUsers = @("tunnel-client")
            RequireKeyAuth = $true
            MaxConnectionsPerClient = 10
        }
        Monitoring = @{
            HealthCheckInterval = 60
            ClientTimeoutMinutes = 10
            EnableAlerts = $false
        }
    }
}

<#
.SYNOPSIS
    Gets tunnel statistics for a specific client
.DESCRIPTION
    Returns detailed tunnel statistics for a client
.PARAMETER ClientId
    Unique client identifier
.EXAMPLE
    $stats = Get-ClientTunnelStatistics -ClientId $id
#>
function Get-ClientTunnelStatistics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientId
    )
    
    try {
        if (-not $script:ConnectedClients.ContainsKey($ClientId)) {
            return @{}
        }
        
        $client = $script:ConnectedClients[$ClientId]
        $stats = @{
            TotalTunnels = $client.TunnelCount
            ActiveTunnels = $client.ActiveTunnels.Count
            TunnelTypes = @{}
            PortMappings = @()
        }
        
        # Analyze tunnel types and port mappings
        foreach ($tunnel in $client.ActiveTunnels) {
            $service = $tunnel.Service -as [string]
            if ($service) {
                if ($stats.TunnelTypes.ContainsKey($service)) {
                    $stats.TunnelTypes[$service]++
                } else {
                    $stats.TunnelTypes[$service] = 1
                }
            }
            
            $stats.PortMappings += @{
                LocalPort = $tunnel.LocalPort
                RemotePort = $tunnel.RemotePort
                Service = $service
                Status = "Active"
            }
        }
        
        return $stats
    }
    catch {
        Write-Log "Failed to get client tunnel statistics: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        return @{}
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-SSHTunnelServer',
    'Register-TunnelClient',
    'Update-ClientStatus',
    'Get-AllClients',
    'Get-ClientDetails',
    'Remove-TunnelClient',
    'Get-ServerStatistics',
    'Get-DefaultServerConfig',
    'Get-ClientTunnelStatistics'
)

