# Network Discovery Module
# Provides automatic discovery of SSH tunnel servers and network configuration

#Requires -Version 5.1

<#
.SYNOPSIS
    Discovers SSH tunnel servers on the network
.DESCRIPTION
    Uses multiple methods to discover available SSH tunnel servers
.PARAMETER NetworkRange
    Network range to scan (e.g., "192.168.1.0/24")
.PARAMETER Timeout
    Timeout for each connection attempt in seconds
.EXAMPLE
    $servers = Find-SSHTunnelServers -NetworkRange "192.168.1.0/24"
#>
function Find-SSHTunnelServers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$NetworkRange = $null,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxHosts = 50
    )
    
    try {
        Write-Log "Starting SSH tunnel server discovery..." -Level Info
        
        $discoveredServers = @()
        
        # Method 1: DNS SRV record discovery
        $dnsServers = Find-ServersByDNS
        $discoveredServers += $dnsServers
        
        # Method 2: Network scanning (if network range provided)
        if ($NetworkRange) {
            $networkServers = Find-ServersByNetworkScan -NetworkRange $NetworkRange -Timeout $Timeout -MaxHosts $MaxHosts
            $discoveredServers += $networkServers
        }
        
        # Method 3: Well-known hosts discovery
        $knownServers = Find-ServersByKnownHosts
        $discoveredServers += $knownServers
        
        # Method 4: Broadcast discovery
        $broadcastServers = Find-ServersByBroadcast -Timeout $Timeout
        $discoveredServers += $broadcastServers
        
        # Remove duplicates and validate servers
        $uniqueServers = $discoveredServers | Sort-Object Host -Unique
        $validatedServers = @()
        
        foreach ($server in $uniqueServers) {
            if (Test-SSHTunnelServer -Host $server.Host -Port $server.Port -Timeout $Timeout) {
                $validatedServers += $server
                Write-Log "Validated SSH tunnel server: $($server.Host):$($server.Port)" -Level Info
            }
        }
        
        Write-Log "Discovery completed. Found $($validatedServers.Count) valid SSH tunnel servers" -Level Info
        return $validatedServers
    }
    catch {
        Write-Log "Error during server discovery: $($_.Exception.Message)" -Level Error
        return @()
    }
}

<#
.SYNOPSIS
    Discovers servers using DNS SRV records
.DESCRIPTION
    Looks for _ssh-tunnel._tcp SRV records in the domain
.EXAMPLE
    $servers = Find-ServersByDNS
#>
function Find-ServersByDNS {
    try {
        Write-Log "Attempting DNS SRV record discovery..." -Level Debug
        
        $servers = @()
        $domain = $env:USERDNSDOMAIN
        
        if (-not $domain) {
            Write-Log "No domain found for DNS discovery" -Level Debug
            return $servers
        }
        
        # Query for _ssh-tunnel._tcp SRV records
        $srvRecord = "_ssh-tunnel._tcp.$domain"
        
        try {
            $dnsResults = Resolve-DnsName -Name $srvRecord -Type SRV -ErrorAction SilentlyContinue
            
            foreach ($result in $dnsResults) {
                if ($result.Type -eq "SRV") {
                    $servers += @{
                        Host = $result.NameTarget
                        Port = $result.Port
                        Priority = $result.Priority
                        Weight = $result.Weight
                        Source = "DNS-SRV"
                    }
                    Write-Log "Found server via DNS SRV: $($result.NameTarget):$($result.Port)" -Level Debug
                }
            }
        }
        catch {
            Write-Log "DNS SRV query failed: $($_.Exception.Message)" -Level Debug
        }
        
        return $servers
    }
    catch {
        Write-Log "Error in DNS discovery: $($_.Exception.Message)" -Level Warning
        return @()
    }
}

<#
.SYNOPSIS
    Discovers servers by scanning network ranges
.DESCRIPTION
    Scans specified network ranges for SSH tunnel servers
.PARAMETER NetworkRange
    Network range in CIDR notation
.PARAMETER Timeout
    Connection timeout in seconds
.PARAMETER MaxHosts
    Maximum number of hosts to scan
.EXAMPLE
    $servers = Find-ServersByNetworkScan -NetworkRange "192.168.1.0/24"
#>
function Find-ServersByNetworkScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NetworkRange,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxHosts = 50
    )
    
    try {
        Write-Log "Starting network scan for range: $NetworkRange" -Level Debug
        
        $servers = @()
        $hosts = Get-NetworkHosts -NetworkRange $NetworkRange -MaxHosts $MaxHosts
        $commonPorts = @(22, 443, 2222, 8022)
        
        foreach ($host in $hosts) {
            foreach ($port in $commonPorts) {
                if (Test-NetConnection -ComputerName $host -Port $port -InformationLevel Quiet -WarningAction SilentlyContinue) {
                    # Check if it's actually an SSH tunnel server
                    if (Test-SSHService -Host $host -Port $port -Timeout $Timeout) {
                        $servers += @{
                            Host = $host
                            Port = $port
                            Priority = 10
                            Weight = 1
                            Source = "NetworkScan"
                        }
                        Write-Log "Found SSH service via network scan: $host`:$port" -Level Debug
                    }
                }
            }
        }
        
        return $servers
    }
    catch {
        Write-Log "Error in network scan: $($_.Exception.Message)" -Level Warning
        return @()
    }
}

<#
.SYNOPSIS
    Discovers servers from known hosts configuration
.DESCRIPTION
    Checks SSH known_hosts and config files for tunnel servers
.EXAMPLE
    $servers = Find-ServersByKnownHosts
#>
function Find-ServersByKnownHosts {
    try {
        Write-Log "Checking known hosts for SSH tunnel servers..." -Level Debug
        
        $servers = @()
        $sshDir = Join-Path $env:USERPROFILE ".ssh"
        
        # Check SSH config file
        $configFile = Join-Path $sshDir "config"
        if (Test-Path $configFile) {
            $configContent = Get-Content $configFile -ErrorAction SilentlyContinue
            
            foreach ($line in $configContent) {
                if ($line -match "^\s*Host\s+(.+)") {
                    $hostName = $Matches[1].Trim()
                    if ($hostName -like "*tunnel*" -or $hostName -like "*ssh*") {
                        # Try to extract hostname and port from subsequent lines
                        $servers += @{
                            Host = $hostName
                            Port = 22
                            Priority = 5
                            Weight = 1
                            Source = "SSHConfig"
                        }
                        Write-Log "Found potential server in SSH config: $hostName" -Level Debug
                    }
                }
            }
        }
        
        # Check known_hosts file
        $knownHostsFile = Join-Path $sshDir "known_hosts"
        if (Test-Path $knownHostsFile) {
            $knownHosts = Get-Content $knownHostsFile -ErrorAction SilentlyContinue
            
            foreach ($line in $knownHosts) {
                if ($line -match "^([^\s,]+)") {
                    $hostEntry = $Matches[1]
                    if ($hostEntry -like "*tunnel*" -or $hostEntry -like "*ssh*") {
                        # Extract hostname and port if specified
                        if ($hostEntry -match "^\[(.+)\]:(\d+)$") {
                            $host = $Matches[1]
                            $port = [int]$Matches[2]
                        } else {
                            $host = $hostEntry
                            $port = 22
                        }
                        
                        $servers += @{
                            Host = $host
                            Port = $port
                            Priority = 8
                            Weight = 1
                            Source = "KnownHosts"
                        }
                        Write-Log "Found potential server in known_hosts: $host`:$port" -Level Debug
                    }
                }
            }
        }
        
        return $servers
    }
    catch {
        Write-Log "Error checking known hosts: $($_.Exception.Message)" -Level Warning
        return @()
    }
}

<#
.SYNOPSIS
    Discovers servers using broadcast discovery
.DESCRIPTION
    Sends broadcast packets to discover SSH tunnel servers
.PARAMETER Timeout
    Discovery timeout in seconds
.EXAMPLE
    $servers = Find-ServersByBroadcast
#>
function Find-ServersByBroadcast {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5
    )
    
    try {
        Write-Log "Attempting broadcast discovery..." -Level Debug
        
        $servers = @()
        
        # Create UDP client for broadcast
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.EnableBroadcast = $true
        
        # Discovery message
        $discoveryMessage = @{
            type = "ssh-tunnel-discovery"
            version = "1.0"
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            clientId = [System.Guid]::NewGuid().ToString()
        } | ConvertTo-Json -Compress
        
        $messageBytes = [System.Text.Encoding]::UTF8.GetBytes($discoveryMessage)
        
        # Send broadcast to common discovery ports
        $discoveryPorts = @(9999, 8888, 7777)
        
        foreach ($port in $discoveryPorts) {
            try {
                $broadcastEndpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Broadcast, $port)
                $udpClient.Send($messageBytes, $messageBytes.Length, $broadcastEndpoint) | Out-Null
                Write-Log "Sent broadcast discovery to port $port" -Level Debug
            }
            catch {
                Write-Log "Failed to send broadcast to port $port`: $($_.Exception.Message)" -Level Debug
            }
        }
        
        # Listen for responses
        $udpClient.Client.ReceiveTimeout = $Timeout * 1000
        $startTime = Get-Date
        
        while (((Get-Date) - $startTime).TotalSeconds -lt $Timeout) {
            try {
                $remoteEndpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                $responseBytes = $udpClient.Receive([ref]$remoteEndpoint)
                $responseText = [System.Text.Encoding]::UTF8.GetString($responseBytes)
                
                $response = $responseText | ConvertFrom-Json
                
                if ($response.type -eq "ssh-tunnel-server" -and $response.sshPort) {
                    $servers += @{
                        Host = $remoteEndpoint.Address.ToString()
                        Port = $response.sshPort
                        Priority = 3
                        Weight = 1
                        Source = "Broadcast"
                        ServerInfo = $response
                    }
                    Write-Log "Found server via broadcast: $($remoteEndpoint.Address):$($response.sshPort)" -Level Debug
                }
            }
            catch [System.Net.Sockets.SocketException] {
                # Timeout or no more data - continue
                break
            }
            catch {
                Write-Log "Error receiving broadcast response: $($_.Exception.Message)" -Level Debug
            }
        }
        
        $udpClient.Close()
        return $servers
    }
    catch {
        Write-Log "Error in broadcast discovery: $($_.Exception.Message)" -Level Warning
        return @()
    }
}

<#
.SYNOPSIS
    Gets list of hosts in a network range
.DESCRIPTION
    Generates list of IP addresses from CIDR notation
.PARAMETER NetworkRange
    Network range in CIDR notation (e.g., "192.168.1.0/24")
.PARAMETER MaxHosts
    Maximum number of hosts to return
.EXAMPLE
    $hosts = Get-NetworkHosts -NetworkRange "192.168.1.0/24"
#>
function Get-NetworkHosts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$NetworkRange,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxHosts = 50
    )
    
    try {
        if ($NetworkRange -notmatch "^(\d+\.\d+\.\d+\.\d+)/(\d+)$") {
            throw "Invalid network range format. Use CIDR notation (e.g., 192.168.1.0/24)"
        }
        
        $networkAddress = $Matches[1]
        $prefixLength = [int]$Matches[2]
        
        $networkBytes = [System.Net.IPAddress]::Parse($networkAddress).GetAddressBytes()
        $hostBits = 32 - $prefixLength
        $maxHosts = [Math]::Min([Math]::Pow(2, $hostBits) - 2, $MaxHosts)  # Exclude network and broadcast
        
        $hosts = @()
        
        for ($i = 1; $i -le $maxHosts; $i++) {
            $hostBytes = $networkBytes.Clone()
            
            # Add host number to the network address
            $hostNumber = $i
            for ($j = 3; $j -ge 0; $j--) {
                $hostBytes[$j] = ($hostBytes[$j] -band (255 -shl ($hostBits - (8 * (3 - $j))))) -bor ($hostNumber -band 255)
                $hostNumber = $hostNumber -shr 8
            }
            
            $hostAddress = [System.Net.IPAddress]::new($hostBytes).ToString()
            $hosts += $hostAddress
        }
        
        return $hosts
    }
    catch {
        Write-Log "Error generating network hosts: $($_.Exception.Message)" -Level Error
        return @()
    }
}

<#
.SYNOPSIS
    Tests if a host is running an SSH tunnel server
.DESCRIPTION
    Validates that a host is running SSH tunnel server software
.PARAMETER Host
    Hostname or IP address
.PARAMETER Port
    SSH port number
.PARAMETER Timeout
    Connection timeout in seconds
.EXAMPLE
    $isServer = Test-SSHTunnelServer -Host "192.168.1.100" -Port 22
#>
function Test-SSHTunnelServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Host,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5
    )
    
    try {
        # First check if SSH service is running
        if (-not (Test-SSHService -Host $Host -Port $Port -Timeout $Timeout)) {
            return $false
        }
        
        # Try to connect and check SSH banner for tunnel server indicators
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.ConnectAsync($Host, $Port)
        
        if ($connectTask.Wait($Timeout * 1000)) {
            $stream = $tcpClient.GetStream()
            $stream.ReadTimeout = $Timeout * 1000
            
            # Read SSH banner
            $buffer = New-Object byte[] 1024
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
            $banner = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
            
            $tcpClient.Close()
            
            # Check if banner indicates SSH tunnel support
            if ($banner -match "SSH-2\.0" -and 
                ($banner -match "tunnel" -or $banner -match "OpenSSH" -or $banner -match "libssh")) {
                return $true
            }
        }
        
        $tcpClient.Close()
        return $false
    }
    catch {
        Write-Log "Error testing SSH tunnel server $Host`:$Port`: $($_.Exception.Message)" -Level Debug
        return $false
    }
}

<#
.SYNOPSIS
    Tests if a host is running SSH service
.DESCRIPTION
    Quick test to check if SSH service is available
.PARAMETER Host
    Hostname or IP address
.PARAMETER Port
    SSH port number
.PARAMETER Timeout
    Connection timeout in seconds
.EXAMPLE
    $hasSSH = Test-SSHService -Host "192.168.1.100" -Port 22
#>
function Test-SSHService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Host,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.ConnectAsync($Host, $Port)
        
        if ($connectTask.Wait($Timeout * 1000)) {
            $tcpClient.Close()
            return $true
        }
        
        $tcpClient.Close()
        return $false
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Gets the current network configuration
.DESCRIPTION
    Retrieves network interface and routing information
.EXAMPLE
    $config = Get-NetworkConfiguration
#>
function Get-NetworkConfiguration {
    try {
        $config = @{
            Interfaces = @()
            DefaultGateway = $null
            DNSServers = @()
            Domain = $env:USERDNSDOMAIN
        }
        
        # Get network interfaces
        $interfaces = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        
        foreach ($interface in $interfaces) {
            $ipConfig = Get-NetIPAddress -InterfaceIndex $interface.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
            
            if ($ipConfig) {
                $config.Interfaces += @{
                    Name = $interface.Name
                    Description = $interface.InterfaceDescription
                    IPAddress = $ipConfig.IPAddress
                    PrefixLength = $ipConfig.PrefixLength
                    NetworkRange = "$($ipConfig.IPAddress)/$($ipConfig.PrefixLength)"
                }
            }
        }
        
        # Get default gateway
        $defaultRoute = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($defaultRoute) {
            $config.DefaultGateway = $defaultRoute.NextHop
        }
        
        # Get DNS servers
        $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses.Count -gt 0 }
        foreach ($dns in $dnsServers) {
            $config.DNSServers += $dns.ServerAddresses
        }
        
        return $config
    }
    catch {
        Write-Log "Error getting network configuration: $($_.Exception.Message)" -Level Error
        return @{}
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Find-SSHTunnelServers',
    'Find-ServersByDNS',
    'Find-ServersByNetworkScan',
    'Find-ServersByKnownHosts',
    'Find-ServersByBroadcast',
    'Get-NetworkHosts',
    'Test-SSHTunnelServer',
    'Test-SSHService',
    'Get-NetworkConfiguration'
)

