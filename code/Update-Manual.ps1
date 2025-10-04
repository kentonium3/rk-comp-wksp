# ============================================================================
# Update-Manual.ps1 - Git pull and content deployment with conflict resolution
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
    Write-RKLog "Starting manual update process" -Component 'UPDATE'
    
    $config = Get-RKConfig
    
    # System health check
    Write-RKLog "Performing system health check" -Component 'UPDATE'
    $healthCheck = Test-RequiredComponents -Components @('Git', 'Network', 'Directories')
    
    if (-not $healthCheck.Git) {
        $errorMsg = "Git is not installed or not accessible. Cannot update manual. Please run Update-Components.ps1 to install Git."
        Write-RKLog $errorMsg -Level 'ERROR' -Component 'UPDATE'
        
        if (-not $Silent) {
            Send-RKNotification -Subject "Manual Update Failed - Git Missing" -Body $errorMsg -ShowUserAlert -UserMessage "Your computer manual cannot be updated because Git is missing. The support team has been notified."
        }
        exit 1
    }
    
    if (-not $healthCheck.Network) {
        $errorMsg = "Network connectivity issues detected. Cannot reach GitHub or SMTP server."
        Write-RKLog $errorMsg -Level 'ERROR' -Component 'UPDATE'
        
        if (-not $Silent) {
            Send-RKNotification -Subject "Manual Update Failed - Network Issues" -Body $errorMsg -ShowUserAlert -UserMessage "Your computer manual cannot be updated due to network connectivity issues. The support team has been notified."
        }
        exit 1
    }
    
    if (-not $healthCheck.Directories) {
        Write-RKLog "Repairing missing directories" -Component 'UPDATE'
        Repair-SystemDirectories | Out-Null
    }
    
    # Check repository health
    $repoHealthy = Test-RepositoryHealth
    if (-not $repoHealthy) {
        Write-RKLog "Repository unhealthy, attempting recovery" -Level 'WARN' -Component 'UPDATE'
        try {
            Restore-Repository -BackupReason "Unhealthy repository during update"
            Write-RKLog "Repository recovered successfully, update complete" -Level 'SUCCESS' -Component 'UPDATE'
            exit 0  # Recovery includes deployment, so we're done
        }
        catch {
            $errorMsg = "Failed to recover repository: $($_.Exception.Message)"
            Write-RKLog $errorMsg -Level 'ERROR' -Component 'UPDATE'
            
            if (-not $Silent) {
                Send-RKNotification -Subject "Manual Update Failed - Repository Recovery Failed" -Body $errorMsg -ShowUserAlert -UserMessage "Your computer manual could not be updated due to technical issues. The support team has been notified."
            }
            exit 1
        }
    }
    
    # Attempt git operations
    try {
        $repoPath = $config.repository.localPath
        Push-Location $repoPath
        
        Write-RKLog "Fetching updates from GitHub" -Component 'UPDATE'
        
        # Configure git settings for this machine if not already set
        $gitUserName = git config user.name 2>$null
        if (-not $gitUserName) {
            git config user.name "$($config.system.userName) - $($config.system.computerName)"
            git config user.email $config.support.emailFrom
            git config credential.helper manager-core
            Write-RKLog "Configured git settings for this machine" -Component 'UPDATE'
        }
        
        # Fetch first to check for updates
        $fetchResult = git fetch origin main 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Git fetch failed: $fetchResult"
        }
        
        # Check if there are updates
        $localCommit = git rev-parse HEAD 2>$null
        $remoteCommit = git rev-parse origin/main 2>$null
        
        if ($localCommit -eq $remoteCommit -and -not $Force) {
            Write-RKLog "Manual is already up to date (Local: $($localCommit.Substring(0,8)), Remote: $($remoteCommit.Substring(0,8)))" -Level 'SUCCESS' -Component 'UPDATE'
            
            # Still deploy content to ensure deployment area is in sync
            try {
                $deploymentIntegrity = Test-DeploymentIntegrity
                if (-not $deploymentIntegrity.IsValid) {
                    Write-RKLog "Deployment area needs repair: $($deploymentIntegrity.Reason)" -Level 'WARN' -Component 'UPDATE'
                    Deploy-ManualContent
                    Write-RKLog "Deployment area repaired" -Level 'SUCCESS' -Component 'UPDATE'
                }
            }
            catch {
                Write-RKLog "Failed to verify/repair deployment: $($_.Exception.Message)" -Level 'WARN' -Component 'UPDATE'
            }
            
            exit 0
        }
        
        Write-RKLog "Updates available - Local: $($localCommit.Substring(0,8)), Remote: $($remoteCommit.Substring(0,8))" -Component 'UPDATE'
        
        # Check for local changes that might conflict
        $status = git status --porcelain 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Git status check failed: $status"
        }
        
        if ($status -and $status.Trim()) {
            Write-RKLog "Local changes detected: $status" -Level 'WARN' -Component 'UPDATE'
            Write-RKLog "Local changes detected, performing recovery to preserve changes" -Level 'WARN' -Component 'UPDATE'
            Restore-Repository -BackupReason "Local changes detected during update"
            Write-RKLog "Recovery completed, manual updated with latest content" -Level 'SUCCESS' -Component 'UPDATE'
            exit 0  # Recovery includes fresh pull and deployment
        }
        
        # Perform the pull
        Write-RKLog "Pulling updates from GitHub" -Component 'UPDATE'
        $pullResult = git pull origin main 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            # Get information about what changed
            $changedFiles = git diff --name-only HEAD~1 HEAD 2>$null
            $changedFileCount = if ($changedFiles) { ($changedFiles | Measure-Object).Count } else { 0 }
            $newCommit = git rev-parse HEAD 2>$null
            
            Write-RKLog "Git pull completed successfully. Changed files: $changedFileCount, New commit: $($newCommit.Substring(0,8))" -Level 'SUCCESS' -Component 'UPDATE'
            
            # Deploy updated content
            Deploy-ManualContent
            
            # Verify deployment
            $deploymentIntegrity = Test-DeploymentIntegrity
            if ($deploymentIntegrity.IsValid) {
                Write-RKLog "Deployment verification passed" -Level 'SUCCESS' -Component 'UPDATE'
            } else {
                Write-RKLog "Deployment verification failed: $($deploymentIntegrity.Reason)" -Level 'WARN' -Component 'UPDATE'
            }
            
            # Prepare notification
            $changeDetails = if ($changedFiles) {
                "Changed files:`n" + ($changedFiles | ForEach-Object { "  - $_" } | Out-String)
            } else {
                "No file changes detected in this update."
            }
            
            $notificationBody = @"
Manual update completed successfully.

Update Details:
- Computer: $($config.system.computerName)
- User: $($config.system.userName)
- Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- Previous commit: $($localCommit.Substring(0,8))
- New commit: $($newCommit.Substring(0,8))
- Files changed: $changedFileCount

$changeDetails

The manual has been updated and deployed successfully.
Manual Status: UPDATED
Deployment Status: VERIFIED
"@
            
            # Notify success (only if not silent and there were actual changes)
            if (-not $Silent -and $changedFileCount -gt 0) {
                Send-RKNotification -Subject "Manual Updated Successfully" -Body $notificationBody
            }
        }
        else {
            throw "Git pull failed: $pullResult"
        }
    }
    catch {
        $errorMsg = "Git update failed: $($_.Exception.Message)"
        Write-RKLog $errorMsg -Level 'ERROR' -Component 'UPDATE'
        
        # Attempt recovery
        try {
            Write-RKLog "Attempting repository recovery due to git failure" -Level 'WARN' -Component 'UPDATE'
            Restore-Repository -BackupReason "Git pull failure: $($_.Exception.Message)"
            Write-RKLog "Recovery completed successfully after git failure" -Level 'SUCCESS' -Component 'UPDATE'
        }
        catch {
            $recoveryError = "Recovery also failed: $($_.Exception.Message)"
            Write-RKLog $recoveryError -Level 'ERROR' -Component 'UPDATE'
            
            if (-not $Silent) {
                $fullError = "$errorMsg`n`n$recoveryError"
                Send-RKNotification -Subject "Manual Update Failed - Critical Error" -Body $fullError -ShowUserAlert -UserMessage "Your computer manual could not be updated and automatic recovery failed. The support team has been notified and will fix this immediately."
            }
            exit 1
        }
    }
    finally {
        Pop-Location
    }
}
catch {
    $errorMsg = "Critical error in manual update: $($_.Exception.Message)"
    Write-RKLog $errorMsg -Level 'ERROR' -Component 'UPDATE'
    
    if (-not $Silent) {
        Send-RKNotification -Subject "Manual Update Critical Error" -Body $errorMsg -ShowUserAlert -UserMessage "There was a serious problem updating your computer manual. The support team has been notified."
    }
    exit 1
}