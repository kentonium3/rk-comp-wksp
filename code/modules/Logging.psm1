# ============================================================================
# Logging.psm1 - Centralized logging with automatic rotation
# ============================================================================

function Write-RKLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO',
        
        [string]$Component = 'SYSTEM'
    )
    
    try {
        $config = Get-RKConfig
        $logDir = $config.logging.path
        
        # Ensure log directory exists
        if (!(Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        $logFile = Join-Path $logDir "rk-manual-$(Get-Date -Format 'yyyy-MM-dd').log"
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $computerName = $config.system.computerName
        $userName = $config.system.userName
        $logEntry = "[$timestamp] [$computerName\$userName] [$Level] [$Component] $Message"
        
        # Write to log file
        Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
        
        # Also write to console if running interactively
        if ($Host.UI.RawUI.WindowTitle -notlike "*Service*" -and $Host.UI.RawUI.WindowTitle -notlike "*Hidden*") {
            switch ($Level) {
                'ERROR' { Write-Host $logEntry -ForegroundColor Red }
                'WARN'  { Write-Host $logEntry -ForegroundColor Yellow }
                'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
                default { Write-Host $logEntry }
            }
        }
        
        # Cleanup old logs (but don't fail if this doesn't work)
        try {
            Remove-OldLogs -LogDir $logDir -RetentionDays $config.logging.retentionDays
        }
        catch {
            # Silently continue if log cleanup fails
        }
    }
    catch {
        # Fallback logging if something goes wrong
        $fallbackLog = "$env:TEMP\rk-manual-error.log"
        $fallbackEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] [LOGGING] Failed to write log: $($_.Exception.Message). Original message: $Message"
        Add-Content -Path $fallbackLog -Value $fallbackEntry -Encoding UTF8
    }
}

function Remove-OldLogs {
    [CmdletBinding()]
    param(
        [string]$LogDir,
        [int]$RetentionDays
    )
    
    if (Test-Path $LogDir) {
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        Get-ChildItem -Path $LogDir -Filter "*.log" | 
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

function Get-RKLogPath {
    [CmdletBinding()]
    param(
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd')
    )
    
    $config = Get-RKConfig
    return Join-Path $config.logging.path "rk-manual-$Date.log"
}

function Get-RKLogSummary {
    [CmdletBinding()]
    param(
        [int]$Days = 7
    )
    
    $config = Get-RKConfig
    $logDir = $config.logging.path
    
    if (!(Test-Path $logDir)) {
        return @{
            TotalEntries = 0
            ErrorCount = 0
            WarningCount = 0
            LastActivity = $null
        }
    }
    
    $startDate = (Get-Date).AddDays(-$Days)
    $logFiles = Get-ChildItem -Path $logDir -Filter "*.log" | 
                Where-Object { $_.LastWriteTime -gt $startDate }
    
    $totalEntries = 0
    $errorCount = 0
    $warningCount = 0
    $lastActivity = $null
    
    foreach ($file in $logFiles) {
        $content = Get-Content $file.FullName
        $totalEntries += $content.Count
        $errorCount += ($content | Where-Object { $_ -like "*[ERROR]*" }).Count
        $warningCount += ($content | Where-Object { $_ -like "*[WARN]*" }).Count
        
        if ($file.LastWriteTime -gt $lastActivity) {
            $lastActivity = $file.LastWriteTime
        }
    }
    
    return @{
        TotalEntries = $totalEntries
        ErrorCount = $errorCount
        WarningCount = $warningCount
        LastActivity = $lastActivity
        LogFiles = $logFiles.Count
    }
}

# Export functions
Export-ModuleMember -Function Write-RKLog, Get-RKLogPath, Get-RKLogSummary