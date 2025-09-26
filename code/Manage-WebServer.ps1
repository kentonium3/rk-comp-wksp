# ============================================================================
# Manage-WebServer.ps1 - Web server management utility
# ============================================================================

param(
    [Parameter(Mandatory)]
    [ValidateSet('Start', 'Stop', 'Restart', 'Status', 'Kill')]
    [string]$Action,
    
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
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

function Stop-RKWebServer {
    param([switch]$Force)
    
    $config = Get-RKConfig
    $port = $config.webServer.port
    $stopped = $false
    
    Write-RKLog "Attempting to stop web server on port $port" -Component 'WEBSERVER'
    
    try {
        # First, try to find and stop processes using the port
        $connections = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        if ($connections) {
            foreach ($conn in $connections) {
                try {
                    $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                    if ($process) {
                        Write-RKLog "Stopping process: $($process.ProcessName) (PID: $($process.Id))" -Component 'WEBSERVER'
                        
                        if ($Force) {
                            $process | Stop-Process -Force
                        } else {
                            $process | Stop-Process
                        }
                        $stopped = $true
                    }
                }
                catch {
                    Write-RKLog "Failed to stop process $($conn.OwningProcess): $($_.Exception.Message)" -Level 'WARN' -Component 'WEBSERVER'
                }
            }
        }
        
        # Also stop any PowerShell jobs named RK-WebServer
        $jobs = Get-Job -Name "RK-WebServer" -ErrorAction SilentlyContinue
        if ($jobs) {
            foreach ($job in $jobs) {
                try {
                    Write-RKLog "Stopping PowerShell job: $($job.Name) (ID: $($job.Id))" -Component 'WEBSERVER'
                    Stop-Job $job
                    Remove-Job $job
                    $stopped = $true
                }
                catch {
                    Write-RKLog "Failed to stop job $($job.Id): $($_.Exception.Message)" -Level 'WARN' -Component 'WEBSERVER'
                }
            }
        }
        
        # Clean up job info file
        $jobInfoPath = Join-Path $config.logging.path "webserver-job.json"
        if (Test-Path $jobInfoPath) {
            Remove-Item $jobInfoPath -Force -ErrorAction SilentlyContinue
        }
        
        # Wait a moment and verify
        Start-Sleep -Seconds 2
        
        if (-not (Test-WebServerStatus)) {
            Write-RKLog "Web server stopped successfully" -Level 'SUCCESS' -Component 'WEBSERVER'
            return $true
        } else {
            if ($stopped) {
                Write-RKLog "Process stopped but port still in use" -Level 'WARN' -Component 'WEBSERVER'
            } else {
                Write-RKLog "No web server process found to stop" -Level 'WARN' -Component 'WEBSERVER'
            }
            return $false
        }
    }
    catch {
        Write-RKLog "Error stopping web server: $($_.Exception.Message)" -Level 'ERROR' -Component 'WEBSERVER'
        return $false
    }
}

function Get-RKWebServerStatus {
    $config = Get-RKConfig
    $port = $config.webServer.port
    
    $status = @{
        IsRunning = Test-WebServerStatus
        Port = $port
        Process = $null
        Job = $null
        URL = "http://localhost:$port"
        JobInfoFile = Join-Path $config.logging.path "webserver-job.json"
    }
    
    # Get process information
    $processInfo = Get-WebServerProcess
    if ($processInfo) {
        $status.Process = $processInfo
    }
    
    # Get job information
    $jobs = Get-Job -Name "RK-WebServer" -ErrorAction SilentlyContinue
    if ($jobs) {
        $status.Job = $jobs | Select-Object -First 1
    }
    
    # Get job info from file
    if (Test-Path $status.JobInfoFile) {
        try {
            $jobInfo = Get-Content $status.JobInfoFile -Raw | ConvertFrom-Json
            $status.JobInfo = $jobInfo
        }
        catch {
            # Ignore errors reading job info file
        }
    }
    
    return $status
}

try {
    $config = Get-RKConfig
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Green
        Write-Host "  Web Server Management - $Action" -ForegroundColor Green
        Write-Host "=============================================" -ForegroundColor Green
        Write-Host ""
    }
    
    switch ($Action) {
        'Start' {
            Write-RKLog "Starting web server via management utility" -Component 'WEBSERVER'
            
            if (Test-WebServerStatus -and -not $Force) {
                $message = "Web server is already running on port $($config.webServer.port)"
                Write-RKLog $message -Level 'SUCCESS' -Component 'WEBSERVER'
                if (-not $Silent) {
                    Write-Host "✓ $message" -ForegroundColor Green
                }
            } else {
                $startScript = Join-Path $scriptDir "Start-WebServer.ps1"
                if (Test-Path $startScript) {
                    $arguments = if ($Force) { "-Force" } else { "" }
                    if ($Silent) { $arguments += " -Silent" }
                    
                    & $startScript $arguments.Split(' ')
                    
                    if (Test-WebServerStatus) {
                        if (-not $Silent) {
                            Write-Host "✓ Web server started successfully" -ForegroundColor Green
                            Write-Host "  URL: http://localhost:$($config.webServer.port)" -ForegroundColor Cyan
                        }
                    } else {
                        if (-not $Silent) {
                            Write-Host "✗ Web server failed to start" -ForegroundColor Red
                        }
                        exit 1
                    }
                } else {
                    Write-RKLog "Start-WebServer.ps1 not found" -Level 'ERROR' -Component 'WEBSERVER'
                    if (-not $Silent) {
                        Write-Host "✗ Start-WebServer.ps1 not found" -ForegroundColor Red
                    }
                    exit 1
                }
            }
        }
        
        'Stop' {
            Write-RKLog "Stopping web server via management utility" -Component 'WEBSERVER'
            
            if (-not (Test-WebServerStatus)) {
                $message = "Web server is not running"
                Write-RKLog $message -Level 'INFO' -Component 'WEBSERVER'
                if (-not $Silent) {
                    Write-Host "ℹ $message" -ForegroundColor Yellow
                }
            } else {
                $stopped = Stop-RKWebServer -Force:$Force
                
                if ($stopped -or -not (Test-WebServerStatus)) {
                    if (-not $Silent) {
                        Write-Host "✓ Web server stopped successfully" -ForegroundColor Green
                    }
                } else {
                    if (-not $Silent) {
                        Write-Host "✗ Failed to stop web server" -ForegroundColor Red
                    }
                    exit 1
                }
            }
        }
        
        'Restart' {
            Write-RKLog "Restarting web server via management utility" -Component 'WEBSERVER'
            
            if (-not $Silent) {
                Write-Host "Stopping web server..." -ForegroundColor Yellow
            }
            Stop-RKWebServer -Force:$Force | Out-Null
            
            Start-Sleep -Seconds 2
            
            if (-not $Silent) {
                Write-Host "Starting web server..." -ForegroundColor Yellow
            }
            
            $startScript = Join-Path $scriptDir "Start-WebServer.ps1"
            if (Test-Path $startScript) {
                $arguments = if ($Silent) { "-Silent" } else { "" }
                & $startScript $arguments.Split(' ')
                
                if (Test-WebServerStatus) {
                    if (-not $Silent) {
                        Write-Host "✓ Web server restarted successfully" -ForegroundColor Green
                        Write-Host "  URL: http://localhost:$($config.webServer.port)" -ForegroundColor Cyan
                    }
                } else {
                    if (-not $Silent) {
                        Write-Host "✗ Web server failed to restart" -ForegroundColor Red
                    }
                    exit 1
                }
            } else {
                Write-RKLog "Start-WebServer.ps1 not found" -Level 'ERROR' -Component 'WEBSERVER'
                if (-not $Silent) {
                    Write-Host "✗ Start-WebServer.ps1 not found" -ForegroundColor Red
                }
                exit 1
            }
        }
        
        'Status' {
            $status = Get-RKWebServerStatus
            
            if (-not $Silent) {
                Write-Host "Web Server Status:" -ForegroundColor Cyan
                Write-Host "  Running: $(if($status.IsRunning){'✓ Yes'}else{'✗ No'})" -ForegroundColor $(if($status.IsRunning){'Green'}else{'Red'})
                Write-Host "  Port: $($status.Port)" -ForegroundColor Gray
                Write-Host "  URL: $($status.URL)" -ForegroundColor Gray
                
                if ($status.Process) {
                    Write-Host "  Process ID: $($status.Process.ProcessId)" -ForegroundColor Gray
                    Write-Host "  Process Name: $($status.Process.ProcessName)" -ForegroundColor Gray
                    Write-Host "  Start Time: $($status.Process.StartTime)" -ForegroundColor Gray
                }
                
                if ($status.Job) {
                    Write-Host "  PowerShell Job: $($status.Job.Name) (State: $($status.Job.State))" -ForegroundColor Gray
                }
                
                if ($status.JobInfo) {
                    Write-Host "  Job Started: $($status.JobInfo.StartTime)" -ForegroundColor Gray
                    Write-Host "  Job Computer: $($status.JobInfo.ComputerName)" -ForegroundColor Gray
                }
            }
            
            # Test connectivity
            if ($status.IsRunning) {
                try {
                    $response = Invoke-WebRequest -Uri $status.URL -TimeoutSec 5 -UseBasicParsing
                    Write-RKLog "Web server connectivity test passed (Status: $($response.StatusCode))" -Level 'SUCCESS' -Component 'WEBSERVER'
                    if (-not $Silent) {
                        Write-Host "  Connectivity: ✓ OK (HTTP $($response.StatusCode))" -ForegroundColor Green
                    }
                }
                catch {
                    Write-RKLog "Web server connectivity test failed: $($_.Exception.Message)" -Level 'WARN' -Component 'WEBSERVER'
                    if (-not $Silent) {
                        Write-Host "  Connectivity: ✗ Failed ($($_.Exception.Message))" -ForegroundColor Red
                    }
                }
            }
        }
        
        'Kill' {
            Write-RKLog "Force killing all web server processes" -Component 'WEBSERVER'
            
            $killed = $false
            
            # Kill all Python processes on the port
            try {
                $connections = Get-NetTCPConnection -LocalPort $config.webServer.port -ErrorAction SilentlyContinue
                if ($connections) {
                    foreach ($conn in $connections) {
                        $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                        if ($process) {
                            Write-RKLog "Force killing process: $($process.ProcessName) (PID: $($process.Id))" -Component 'WEBSERVER'
                            $process | Stop-Process -Force
                            $killed = $true
                        }
                    }
                }
            }
            catch {
                Write-RKLog "Error force killing processes: $($_.Exception.Message)" -Level 'WARN' -Component 'WEBSERVER'
            }
            
            # Kill all RK-WebServer jobs
            try {
                $jobs = Get-Job -Name "RK-WebServer" -ErrorAction SilentlyContinue
                if ($jobs) {
                    foreach ($job in $jobs) {
                        Write-RKLog "Force stopping job: $($job.Name) (ID: $($job.Id))" -Component 'WEBSERVER'
                        Stop-Job $job -ErrorAction SilentlyContinue
                        Remove-Job $job -Force -ErrorAction SilentlyContinue
                        $killed = $true
                    }
                }
            }
            catch {
                Write-RKLog "Error force stopping jobs: $($_.Exception.Message)" -Level 'WARN' -Component 'WEBSERVER'
            }
            
            # Clean up job info file
            $jobInfoPath = Join-Path $config.logging.path "webserver-job.json"
            if (Test-Path $jobInfoPath) {
                Remove-Item $jobInfoPath -Force -ErrorAction SilentlyContinue
            }
            
            if ($killed) {
                if (-not $Silent) {
                    Write-Host "✓ Web server processes terminated" -ForegroundColor Green
                }
            } else {
                if (-not $Silent) {
                    Write-Host "ℹ No web server processes found to terminate" -ForegroundColor Yellow
                }
            }
        }
    }
    
    if (-not $Silent) {
        Write-Host ""
    }
    
}
catch {
    $errorMsg = "Web server management failed: $($_.Exception.Message)"
    Write-RKLog $errorMsg -Level 'ERROR' -Component 'WEBSERVER'
    
    if (-not $Silent) {
        Write-Host "✗ $errorMsg" -ForegroundColor Red
    }
    exit 1
}