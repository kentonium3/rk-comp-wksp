# ============================================================================
# Uninstall-RKSystem.ps1 - Complete system removal and cleanup
# ============================================================================

param(
    [string]$TargetUser = $env:USERNAME,
    [switch]$KeepLogs,
    [switch]$KeepCredentials,
    [switch]$Force,
    [switch]$Silent
)

if (-not $Silent) {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Red
    Write-Host "  Rob's Computer Manual - System Removal" -ForegroundColor Red
    Write-Host "=============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "WARNING: This will completely remove the Rob's Computer Manual system." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This will remove:" -ForegroundColor Red
    Write-Host "  • All scheduled tasks" -ForegroundColor Gray
    Write-Host "  • Repository and manual content" -ForegroundColor Gray
    Write-Host "  • Desktop shortcuts" -ForegroundColor Gray
    Write-Host "  • Web server processes" -ForegroundColor Gray
    Write-Host "  • Configuration files" -ForegroundColor Gray
    if (-not $KeepCredentials) {
        Write-Host "  • Stored Gmail credentials" -ForegroundColor Gray
    }
    if (-not $KeepLogs) {
        Write-Host "  • All log files" -ForegroundColor Gray
    }
    Write-Host ""
    
    if (-not $Force) {
        $confirm = Read-Host "Are you sure you want to proceed? Type 'DELETE' to confirm"
        if ($confirm -ne "DELETE") {
            Write-Host "Uninstall cancelled." -ForegroundColor Green
            exit 0
        }
    }
}

$removedItems = @()
$failedItems = @()

try {
    # Determine paths
    $userProfile = if ($TargetUser -eq $env:USERNAME) { $env:USERPROFILE } else { "C:\Users\$TargetUser" }
    $repoPath = Join-Path $userProfile "rk-comp-wksp"
    $deployPath = Join-Path $userProfile "Documents\Rob's Computer Manual"
    $desktopPath = Join-Path $userProfile "Desktop"
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "Target User: $TargetUser" -ForegroundColor Cyan
        Write-Host "Repository: $repoPath" -ForegroundColor Cyan
        Write-Host "Manual Content: $deployPath" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Starting removal process..." -ForegroundColor Yellow
    }
    
    # Step 1: Stop Web Server
    if (-not $Silent) { Write-Host "Step 1: Stopping web server..." -ForegroundColor Yellow }
    
    try {
        $webServerProcesses = Get-Process -Name "python" -ErrorAction SilentlyContinue | Where-Object {
            $_.CommandLine -like "*http.server*" -or $_.CommandLine -like "*-m SimpleHTTPServer*"
        }
        
        foreach ($process in $webServerProcesses) {
            Stop-Process -Id $process.Id -Force
            $removedItems += "Web server process (PID: $($process.Id))"
        }
        
        if (-not $Silent) { Write-Host "  [OK] Web server stopped" -ForegroundColor Green }
    }
    catch {
        $failedItems += "Web server stop: $($_.Exception.Message)"
        if (-not $Silent) { Write-Host "  [!] Web server stop failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    
    # Step 2: Remove Scheduled Tasks
    if (-not $Silent) { Write-Host "Step 2: Removing scheduled tasks..." -ForegroundColor Yellow }
    
    $taskNames = @(
        "RK-ComputerManual-WebServer",
        "RK-ComputerManual-DailyUpdate", 
        "RK-ComputerManual-WeeklyMaintenance"
    )
    
    foreach ($taskName in $taskNames) {
        try {
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($task) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                $removedItems += "Scheduled task: $taskName"
                if (-not $Silent) { Write-Host "  [OK] Removed task: $taskName" -ForegroundColor Green }
            }
        }
        catch {
            $failedItems += "Scheduled task ${taskName}: $($_.Exception.Message)"
            if (-not $Silent) { Write-Host "  [!] Failed to remove task ${taskName}: $($_.Exception.Message)" -ForegroundColor Yellow }
        }
    }
    
    # Step 3: Remove Desktop Shortcuts
    if (-not $Silent) { Write-Host "Step 3: Removing desktop shortcuts..." -ForegroundColor Yellow }
    
    $shortcuts = @(
        "Refresh Rob's Manual.bat",
        "Rob's Computer Manual.url",
        "Computer Manual.lnk",
        "Rob's Computer Manual.lnk"
    )
    
    foreach ($shortcut in $shortcuts) {
        try {
            $shortcutPath = Join-Path $desktopPath $shortcut
            if (Test-Path $shortcutPath) {
                Remove-Item $shortcutPath -Force
                $removedItems += "Desktop shortcut: $shortcut"
                if (-not $Silent) { Write-Host "  [OK] Removed: $shortcut" -ForegroundColor Green }
            }
        }
        catch {
            $failedItems += "Desktop shortcut ${shortcut}: $($_.Exception.Message)"
            if (-not $Silent) { Write-Host "  [!] Failed to remove ${shortcut}: $($_.Exception.Message)" -ForegroundColor Yellow }
        }
    }
    
    # Step 4: Remove Repository
    if (-not $Silent) { Write-Host "Step 4: Removing repository..." -ForegroundColor Yellow }
    
    try {
        if (Test-Path $repoPath) {
            Remove-Item $repoPath -Recurse -Force
            $removedItems += "Repository directory: $repoPath"
            if (-not $Silent) { Write-Host "  [OK] Repository removed" -ForegroundColor Green }
        } else {
            if (-not $Silent) { Write-Host "  [OK] Repository not found (already removed)" -ForegroundColor Green }
        }
    }
    catch {
        $failedItems += "Repository removal: $($_.Exception.Message)"
        if (-not $Silent) { Write-Host "  [X] Failed to remove repository: $($_.Exception.Message)" -ForegroundColor Red }
    }
    
    # Step 5: Remove Manual Content
    if (-not $Silent) { Write-Host "Step 5: Removing manual content..." -ForegroundColor Yellow }
    
    try {
        if (Test-Path $deployPath) {
            if ($KeepLogs) {
                # Remove everything except logs
                $items = Get-ChildItem $deployPath | Where-Object { $_.Name -ne "logs" }
                foreach ($item in $items) {
                    Remove-Item $item.FullName -Recurse -Force
                }
                $removedItems += "Manual content (logs preserved): $deployPath"
                if (-not $Silent) { Write-Host "  [OK] Manual content removed (logs preserved)" -ForegroundColor Green }
            } else {
                Remove-Item $deployPath -Recurse -Force
                $removedItems += "Manual content directory: $deployPath"
                if (-not $Silent) { Write-Host "  [OK] Manual content removed" -ForegroundColor Green }
            }
        } else {
            if (-not $Silent) { Write-Host "  [OK] Manual content not found (already removed)" -ForegroundColor Green }
        }
    }
    catch {
        $failedItems += "Manual content removal: $($_.Exception.Message)"
        if (-not $Silent) { Write-Host "  [X] Failed to remove manual content: $($_.Exception.Message)" -ForegroundColor Red }
    }
    
    # Step 6: Remove Stored Credentials
    if (-not $KeepCredentials) {
        if (-not $Silent) { Write-Host "Step 6: Removing stored credentials..." -ForegroundColor Yellow }
        
        try {
            # Try to remove from Windows Credential Manager
            $credTargets = @(
                "RKComputerManual-Gmail",
                "git:https://github.com/kentonium3/rk-comp-wksp.git"
            )
            
            foreach ($target in $credTargets) {
                try {
                    cmdkey /delete:$target | Out-Null
                    $removedItems += "Stored credential: $target"
                }
                catch {
                    # Credential may not exist, ignore
                }
            }
            
            if (-not $Silent) { Write-Host "  [OK] Credentials removed" -ForegroundColor Green }
        }
        catch {
            $failedItems += "Credential removal: $($_.Exception.Message)"
            if (-not $Silent) { Write-Host "  [!] Failed to remove some credentials: $($_.Exception.Message)" -ForegroundColor Yellow }
        }
    } else {
        if (-not $Silent) { Write-Host "Step 6: Keeping stored credentials (KeepCredentials flag set)" -ForegroundColor Gray }
    }
    
    # Step 7: Clean Registry (if any entries exist)
    if (-not $Silent) { Write-Host "Step 7: Cleaning registry entries..." -ForegroundColor Yellow }
    
    try {
        # Check for any startup entries
        $registryPaths = @(
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
        )
        
        foreach ($regPath in $registryPaths) {
            try {
                $entries = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                if ($entries) {
                    $rkEntries = $entries.PSObject.Properties | Where-Object { $_.Name -like "*RK*" -or $_.Name -like "*Rob*Manual*" }
                    foreach ($entry in $rkEntries) {
                        Remove-ItemProperty -Path $regPath -Name $entry.Name -ErrorAction SilentlyContinue
                        $removedItems += "Registry entry: $regPath\$($entry.Name)"
                    }
                }
            }
            catch {
                # Registry access may fail, ignore
            }
        }
        
        if (-not $Silent) { Write-Host "  [OK] Registry cleaned" -ForegroundColor Green }
    }
    catch {
        $failedItems += "Registry cleanup: $($_.Exception.Message)"
        if (-not $Silent) { Write-Host "  [!] Registry cleanup failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    
    # Final Summary
    if (-not $Silent) {
        Write-Host ""
        Write-Host "=============================================" -ForegroundColor Green
        Write-Host "  Uninstall Complete!" -ForegroundColor Green
        Write-Host "=============================================" -ForegroundColor Green
        Write-Host ""
        
        if ($removedItems.Count -gt 0) {
            Write-Host "Successfully removed $($removedItems.Count) items:" -ForegroundColor Green
            foreach ($item in $removedItems) {
                Write-Host "  [OK] $item" -ForegroundColor Gray
            }
        }
        
        if ($failedItems.Count -gt 0) {
            Write-Host ""
            Write-Host "Failed to remove $($failedItems.Count) items:" -ForegroundColor Yellow
            foreach ($item in $failedItems) {
                Write-Host "  [!] $item" -ForegroundColor Gray
            }
            Write-Host ""
            Write-Host "These failures are typically non-critical." -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "The Rob's Computer Manual system has been completely removed." -ForegroundColor Green
        Write-Host ""
        
        if ($KeepLogs) {
            Write-Host "Log files were preserved in: $deployPath\logs" -ForegroundColor Cyan
        }
        
        if ($KeepCredentials) {
            Write-Host "Gmail credentials were preserved for future reinstall." -ForegroundColor Cyan
        }
        
        Write-Host ""
        Write-Host "To reinstall, run Deploy-RKSystem.ps1" -ForegroundColor White
        Write-Host ""
    }
    
}
catch {
    if (-not $Silent) {
        Write-Host ""
        Write-Host "Uninstall failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Some items may have been partially removed." -ForegroundColor Yellow
        Write-Host "You may need to manually clean up remaining items." -ForegroundColor Yellow
    }
    exit 1
}

# Return summary for automated scripts
if ($Silent) {
    return @{
        RemovedItems = $removedItems
        FailedItems = $failedItems
        Success = ($failedItems.Count -eq 0)
    }
}
