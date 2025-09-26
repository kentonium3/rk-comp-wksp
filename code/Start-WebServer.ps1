# ============================================================================
# Start-WebServer.ps1 - Web server management with health monitoring
# ============================================================================

param(
    [switch]$Force,
    [switch]$Silent
)

# Get script directory and import modules
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$modulesDir = Join-Path $scriptDir "modules"

try {
    Import-Module (Join-Path $modulesDir "Configuration.psm1") -Force
    Import-Module (Join-Path $modulesDir "Logging.psm1") -Force
    Import-Module (Join-Path $modulesDir "Notifications.psm1") -Force
    Import-Module (Join-Path $modulesDir "SystemChecks.psm1") -Force
    Import-Module (Join-Path $modulesDir "Recovery.psm1") -Force
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

try {
    Write-RKLog "Starting web server management process" -Component 'WEBSERVER'
    
    $config = Get-RKConfig
    
    # Check if web server is already running
    if ((Test-WebServerStatus) -and -not $Force) {
        $serverInfo = Get-WebServerProcess
        if ($serverInfo) {
            Write-RKLog "Web server already running on port $($config.webServer.port) (PID: $($serverInfo.ProcessId), Started: $($serverInfo.StartTime))" -Level 'SUCCESS' -Component 'WEBSERVER'
        } else {
            Write-RKLog "Web server already running on port $($config.webServer.port)" -Level 'SUCCESS' -Component 'WEBSERVER'
        }
        exit 0
    }
    
    # System health check
    Write-RKLog "Performing system health check" -Component 'WEBSERVER'
    $healthCheck = Test-RequiredComponents -Components @('Python', 'Directories')
    
    if (-not $healthCheck.Python) {
        $errorMsg = "Python is not installed or not accessible. Web server cannot start. Please run Update-Components.ps1 to install Python."
        Write-RKLog $errorMsg -Level 'ERROR' -Component 'WEBSERVER'
        
        if (-not $Silent) {
            Send-RKNotification -Subject "Web Server Startup Failed - Python Missing" -Body $errorMsg -ShowUserAlert -UserMessage "Your computer manual cannot start because Python is missing. The support team has been notified and will fix this."
        }
        exit 1
    }
    
    if (-not $healthCheck.Directories) {
        Write-RKLog "Creating missing directories" -Component 'WEBSERVER'
        Repair-SystemDirectories | Out-Null
        
        # Check if deployment content exists
        $deployPath = $config.repository.deployPath
        $indexFile = Join-Path $deployPath "index.html"
        
        if (!(Test-Path $indexFile)) {
            Write-RKLog "Manual content missing, creating temporary index" -Component 'WEBSERVER'
            # Create a temporary index file if manual content is missing
            $tempIndex = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rob's Computer Manual</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
        .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .status { background: #e8f6ff; border: 1px solid #3498db; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .timestamp { color: #7f8c8d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Rob's Computer Manual</h1>
        <div class="status">
            <h3>Setting Up Your Manual</h3>
            <p>Your computer manual is being prepared. This may take a few minutes as we download the latest content.</p>
            <p>Please wait a moment and then refresh this page.</p>
            <p>If this message persists, your support person has been notified and will help resolve any issues.</p>
        </div>
        <div class="timestamp">
            Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') on $($config.system.computerName)
        </div>
    </div>
</body>
</html>
"@
            Set-Content $indexFile -Value $tempIndex -Encoding UTF8
        }
    }
    
    # Stop any existing web server processes on this port (cleanup)
    Write-RKLog "Checking for existing processes on port $($config.webServer.port)" -Component 'WEBSERVER'
    try {
        $existingProcesses = Get-NetTCPConnection -LocalPort $config.webServer.port -ErrorAction SilentlyContinue | 
                           ForEach-Object { Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue }
        
        if ($existingProcesses) {
            Write-RKLog "Stopping $($existingProcesses.Count) existing web server process(es)" -Component 'WEBSERVER'
            $existingProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        }
    }
    catch {
        # Ignore errors during cleanup
        Write-RKLog "Error during process cleanup (non-critical): $($_.Exception.Message)" -Level 'WARN' -Component 'WEBSERVER'
    }
    
    # Start web server
    try {
        $docRoot = $config.webServer.docRoot
        $port = $config.webServer.port
        
        Write-RKLog "Starting Python web server on port $port, serving $docRoot" -Component 'WEBSERVER'
        
        # Verify document root exists and is accessible
        if (!(Test-Path $docRoot)) {
            throw "Document root does not exist: $docRoot"
        }
        
        # Start Python web server as background job
        $scriptBlock = {
            param($DocRoot, $Port)
            Set-Location $DocRoot
            
            # Use Python's HTTP server with improved error handling
            python -m http.server $Port 2>&1
        }
        
        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $docRoot, $port -Name "RK-WebServer"
        
        # Wait for server to start
        $retryCount = 0
        $maxRetries = 10
        $serverStarted = $false
        
        while ($retryCount -lt $maxRetries -and -not $serverStarted) {
            Start-Sleep -Seconds 1
            $retryCount++
            
            if (Test-WebServerStatus) {
                $serverStarted = $true
                break
            }
        }
        
        # Verify server started successfully
        if ($serverStarted) {
            Write-RKLog "Web server started successfully (Job ID: $($job.Id), Attempts: $retryCount)" -Level 'SUCCESS' -Component 'WEBSERVER'
            
            # Save job information for later management
            $jobInfo = @{
                JobId = $job.Id
                StartTime = Get-Date
                Port = $port
                DocRoot = $docRoot
                ComputerName = $config.system.computerName
                UserName = $config.system.userName
            }
            
            $jobInfoPath = Join-Path $config.logging.path "webserver-job.json"
            $jobInfo | ConvertTo-Json | Set-Content $jobInfoPath -Encoding UTF8
            
            # Test access to the web server
            try {
                $testResponse = Invoke-WebRequest -Uri "http://localhost:$port" -TimeoutSec 5 -UseBasicParsing
                Write-RKLog "Web server accessibility test passed (Status: $($testResponse.StatusCode))" -Level 'SUCCESS' -Component 'WEBSERVER'
            }
            catch {
                Write-RKLog "Web server started but accessibility test failed: $($_.Exception.Message)" -Level 'WARN' -Component 'WEBSERVER'
            }
        }
        else {
            # Check job status for error details
            $jobState = if ($job) { $job.State } else { "Unknown" }
            $jobError = if ($job -and $job.State -eq "Failed") { 
                Receive-Job $job 2>&1 | Out-String 
            } else { 
                "No specific error information available" 
            }
            
            throw "Web server failed to respond after $maxRetries seconds. Job State: $jobState. Error: $jobError"
        }
    }
    catch {
        $errorMsg = "Failed to start web server: $($_.Exception.Message)"
        Write-RKLog $errorMsg -Level 'ERROR' -Component 'WEBSERVER'
        
        # Clean up failed job
        if ($job) {
            try {
                Stop-Job $job -ErrorAction SilentlyContinue
                Remove-Job $job -ErrorAction SilentlyContinue
            }
            catch {
                # Ignore cleanup errors
            }
        }
        
        if (-not $Silent) {
            Send-RKNotification -Subject "Web Server Startup Failed" -Body $errorMsg -ShowUserAlert -UserMessage "Your computer manual could not start properly. The support team has been notified and will fix this."
        }
        exit 1
    }
}
catch {
    $errorMsg = "Critical error in web server startup: $($_.Exception.Message)"
    Write-RKLog $errorMsg -Level 'ERROR' -Component 'WEBSERVER'
    
    if (-not $Silent) {
        Send-RKNotification -Subject "Web Server Critical Error" -Body $errorMsg -ShowUserAlert -UserMessage "There was a serious problem starting your computer manual. The support team has been notified."
    }
    exit 1
}