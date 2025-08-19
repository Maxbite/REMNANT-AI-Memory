# Common Functions for SSH Tunnel System
# Shared utilities for both client and server components

#Requires -Version 5.1

# Global variables
$script:LogLevels = @{
    "Debug" = 0
    "Info" = 1
    "Warning" = 2
    "Error" = 3
}

<#
.SYNOPSIS
    Writes a log message with timestamp and level
.DESCRIPTION
    Centralized logging function for the SSH tunnel system
.PARAMETER Message
    The message to log
.PARAMETER Level
    Log level (Debug, Info, Warning, Error)
.PARAMETER LogPath
    Path to the log file (optional, uses default if not specified)
.EXAMPLE
    Write-Log "Tunnel established successfully" -Level Info
#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Debug", "Info", "Warning", "Error")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath = $null
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    switch ($Level) {
        "Debug" { Write-Host $logEntry -ForegroundColor Gray }
        "Info" { Write-Host $logEntry -ForegroundColor White }
        "Warning" { Write-Host $logEntry -ForegroundColor Yellow }
        "Error" { Write-Host $logEntry -ForegroundColor Red }
    }
    
    # File output
    if ($LogPath) {
        try {
            # Ensure log directory exists
            $logDir = Split-Path $LogPath -Parent
            if ($logDir -and -not (Test-Path $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            
            # Append to log file
            Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
            
            # Rotate log if it gets too large (>10MB)
            if ((Get-Item $LogPath -ErrorAction SilentlyContinue).Length -gt 10MB) {
                Rotate-LogFile -LogPath $LogPath
            }
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

<#
.SYNOPSIS
    Rotates a log file when it becomes too large
.DESCRIPTION
    Moves current log to .old and starts a new log file
.PARAMETER LogPath
    Path to the log file to rotate
.EXAMPLE
    Rotate-LogFile -LogPath "C:\logs\client.log"
#>
function Rotate-LogFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )
    
    try {
        $logDir = Split-Path $LogPath -Parent
        $logName = Split-Path $LogPath -Leaf
        $oldLogPath = Join-Path $logDir "$logName.old"
        
        # Remove old backup if it exists
        if (Test-Path $oldLogPath) {
            Remove-Item $oldLogPath -Force
        }
        
        # Move current log to backup
        Move-Item $LogPath $oldLogPath -Force
        
        Write-Log "Log file rotated: $LogPath" -Level Info -LogPath $LogPath
    }
    catch {
        Write-Warning "Failed to rotate log file: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Tests if SSH client is available on the system
.DESCRIPTION
    Checks for SSH client availability and version
.EXAMPLE
    Test-SSHClientAvailable
#>
function Test-SSHClientAvailable {
    try {
        $sshVersion = ssh -V 2>&1
        if ($sshVersion -match "OpenSSH") {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Gets the local network range for scanning
.DESCRIPTION
    Determines the local network range based on current IP configuration
.EXAMPLE
    $range = Get-LocalNetworkRange
#>
function Get-LocalNetworkRange {
    try {
        $networkAdapters = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq "Up" -and $_.IPv4Address }
        
        foreach ($adapter in $networkAdapters) {
            $ipAddress = $adapter.IPv4Address.IPAddress
            $prefixLength = $adapter.IPv4Address.PrefixLength
            
            # Skip loopback and APIPA addresses
            if ($ipAddress -match "^127\." -or $ipAddress -match "^169\.254\.") {
                continue
            }
            
            # Calculate network range
            $ip = [System.Net.IPAddress]::Parse($ipAddress)
            $mask = [System.Net.IPAddress]::Parse((Convert-PrefixLengthToSubnetMask $prefixLength))
            
            $networkBytes = @()
            for ($i = 0; $i -lt 4; $i++) {
                $networkBytes += $ip.GetAddressBytes()[$i] -band $mask.GetAddressBytes()[$i]
            }
            
            $networkAddress = ($networkBytes -join ".")
            return @{
                Network = $networkAddress
                PrefixLength = $prefixLength
                Range = "$networkAddress/$prefixLength"
            }
        }
        
        return $null
    }
    catch {
        Write-Log "Error getting local network range: $($_.Exception.Message)" -Level Warning
        return $null
    }
}

<#
.SYNOPSIS
    Converts prefix length to subnet mask
.DESCRIPTION
    Helper function to convert CIDR prefix length to dotted decimal subnet mask
.PARAMETER PrefixLength
    CIDR prefix length (e.g., 24)
.EXAMPLE
    Convert-PrefixLengthToSubnetMask -PrefixLength 24
#>
function Convert-PrefixLengthToSubnetMask {
    param([int]$PrefixLength)
    
    $mask = [uint32]0
    for ($i = 0; $i -lt $PrefixLength; $i++) {
        $mask = $mask -bor (1 -shl (31 - $i))
    }
    
    $bytes = [System.BitConverter]::GetBytes($mask)
    if ([System.BitConverter]::IsLittleEndian) {
        [Array]::Reverse($bytes)
    }
    
    return ($bytes -join ".")
}

<#
.SYNOPSIS
    Finds SSH-enabled hosts on the network
.DESCRIPTION
    Scans the local network for hosts with SSH service running
.PARAMETER NetworkRange
    Network range to scan (from Get-LocalNetworkRange)
.PARAMETER MaxHosts
    Maximum number of hosts to scan (default: 50)
.EXAMPLE
    $sshHosts = Find-SSHHosts -NetworkRange $networkRange
#>
function Find-SSHHosts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$NetworkRange,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxHosts = 50
    )
    
    $sshHosts = @()
    
    try {
        Write-Log "Scanning network for SSH hosts: $($NetworkRange.Range)" -Level Info
        
        # Parse network address
        $networkParts = $NetworkRange.Network.Split(".")
        $baseNetwork = "$($networkParts[0]).$($networkParts[1]).$($networkParts[2])"
        
        # Scan a limited range of hosts
        $startHost = [Math]::Max(1, [int]$networkParts[3])
        $endHost = [Math]::Min(254, $startHost + $MaxHosts)
        
        $jobs = @()
        
        # Start parallel ping sweep
        for ($i = $startHost; $i -le $endHost; $i++) {
            $targetIP = "$baseNetwork.$i"
            
            $job = Start-Job -ScriptBlock {
                param($IP)
                
                # Quick ping test
                $pingResult = Test-NetConnection -ComputerName $IP -InformationLevel Quiet -WarningAction SilentlyContinue
                if ($pingResult) {
                    # Test SSH port
                    $sshResult = Test-NetConnection -ComputerName $IP -Port 22 -InformationLevel Quiet -WarningAction SilentlyContinue
                    if ($sshResult) {
                        try {
                            # Try to get hostname
                            $hostname = [System.Net.Dns]::GetHostEntry($IP).HostName
                        }
                        catch {
                            $hostname = $IP
                        }
                        
                        return @{
                            IP = $IP
                            HostName = $hostname
                            SSHAvailable = $true
                        }
                    }
                }
                return $null
            } -ArgumentList $targetIP
            
            $jobs += $job
        }
        
        # Wait for jobs to complete (with timeout)
        $timeout = 30
        $completed = Wait-Job -Job $jobs -Timeout $timeout
        
        # Collect results
        foreach ($job in $jobs) {
            try {
                $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                if ($result) {
                    $sshHosts += $result
                    Write-Log "Found SSH host: $($result.IP) ($($result.HostName))" -Level Info
                }
            }
            catch {
                # Ignore job errors
            }
            finally {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Log "Network scan completed. Found $($sshHosts.Count) SSH hosts." -Level Info
        return $sshHosts
    }
    catch {
        Write-Log "Error scanning network: $($_.Exception.Message)" -Level Error
        return @()
    }
}

<#
.SYNOPSIS
    Generates a secure random password
.DESCRIPTION
    Creates a cryptographically secure random password
.PARAMETER Length
    Password length (default: 16)
.PARAMETER IncludeSymbols
    Include special symbols (default: true)
.EXAMPLE
    $password = New-SecurePassword -Length 20
#>
function New-SecurePassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Length = 16,
        
        [Parameter(Mandatory = $false)]
        [bool]$IncludeSymbols = $true
    )
    
    $chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    if ($IncludeSymbols) {
        $chars += "!@#$%^&*()_+-=[]{}|;:,.<>?"
    }
    
    $password = ""
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    
    for ($i = 0; $i -lt $Length; $i++) {
        $bytes = New-Object byte[] 1
        $rng.GetBytes($bytes)
        $password += $chars[$bytes[0] % $chars.Length]
    }
    
    $rng.Dispose()
    return $password
}

<#
.SYNOPSIS
    Tests network connectivity to a host and port
.DESCRIPTION
    Enhanced connectivity test with timeout and retry logic
.PARAMETER Host
    Target hostname or IP address
.PARAMETER Port
    Target port number
.PARAMETER TimeoutSeconds
    Connection timeout in seconds (default: 5)
.PARAMETER RetryCount
    Number of retry attempts (default: 1)
.EXAMPLE
    Test-NetworkConnectivity -Host "server.com" -Port 22 -TimeoutSeconds 10
#>
function Test-NetworkConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Host,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 5,
        
        [Parameter(Mandatory = $false)]
        [int]$RetryCount = 1
    )
    
    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $connectTask = $tcpClient.ConnectAsync($Host, $Port)
            
            if ($connectTask.Wait($TimeoutSeconds * 1000)) {
                if ($tcpClient.Connected) {
                    $tcpClient.Close()
                    return $true
                }
            }
            
            $tcpClient.Close()
        }
        catch {
            # Connection failed
        }
        
        if ($attempt -lt $RetryCount) {
            Start-Sleep -Seconds 1
        }
    }
    
    return $false
}

<#
.SYNOPSIS
    Validates SSH key file format and permissions
.DESCRIPTION
    Checks if an SSH private key file is valid and properly secured
.PARAMETER KeyPath
    Path to the SSH private key file
.EXAMPLE
    Test-SSHKeyFile -KeyPath "C:\Users\admin\.ssh\id_rsa"
#>
function Test-SSHKeyFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$KeyPath
    )
    
    try {
        # Check if file exists
        if (-not (Test-Path $KeyPath)) {
            return @{ Valid = $false; Error = "Key file not found" }
        }
        
        # Check file content
        $keyContent = Get-Content $KeyPath -Raw
        if (-not $keyContent) {
            return @{ Valid = $false; Error = "Key file is empty" }
        }
        
        # Basic format validation
        if ($keyContent -notmatch "-----BEGIN.*PRIVATE KEY-----") {
            return @{ Valid = $false; Error = "Invalid key format" }
        }
        
        # Check file permissions (Windows)
        $acl = Get-Acl $KeyPath
        $accessRules = $acl.Access | Where-Object { $_.IdentityReference -ne $env:USERNAME -and $_.FileSystemRights -match "Read" }
        
        if ($accessRules.Count -gt 0) {
            return @{ Valid = $true; Warning = "Key file may have overly permissive permissions" }
        }
        
        return @{ Valid = $true; Error = $null }
    }
    catch {
        return @{ Valid = $false; Error = $_.Exception.Message }
    }
}

<#
.SYNOPSIS
    Converts a PowerShell hashtable to JSON configuration
.DESCRIPTION
    Safely converts configuration objects to JSON format
.PARAMETER InputObject
    The hashtable or object to convert
.PARAMETER Depth
    Maximum depth for nested objects (default: 10)
.EXAMPLE
    $json = ConvertTo-ConfigJson -InputObject $config
#>
function ConvertTo-ConfigJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject,
        
        [Parameter(Mandatory = $false)]
        [int]$Depth = 10
    )
    
    try {
        return $InputObject | ConvertTo-Json -Depth $Depth -Compress:$false
    }
    catch {
        Write-Log "Error converting to JSON: $($_.Exception.Message)" -Level Error
        return "{}"
    }
}

<#
.SYNOPSIS
    Safely imports a PowerShell data file
.DESCRIPTION
    Imports .psd1 configuration files with error handling
.PARAMETER Path
    Path to the PowerShell data file
.EXAMPLE
    $config = Import-ConfigFile -Path "C:\config\client.conf"
#>
function Import-ConfigFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        if (-not (Test-Path $Path)) {
            throw "Configuration file not found: $Path"
        }
        
        $config = Import-PowerShellDataFile -Path $Path
        return $config
    }
    catch {
        Write-Log "Error importing configuration file: $($_.Exception.Message)" -Level Error
        throw
    }
}

# Export all functions for use by other modules
Export-ModuleMember -Function @(
    'Write-Log',
    'Rotate-LogFile',
    'Test-SSHClientAvailable',
    'Get-LocalNetworkRange',
    'Convert-PrefixLengthToSubnetMask',
    'Find-SSHHosts',
    'New-SecurePassword',
    'Test-NetworkConnectivity',
    'Test-SSHKeyFile',
    'ConvertTo-ConfigJson',
    'Import-ConfigFile'
)

