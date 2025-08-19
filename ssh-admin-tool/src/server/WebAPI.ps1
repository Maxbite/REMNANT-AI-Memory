# SSH Tunnel Server Web API
# Provides REST API endpoints for the management dashboard

#Requires -Version 5.1

param(
    [Parameter(Mandatory = $false)]
    [int]$Port = 8080,
    
    [Parameter(Mandatory = $false)]
    [string]$StaticPath = "..\..\tunnel-dashboard\dist",
    
    [Parameter(Mandatory = $false)]
    [switch]$Development = $false
)

# Import required modules
try {
    Import-Module (Join-Path $PSScriptRoot "SSHTunnelServer.psm1") -Force
    . (Join-Path $PSScriptRoot "..\common\CommonFunctions.ps1")
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

# Global variables
$script:Server = $null
$script:LogPath = Join-Path $PSScriptRoot "..\..\logs\webapi.log"

<#
.SYNOPSIS
    Starts the web API server
.DESCRIPTION
    Initializes and starts the HTTP server for the management dashboard
.PARAMETER Port
    Port to listen on (default: 8080)
.PARAMETER StaticPath
    Path to static web files
.EXAMPLE
    Start-WebAPIServer -Port 8080
#>
function Start-WebAPIServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$Port = 8080,
        
        [Parameter(Mandatory = $false)]
        [string]$StaticPath = "..\..\tunnel-dashboard\dist"
    )
    
    try {
        Write-Log "Starting SSH Tunnel Web API Server on port $Port..." -Level Info -LogPath $script:LogPath
        
        # Initialize the tunnel server
        Initialize-SSHTunnelServer
        
        # Create HTTP listener
        $script:Server = New-Object System.Net.HttpListener
        $script:Server.Prefixes.Add("http://+:$Port/")
        
        # Enable CORS for development
        if ($Development) {
            Write-Log "Development mode enabled - CORS headers will be added" -Level Info -LogPath $script:LogPath
        }
        
        # Start listening
        $script:Server.Start()
        Write-Log "Web API Server started successfully on http://localhost:$Port" -Level Info -LogPath $script:LogPath
        
        # Main request processing loop
        while ($script:Server.IsListening) {
            try {
                # Get incoming request
                $context = $script:Server.GetContext()
                $request = $context.Request
                $response = $context.Response
                
                # Log request
                Write-Log "Request: $($request.HttpMethod) $($request.Url.AbsolutePath)" -Level Debug -LogPath $script:LogPath
                
                # Add CORS headers for development
                if ($Development) {
                    $response.Headers.Add("Access-Control-Allow-Origin", "*")
                    $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
                    $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Authorization")
                }
                
                # Handle preflight requests
                if ($request.HttpMethod -eq "OPTIONS") {
                    $response.StatusCode = 200
                    $response.Close()
                    continue
                }
                
                # Route the request
                $handled = Handle-APIRequest -Request $request -Response $response -StaticPath $StaticPath
                
                if (-not $handled) {
                    # Return 404 for unhandled requests
                    $response.StatusCode = 404
                    $responseText = "Not Found"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseText)
                    $response.ContentLength64 = $buffer.Length
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                }
                
                $response.Close()
            }
            catch {
                Write-Log "Error processing request: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
                try {
                    $response.StatusCode = 500
                    $response.Close()
                }
                catch {
                    # Ignore errors when closing response
                }
            }
        }
    }
    catch {
        Write-Log "Failed to start Web API Server: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        throw
    }
    finally {
        if ($script:Server) {
            $script:Server.Stop()
            $script:Server.Close()
        }
    }
}

<#
.SYNOPSIS
    Handles incoming HTTP requests
.DESCRIPTION
    Routes requests to appropriate handlers
.PARAMETER Request
    HTTP request object
.PARAMETER Response
    HTTP response object
.PARAMETER StaticPath
    Path to static files
.EXAMPLE
    Handle-APIRequest -Request $req -Response $resp -StaticPath $path
#>
function Handle-APIRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerRequest]$Request,
        
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerResponse]$Response,
        
        [Parameter(Mandatory = $true)]
        [string]$StaticPath
    )
    
    $path = $Request.Url.AbsolutePath
    $method = $Request.HttpMethod
    
    try {
        # API endpoints
        if ($path.StartsWith("/api/")) {
            return Handle-APIEndpoint -Path $path -Method $method -Request $Request -Response $Response
        }
        
        # Static file serving
        if ($path -eq "/" -or $path -eq "/index.html") {
            return Serve-StaticFile -FilePath "index.html" -StaticPath $StaticPath -Response $Response
        }
        
        # Other static files
        if ($path.StartsWith("/")) {
            $filePath = $path.Substring(1).Replace("/", "\")
            return Serve-StaticFile -FilePath $filePath -StaticPath $StaticPath -Response $Response
        }
        
        return $false
    }
    catch {
        Write-Log "Error handling request: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        return $false
    }
}

<#
.SYNOPSIS
    Handles API endpoint requests
.DESCRIPTION
    Processes REST API calls for tunnel management
.PARAMETER Path
    Request path
.PARAMETER Method
    HTTP method
.PARAMETER Request
    HTTP request object
.PARAMETER Response
    HTTP response object
.EXAMPLE
    Handle-APIEndpoint -Path "/api/clients" -Method "GET" -Request $req -Response $resp
#>
function Handle-APIEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Method,
        
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerRequest]$Request,
        
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerResponse]$Response
    )
    
    try {
        $responseData = $null
        
        switch -Regex ($Path) {
            "^/api/clients$" {
                if ($Method -eq "GET") {
                    $responseData = Get-AllClients
                }
                break
            }
            
            "^/api/clients/([^/]+)$" {
                $clientId = $Matches[1]
                if ($Method -eq "GET") {
                    $responseData = Get-ClientDetails -ClientId $clientId
                }
                elseif ($Method -eq "DELETE") {
                    Remove-TunnelClient -ClientId $clientId
                    $responseData = @{ success = $true; message = "Client removed successfully" }
                }
                break
            }
            
            "^/api/stats$" {
                if ($Method -eq "GET") {
                    $responseData = Get-ServerStatistics
                }
                break
            }
            
            "^/api/tunnels$" {
                if ($Method -eq "GET") {
                    $clients = Get-AllClients
                    $tunnels = @()
                    foreach ($client in $clients) {
                        foreach ($tunnel in $client.ActiveTunnels) {
                            $tunnels += @{
                                ClientId = $client.ClientId
                                HostName = $client.HostName
                                Service = $tunnel.Service
                                LocalPort = $tunnel.LocalPort
                                RemotePort = $tunnel.RemotePort
                                Status = "Active"
                            }
                        }
                    }
                    $responseData = $tunnels
                }
                break
            }
            
            "^/api/health$" {
                if ($Method -eq "GET") {
                    $responseData = @{
                        status = "healthy"
                        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        version = "1.0.0"
                        uptime = if ($script:ServerConfig.StartTime) { 
                            [Math]::Round(((Get-Date) - [DateTime]::Parse($script:ServerConfig.StartTime)).TotalHours, 1) 
                        } else { 0 }
                    }
                }
                break
            }
            
            "^/api/register$" {
                if ($Method -eq "POST") {
                    $requestBody = Get-RequestBody -Request $Request
                    $clientInfo = $requestBody | ConvertFrom-Json -AsHashtable
                    $clientId = Register-TunnelClient -ClientInfo $clientInfo
                    $responseData = @{ clientId = $clientId; success = $true }
                }
                break
            }
            
            "^/api/update-status$" {
                if ($Method -eq "POST") {
                    $requestBody = Get-RequestBody -Request $Request
                    $statusUpdate = $requestBody | ConvertFrom-Json -AsHashtable
                    Update-ClientStatus -ClientId $statusUpdate.ClientId -Status $statusUpdate.Status -TunnelInfo $statusUpdate.TunnelInfo
                    $responseData = @{ success = $true }
                }
                break
            }
            
            default {
                return $false
            }
        }
        
        if ($responseData -ne $null) {
            Send-JSONResponse -Response $Response -Data $responseData
            return $true
        }
        
        return $false
    }
    catch {
        Write-Log "Error handling API endpoint: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        Send-ErrorResponse -Response $Response -Message $_.Exception.Message
        return $true
    }
}

<#
.SYNOPSIS
    Serves static files
.DESCRIPTION
    Serves static web files for the dashboard
.PARAMETER FilePath
    Relative file path
.PARAMETER StaticPath
    Base static files directory
.PARAMETER Response
    HTTP response object
.EXAMPLE
    Serve-StaticFile -FilePath "index.html" -StaticPath $path -Response $resp
#>
function Serve-StaticFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$StaticPath,
        
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerResponse]$Response
    )
    
    try {
        $fullPath = Join-Path $StaticPath $FilePath
        
        if (-not (Test-Path $fullPath)) {
            return $false
        }
        
        # Get MIME type
        $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $mimeType = Get-MimeType -Extension $extension
        
        # Read file content
        $content = [System.IO.File]::ReadAllBytes($fullPath)
        
        # Set response headers
        $Response.ContentType = $mimeType
        $Response.ContentLength64 = $content.Length
        $Response.StatusCode = 200
        
        # Write content
        $Response.OutputStream.Write($content, 0, $content.Length)
        
        return $true
    }
    catch {
        Write-Log "Error serving static file: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        return $false
    }
}

<#
.SYNOPSIS
    Gets MIME type for file extension
.DESCRIPTION
    Returns appropriate MIME type for web files
.PARAMETER Extension
    File extension
.EXAMPLE
    Get-MimeType -Extension ".html"
#>
function Get-MimeType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Extension
    )
    
    $mimeTypes = @{
        ".html" = "text/html"
        ".css" = "text/css"
        ".js" = "application/javascript"
        ".json" = "application/json"
        ".png" = "image/png"
        ".jpg" = "image/jpeg"
        ".jpeg" = "image/jpeg"
        ".gif" = "image/gif"
        ".svg" = "image/svg+xml"
        ".ico" = "image/x-icon"
        ".woff" = "font/woff"
        ".woff2" = "font/woff2"
        ".ttf" = "font/ttf"
        ".eot" = "application/vnd.ms-fontobject"
    }
    
    return $mimeTypes[$Extension] -or "application/octet-stream"
}

<#
.SYNOPSIS
    Sends JSON response
.DESCRIPTION
    Sends JSON data as HTTP response
.PARAMETER Response
    HTTP response object
.PARAMETER Data
    Data to serialize as JSON
.EXAMPLE
    Send-JSONResponse -Response $resp -Data $data
#>
function Send-JSONResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerResponse]$Response,
        
        [Parameter(Mandatory = $true)]
        [object]$Data
    )
    
    try {
        $json = $Data | ConvertTo-Json -Depth 10 -Compress
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
        
        $Response.ContentType = "application/json"
        $Response.ContentLength64 = $buffer.Length
        $Response.StatusCode = 200
        
        $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    catch {
        Write-Log "Error sending JSON response: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        throw
    }
}

<#
.SYNOPSIS
    Sends error response
.DESCRIPTION
    Sends error message as HTTP response
.PARAMETER Response
    HTTP response object
.PARAMETER Message
    Error message
.EXAMPLE
    Send-ErrorResponse -Response $resp -Message "Error occurred"
#>
function Send-ErrorResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerResponse]$Response,
        
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    try {
        $errorData = @{
            error = $true
            message = $Message
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        $json = $errorData | ConvertTo-Json -Compress
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
        
        $Response.ContentType = "application/json"
        $Response.ContentLength64 = $buffer.Length
        $Response.StatusCode = 500
        
        $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    catch {
        Write-Log "Error sending error response: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
    }
}

<#
.SYNOPSIS
    Gets request body content
.DESCRIPTION
    Reads and returns HTTP request body
.PARAMETER Request
    HTTP request object
.EXAMPLE
    $body = Get-RequestBody -Request $req
#>
function Get-RequestBody {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpListenerRequest]$Request
    )
    
    try {
        $reader = New-Object System.IO.StreamReader($Request.InputStream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        return $body
    }
    catch {
        Write-Log "Error reading request body: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
        return ""
    }
}

<#
.SYNOPSIS
    Stops the web API server
.DESCRIPTION
    Gracefully shuts down the HTTP server
.EXAMPLE
    Stop-WebAPIServer
#>
function Stop-WebAPIServer {
    try {
        if ($script:Server -and $script:Server.IsListening) {
            Write-Log "Stopping Web API Server..." -Level Info -LogPath $script:LogPath
            $script:Server.Stop()
            $script:Server.Close()
            Write-Log "Web API Server stopped successfully" -Level Info -LogPath $script:LogPath
        }
    }
    catch {
        Write-Log "Error stopping Web API Server: $($_.Exception.Message)" -Level Error -LogPath $script:LogPath
    }
}

# Handle Ctrl+C gracefully
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Stop-WebAPIServer
}

# Main execution
try {
    Write-Host "SSH Tunnel Management Web API Server" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Starting server on port $Port..." -ForegroundColor Green
    Write-Host "Static files: $StaticPath" -ForegroundColor Gray
    Write-Host "Development mode: $Development" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
    Write-Host ""
    
    Start-WebAPIServer -Port $Port -StaticPath $StaticPath
}
catch {
    Write-Host "Failed to start server: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

