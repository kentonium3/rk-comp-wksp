# ============================================================================
# Health-Check.ps1 - Comprehensive system health check and diagnostics
# ============================================================================

param(
    [switch]$Detailed,
    [switch]$Export,
    [string]$OutputPath
)

# Get script directory and import modules
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$modulesDir = Join-Path $scriptDir "modules"

try {
    Import-Module (Join-Path $modulesDir "Configuration.psm1") -Force
    Import-Module (Join-Path $modulesDir "Logging.psm1") -Force
    Import-Module (Join-Path $modulesDir "SystemChecks.psm1") -Force
    Import-Module (Join-Path $modulesDir "Recovery.psm1") -Force
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

function Show-HealthStatus {
    param($Name, $Status, $Details = "")
    
    $icon = if ($Status) { "[OK]" } else { "[X]" }
    $color = if ($Status) { "Green" } else { "Red" }
    $statusText = if ($Status) { "OK" } else { "FAILED" }
    
    Write-Host "$icon $Name : " -NoNewline
    Write-Host $statusText -ForegroundColor $color
    
    if ($Details -and $Detailed) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

function Get-DetailedReport {
    param($Config, $Health, $SystemDetails)
    
    $report = @"
========================================
Rob's Computer Manual - Health Report
========================================

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $($Config.system.computerName)
User: $($Config.system.userName)

OVERALL STATUS: $(if($Health.Overall){'HEALTHY'}else{'NEEDS ATTENTION'})

========================================
COMPONENT STATUS
========================================

Python: $(if($Health.Python){'[OK] OK'}else{'[X] FAILED'})
Git: $(if($Health.Git){'[OK] OK'}else{'[X] FAILED'}) 
Repository: $(if($Health.Repository){'[OK] OK'}else{'[X] FAILED'})
Web Server: $(if($Health.WebServer){'[OK] OK'}else{'[X] FAILED'})
Directories: $(if($Health.Directories){'[OK] OK'}else{'[X] FAILED'})
Credentials: $(if($Health.Credentials){'[OK] OK'}else{'[X] FAILED'})
Network: $(if($Health.Network){'[OK] OK'}else{'[X] FAILED'})

========================================
SYSTEM INFORMATION
========================================

PowerShell Version: $($SystemDetails.PowerShellVersion)
Operating System: $($SystemDetails.OSVersion)
.NET Version: $($SystemDetails.DotNetVersion)
Architecture: $($SystemDetails.Architecture)
Time Zone: $($SystemDetails.TimeZone)
Last Boot: $($SystemDetails.LastBootTime)
Execution Policy: $($SystemDetails.ExecutionPolicy)

========================================
CONFIGURATION
========================================

Repository Path: $($Config.repository.localPath)
Deployment Path: $($Config.repository.deployPath)
Web Server Port: $($Config.webServer.port)
Log Directory: $($Config.logging.path)
Log Retention: $($Config.logging.retentionDays) days

Email From: $($Config.support.emailFrom)
SMTP Server: $($Config.support.smtpServer):$($Config.support.smtpPort)
Support Contacts: $($Config.support.contacts.name -join ', ')

========================================
LOG SUMMARY (LAST 24 HOURS)
========================================

Total Entries: $($SystemDetails.LogSummary.TotalEntries)
Errors: $($SystemDetails.LogSummary.ErrorCount)
Warnings: $($SystemDetails.LogSummary.WarningCount)
Last Activity: $($SystemDetails.LogSummary.LastActivity)
Log Files: $($SystemDetails.LogSummary.LogFiles)

========================================
WEB SERVER STATUS
========================================
"@

    # Add web server process information
    $webServerProcess = Get-WebServerProcess
    if ($webServerProcess) {
        $report += @"

Process ID: $($webServerProcess.ProcessId)
Process Name: $($webServerProcess.ProcessName)
Start Time: $($webServerProcess.StartTime)
Port: $($webServerProcess.Port)
Connection State: $($webServerProcess.State)
"@
    } else {
        $report += "`nWeb server process not found or not running."
    }
    
    # Add deployment status
    $deploymentStatus = Test-DeploymentIntegrity
    $report += @"

========================================
DEPLOYMENT STATUS
========================================

Deployment Valid: $(if($deploymentStatus.IsValid){'[OK] YES'}else{'[X] NO'})
"@
    
    if ($deploymentStatus.IsValid) {
        $report += @"
Last Update: $($deploymentStatus.LastUpdate)
Days Since Update: $($deploymentStatus.DaysSinceUpdate)
File Count: $($deploymentStatus.FileCount)
"@
    } else {
        $report += "Issue: $($deploymentStatus.Reason)"
    }
    
    # Add scheduled tasks status (Windows specific)
    if ($IsWindows -or $env:OS -like "*Windows*") {
        $report += @"

========================================
SCHEDULED TASKS
========================================
"@
        try {
            $tasks = Get-ScheduledTask -TaskName "RK-ComputerManual-*" -ErrorAction SilentlyContinue
            if ($tasks) {
                foreach ($task in $tasks) {
                    $taskInfo = Get-ScheduledTaskInfo $task -ErrorAction SilentlyContinue
                    $lastRun = if ($taskInfo.LastRunTime -eq (Get-Date "1/1/1900")) { "Never" } else { $taskInfo.LastRunTime }
                    $nextRun = if ($taskInfo.NextRunTime -eq (Get-Date "1/1/1900")) { "Not scheduled" } else { $taskInfo.NextRunTime }
                    
                    $report += @"

Task: $($task.TaskName)
State: $($task.State)
Last Run: $lastRun
Next Run: $nextRun
Last Result: $($taskInfo.LastTaskResult)
"@
                }
            } else {
                $report += "`nNo RK-ComputerManual scheduled tasks found."
            }
        }
        catch {
            $report += "`nError retrieving scheduled task information: $($_.Exception.Message)"
        }
    }
    
    $report += @"

========================================
RECOMMENDATIONS
========================================
"@
    
    # Add recommendations based on health status
    $recommendations = @()
    
    if (-not $Health.Python) {
        $recommendations += "• Install Python by running Update-Components.ps1"
    }
    
    if (-not $Health.Git) {
        $recommendations += "• Install Git by running Update-Components.ps1"
    }
    
    if (-not $Health.Repository) {
        $recommendations += "• Repository needs repair - run Update-Manual.ps1 to fix"
    }
    
    if (-not $Health.WebServer) {
        $recommendations += "• Start web server by running Start-WebServer.ps1"
    }
    
    if (-not $Health.Credentials) {
        $recommendations += "• Configure email credentials by running Setup-RKCredentials.ps1"
    }
    
    if (-not $Health.Network) {
        $recommendations += "• Check internet connection and firewall settings"
    }
    
    if ($SystemDetails.LogSummary.ErrorCount -gt 5) {
        $recommendations += "• High error count in logs - review recent log files"
    }
    
    if ($deploymentStatus.IsValid -and $deploymentStatus.DaysSinceUpdate -gt 7) {
        $recommendations += "• Manual content is outdated - run Manual-Refresh.bat"
    }
    
    if ($recommendations.Count -eq 0) {
        $report += "`nAll systems are healthy! No action needed."
    } else {
        $report += "`n" + ($recommendations -join "`n")
    }
    
    $report += @"

========================================
SUPPORT INFORMATION
========================================

For assistance, contact: $($Config.support.contacts[0].name)
Email: $($Config.support.contacts[0].email)

When contacting support, please include this health report.

Report generated by: Health-Check.ps1
System uptime: $((Get-Date) - $SystemDetails.LastBootTime)
"@
    
    return $report
}

try {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "  Rob's Computer Manual - Health Check" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""
    
    # Get configuration and system info
    $config = Get-RKConfig
    Write-Host "Computer: $($config.system.computerName)" -ForegroundColor Cyan
    Write-Host "User: $($config.system.userName)" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ""
    
    # Perform health check
    Write-Host "Performing health check..." -ForegroundColor Yellow
    $health = Test-RKSystemHealth -Detailed
    $systemDetails = Get-SystemDetails
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  Component Status" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    # Display results
    Show-HealthStatus "Python" $health.Python
    Show-HealthStatus "Git" $health.Git
    Show-HealthStatus "Repository" $health.Repository
    Show-HealthStatus "Web Server" $health.WebServer
    Show-HealthStatus "Directories" $health.Directories
    Show-HealthStatus "Credentials" $health.Credentials
    Show-HealthStatus "Network" $health.Network
    
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    $overallColor = if ($health.Overall) { "Green" } else { "Red" }
    $overallStatus = if ($health.Overall) { "HEALTHY" } else { "NEEDS ATTENTION" }
    Write-Host "Overall Status: " -NoNewline
    Write-Host $overallStatus -ForegroundColor $overallColor
    Write-Host "=========================================" -ForegroundColor Cyan
    
    # Show web server process info if available
    $webServerProcess = Get-WebServerProcess
    if ($webServerProcess) {
        Write-Host ""
        Write-Host "Web Server Process:" -ForegroundColor Yellow
        Write-Host "  PID: $($webServerProcess.ProcessId)" -ForegroundColor Gray
        Write-Host "  Started: $($webServerProcess.StartTime)" -ForegroundColor Gray
        Write-Host "  Port: $($webServerProcess.Port)" -ForegroundColor Gray
    }
    
    # Show deployment status
    $deploymentStatus = Test-DeploymentIntegrity
    Write-Host ""
    Write-Host "Deployment Status:" -ForegroundColor Yellow
    if ($deploymentStatus.IsValid) {
        Write-Host "  [OK] Valid deployment" -ForegroundColor Green
        Write-Host "  Last updated: $($deploymentStatus.LastUpdate)" -ForegroundColor Gray
        Write-Host "  Days since update: $($deploymentStatus.DaysSinceUpdate)" -ForegroundColor Gray
    } else {
        Write-Host "  [X] Invalid deployment: $($deploymentStatus.Reason)" -ForegroundColor Red
    }
    
    # Show log summary
    Write-Host ""
    Write-Host "Recent Activity (24 hours):" -ForegroundColor Yellow
    Write-Host "  Log entries: $($systemDetails.LogSummary.TotalEntries)" -ForegroundColor Gray
    Write-Host "  Errors: $($systemDetails.LogSummary.ErrorCount)" -ForegroundColor Gray
    Write-Host "  Warnings: $($systemDetails.LogSummary.WarningCount)" -ForegroundColor Gray
    
    # Generate detailed report if requested
    if ($Detailed -or $Export) {
        $detailedReport = Get-DetailedReport -Config $config -Health $health -SystemDetails $systemDetails
        
        if ($Detailed) {
            Write-Host ""
            Write-Host $detailedReport
        }
        
        if ($Export) {
            if (-not $OutputPath) {
                $OutputPath = Join-Path $config.logging.path "health-report-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').txt"
            }
            
            $detailedReport | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Host ""
            Write-Host "Detailed report exported to: $OutputPath" -ForegroundColor Green
        }
    }
    
    # Quick recommendations
    if (-not $health.Overall) {
        Write-Host ""
        Write-Host "Quick Actions:" -ForegroundColor Yellow
        
        if (-not $health.Python -or -not $health.Git) {
            Write-Host "  • Run Update-Components.ps1 to install missing tools" -ForegroundColor White
        }
        
        if (-not $health.Repository) {
            Write-Host "  • Run Update-Manual.ps1 to repair repository" -ForegroundColor White
        }
        
        if (-not $health.WebServer) {
            Write-Host "  • Run Start-WebServer.ps1 to start the manual" -ForegroundColor White
        }
        
        if (-not $health.Credentials) {
            Write-Host "  • Run Setup-RKCredentials.ps1 to configure email" -ForegroundColor White
        }
    }
    
    Write-Host ""
    
    # Log the health check
    $healthStatus = if ($health.Overall) { "HEALTHY" } else { "NEEDS ATTENTION" }
    Write-RKLog "Health check completed: $healthStatus" -Level $(if ($health.Overall) { 'SUCCESS' } else { 'WARN' }) -Component 'HEALTH'
    
}
catch {
    Write-Host "Health check failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-RKLog "Health check failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'HEALTH'
    exit 1
}