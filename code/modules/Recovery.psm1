# ============================================================================
# Recovery.psm1 - Backup and recovery operations
# ============================================================================

function Backup-ModifiedFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,
        
        [string]$BackupReason = "System Recovery"
    )
    
    $config = Get-RKConfig
    $timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
    $backupPath = Join-Path $config.repository.deployPath "backups\$timestamp"
    
    Write-RKLog "Starting backup of modified files from $SourcePath" -Component 'BACKUP'
    
    # Create backup directory
    if (!(Test-Path $backupPath)) {
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    }
    
    # Find modified files by comparing with repository
    $modifiedFiles = @()
    if (Test-Path $SourcePath) {
        $files = Get-ChildItem -Path $SourcePath -Recurse -File
        $repoManualPath = Join-Path $config.repository.localPath "rk-comp-man"
        
        foreach ($file in $files) {
            try {
                $relativePath = $file.FullName.Substring($SourcePath.Length).TrimStart('\', '/')
                $repoFile = Join-Path $repoManualPath $relativePath
                
                # Skip system files and directories we don't want to backup
                if ($relativePath -like "logs\*" -or $relativePath -like "backups\*" -or $relativePath -like ".obsidian\*") {
                    continue
                }
                
                $shouldBackup = $false
                
                if (Test-Path $repoFile) {
                    # File exists in repo, check if it's different
                    try {
                        $sourceHash = Get-FileHash $file.FullName -Algorithm MD5
                        $repoHash = Get-FileHash $repoFile -Algorithm MD5
                        
                        if ($sourceHash.Hash -ne $repoHash.Hash) {
                            $shouldBackup = $true
                            Write-RKLog "File modified: $relativePath" -Component 'BACKUP'
                        }
                    }
                    catch {
                        # If we can't compare, assume it's different
                        $shouldBackup = $true
                        Write-RKLog "Could not compare file, backing up: $relativePath" -Level 'WARN' -Component 'BACKUP'
                    }
                }
                else {
                    # File doesn't exist in repo, so it was added locally
                    $shouldBackup = $true
                    Write-RKLog "File added locally: $relativePath" -Component 'BACKUP'
                }
                
                if ($shouldBackup) {
                    $modifiedFiles += @{
                        OriginalFile = $file
                        RelativePath = $relativePath
                    }
                }
            }
            catch {
                Write-RKLog "Error processing file $($file.FullName): $($_.Exception.Message)" -Level 'WARN' -Component 'BACKUP'
            }
        }
    }
    
    # Copy modified files to backup
    $backupManifest = @{
        timestamp = $timestamp
        reason = $BackupReason
        computerName = $config.system.computerName
        userName = $config.system.userName
        sourcePath = $SourcePath
        files = @()
    }
    
    foreach ($fileInfo in $modifiedFiles) {
        try {
            $file = $fileInfo.OriginalFile
            $relativePath = $fileInfo.RelativePath
            $backupFile = Join-Path $backupPath $relativePath
            $backupDir = Split-Path $backupFile -Parent
            
            if (!(Test-Path $backupDir)) {
                New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
            }
            
            Copy-Item $file.FullName $backupFile -Force
            
            $backupManifest.files += @{
                originalPath = $file.FullName
                relativePath = $relativePath
                lastModified = $file.LastWriteTime
                size = $file.Length
                backupPath = $backupFile
            }
            
            Write-RKLog "Backed up: $relativePath" -Component 'BACKUP'
        }
        catch {
            Write-RKLog "Failed to backup file $($fileInfo.RelativePath): $($_.Exception.Message)" -Level 'ERROR' -Component 'BACKUP'
        }
    }
    
    # Save backup manifest
    $manifestPath = Join-Path $backupPath "backup-manifest.json"
    $backupManifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8
    
    # Create a readable summary file
    $summaryPath = Join-Path $backupPath "backup-summary.txt"
    $summaryContent = @"
Rob's Computer Manual - Backup Summary
=====================================

Backup Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Computer: $($config.system.computerName)
User: $($config.system.userName)
Reason: $BackupReason

Files Backed Up: $($modifiedFiles.Count)

File List:
$($backupManifest.files | ForEach-Object { "  - $($_.relativePath) (Modified: $($_.lastModified))" } | Out-String)

This backup was created automatically to preserve any changes that were
made locally before restoring the manual to its original state.

To restore these files, copy them from this backup folder back to:
$SourcePath

Support Contact: $($config.support.contacts[0].name) - $($config.support.contacts[0].email)
"@
    
    Set-Content $summaryPath -Value $summaryContent -Encoding UTF8
    
    Write-RKLog "Backup completed: $($modifiedFiles.Count) files backed up to $backupPath" -Level 'SUCCESS' -Component 'BACKUP'
    
    return @{
        BackupPath = $backupPath
        FileCount = $modifiedFiles.Count
        Manifest = $backupManifest
        SummaryFile = $summaryPath
    }
}

function Restore-Repository {
    [CmdletBinding()]
    param(
        [string]$BackupReason = "Repository Recovery"
    )
    
    $config = Get-RKConfig
    $repoPath = $config.repository.localPath
    $deployPath = $config.repository.deployPath
    
    Write-RKLog "Starting repository recovery process" -Level 'INFO' -Component 'RECOVERY'
    
    try {
        # Step 1: Backup any modified files in deployment area
        $backupResult = $null
        if (Test-Path $deployPath) {
            try {
                $backupResult = Backup-ModifiedFiles -SourcePath $deployPath -BackupReason $BackupReason
            }
            catch {
                Write-RKLog "Backup failed, but continuing with recovery: $($_.Exception.Message)" -Level 'WARN' -Component 'RECOVERY'
            }
        }
        
        # Step 2: Remove corrupted repository
        if (Test-Path $repoPath) {
            Write-RKLog "Removing corrupted repository: $repoPath" -Level 'INFO' -Component 'RECOVERY'
            try {
                # Try to remove gracefully first
                Remove-Item $repoPath -Recurse -Force -ErrorAction Stop
            }
            catch {
                # If normal removal fails, try more aggressive cleanup
                Write-RKLog "Normal removal failed, attempting forced cleanup" -Level 'WARN' -Component 'RECOVERY'
                Start-Sleep -Seconds 2
                
                # Kill any processes that might be holding file locks
                Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($repoPath) } | Stop-Process -Force -ErrorAction SilentlyContinue
                
                # Try removal again
                Start-Sleep -Seconds 1
                Remove-Item $repoPath -Recurse -Force
            }
        }
        
        # Step 3: Fresh clone from GitHub
        Write-RKLog "Cloning fresh repository from GitHub" -Component 'RECOVERY'
        try {
            $parentDir = Split-Path $repoPath -Parent
            if (!(Test-Path $parentDir)) {
                New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
            }
            
            Push-Location $parentDir
            $cloneResult = git clone $config.repository.githubUrl (Split-Path $repoPath -Leaf) 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-RKLog "Repository cloned successfully" -Level 'SUCCESS' -Component 'RECOVERY'
            }
            else {
                throw "Git clone failed with exit code $LASTEXITCODE. Output: $cloneResult"
            }
        }
        finally {
            Pop-Location
        }
        
        # Step 4: Configure git for this machine
        try {
            Push-Location $repoPath
            git config user.name "$($config.system.userName) - $($config.system.computerName)"
            git config user.email $config.support.emailFrom
            git config credential.helper manager-core
            Write-RKLog "Git configuration updated" -Component 'RECOVERY'
        }
        finally {
            Pop-Location
        }
        
        # Step 5: Deploy fresh content
        Deploy-ManualContent
        
        # Step 6: Notify about recovery
        $notificationBody = @"
Repository recovery completed successfully.

Recovery Details:
- Computer: $($config.system.computerName)
- User: $($config.system.userName)
- Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- Reason: $BackupReason
- Files backed up: $(if ($backupResult) { $backupResult.FileCount } else { "0" })
- Backup location: $(if ($backupResult) { $backupResult.BackupPath } else { "N/A" })

The system has been restored to working order with the latest content from GitHub.
$(if ($backupResult -and $backupResult.FileCount -gt 0) { "`nPlease review the backed up files to determine if any changes need to be preserved.`nBackup summary: $($backupResult.SummaryFile)" } else { "`nNo local changes were found to backup." })

Next Steps:
1. Review any backed up files
2. Test the manual functionality
3. Check that scheduled tasks are working

Repository Status: HEALTHY
Manual Status: DEPLOYED
"@
        
        $userMessage = if ($backupResult -and $backupResult.FileCount -gt 0) {
            "I found some changes to your manual files and saved them safely. The manual has been restored to working order. Your support person has been notified about the saved changes."
        } else {
            "Your computer manual has been restored to working order. No local changes were found. Your support person has been notified that the recovery is complete."
        }
        
        Send-RKNotification -Subject "Repository Recovered Successfully" -Body $notificationBody -ShowUserAlert -UserMessage $userMessage
        
        Write-RKLog "Repository recovery completed successfully" -Level 'SUCCESS' -Component 'RECOVERY'
        return $backupResult
    }
    catch {
        $errorMsg = "Repository recovery failed: $($_.Exception.Message)"
        Write-RKLog $errorMsg -Level 'ERROR' -Component 'RECOVERY'
        
        Send-RKNotification -Subject "Repository Recovery Failed" -Body $errorMsg -ShowUserAlert -UserMessage "There was a serious problem with your computer manual that could not be automatically fixed. Your support person has been notified and will help resolve this."
        
        throw
    }
}

function Deploy-ManualContent {
    [CmdletBinding()]
    param([switch]$Force)
    
    $config = Get-RKConfig
    $sourcePath = Join-Path $config.repository.localPath "rk-comp-man"
    $deployPath = $config.repository.deployPath
    
    Write-RKLog "Starting manual content deployment" -Component 'DEPLOY'
    
    if (!(Test-Path $sourcePath)) {
        throw "Source path does not exist: $sourcePath"
    }
    
    # Ensure deploy directory structure exists
    $deployDir = Split-Path $deployPath -Parent
    if (!(Test-Path $deployDir)) {
        New-Item -Path $deployDir -ItemType Directory -Force | Out-Null
    }
    
    # Create logs and backups directories
    $logsDir = Join-Path $deployPath "logs"
    $backupsDir = Join-Path $deployPath "backups"
    
    if (!(Test-Path $logsDir)) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }
    if (!(Test-Path $backupsDir)) {
        New-Item -Path $backupsDir -ItemType Directory -Force | Out-Null
    }
    
    # Clear deployment area (except logs and backups)
    if (Test-Path $deployPath) {
        Get-ChildItem -Path $deployPath | Where-Object { 
            $_.Name -ne "logs" -and $_.Name -ne "backups" 
        } | Remove-Item -Recurse -Force
    }
    else {
        New-Item -Path $deployPath -ItemType Directory -Force | Out-Null
    }
    
    # Copy content from repository, excluding certain patterns
    $excludePatterns = @('.obsidian', '.git', '*.tmp', 'Thumbs.db', '.DS_Store')
    $deployedFiles = 0
    
    try {
        $items = Get-ChildItem -Path $sourcePath -Recurse
        
        foreach ($item in $items) {
            $relativePath = $item.FullName.Substring($sourcePath.Length + 1)
            $shouldExclude = $false
            
            # Check exclusion patterns
            foreach ($pattern in $excludePatterns) {
                if ($relativePath -like $pattern -or $relativePath -like "*\$pattern*" -or $relativePath -like "*/$pattern*") {
                    $shouldExclude = $true
                    break
                }
            }
            
            if (-not $shouldExclude) {
                $targetPath = Join-Path $deployPath $relativePath
                $targetDir = Split-Path $targetPath -Parent
                
                if (!(Test-Path $targetDir)) {
                    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                }
                
                if ($item -is [System.IO.FileInfo]) {
                    Copy-Item $item.FullName $targetPath -Force
                    $deployedFiles++
                }
            }
        }
        
        Write-RKLog "Manual content deployed successfully: $deployedFiles files to $deployPath" -Level 'SUCCESS' -Component 'DEPLOY'
        
        # Verify critical files exist
        $criticalFiles = @('index.html')
        foreach ($file in $criticalFiles) {
            $filePath = Join-Path $deployPath $file
            if (!(Test-Path $filePath)) {
                Write-RKLog "Critical file missing after deployment: $file" -Level 'WARN' -Component 'DEPLOY'
            }
        }
        
        return $true
    }
    catch {
        Write-RKLog "Manual content deployment failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'DEPLOY'
        throw
    }
}

function Test-DeploymentIntegrity {
    [CmdletBinding()]
    param()
    
    $config = Get-RKConfig
    $deployPath = $config.repository.deployPath
    
    if (!(Test-Path $deployPath)) {
        return @{ IsValid = $false; Reason = "Deployment directory does not exist" }
    }
    
    # Check for critical files
    $criticalFiles = @('index.html')
    $missingFiles = @()
    
    foreach ($file in $criticalFiles) {
        $filePath = Join-Path $deployPath $file
        if (!(Test-Path $filePath)) {
            $missingFiles += $file
        }
    }
    
    if ($missingFiles.Count -gt 0) {
        return @{ 
            IsValid = $false
            Reason = "Missing critical files: $($missingFiles -join ', ')"
            MissingFiles = $missingFiles
        }
    }
    
    # Check if deployment is recent (within last 7 days)
    $indexFile = Join-Path $deployPath "index.html"
    $indexLastWrite = (Get-Item $indexFile).LastWriteTime
    $daysSinceUpdate = (Get-Date) - $indexLastWrite
    
    return @{
        IsValid = $true
        LastUpdate = $indexLastWrite
        DaysSinceUpdate = [math]::Floor($daysSinceUpdate.TotalDays)
        FileCount = (Get-ChildItem -Path $deployPath -Recurse -File | Measure-Object).Count
    }
}

function Repair-SystemDirectories {
    [CmdletBinding()]
    param()
    
    $config = Get-RKConfig
    $requiredPaths = @(
        $config.repository.localPath,
        $config.repository.deployPath,
        $config.logging.path,
        (Join-Path $config.repository.localPath "code"),
        (Join-Path $config.repository.localPath "config"),
        (Join-Path $config.repository.deployPath "logs"),
        (Join-Path $config.repository.deployPath "backups")
    )
    
    $created = @()
    
    foreach ($path in $requiredPaths) {
        if (!(Test-Path $path)) {
            try {
                New-Item -Path $path -ItemType Directory -Force | Out-Null
                $created += $path
                Write-RKLog "Created missing directory: $path" -Component 'REPAIR'
            }
            catch {
                Write-RKLog "Failed to create directory $path : $($_.Exception.Message)" -Level 'ERROR' -Component 'REPAIR'
            }
        }
    }
    
    if ($created.Count -gt 0) {
        Write-RKLog "Repaired $($created.Count) missing directories" -Level 'SUCCESS' -Component 'REPAIR'
    }
    
    return $created
}

# Export functions
Export-ModuleMember -Function Backup-ModifiedFiles, Restore-Repository, Deploy-ManualContent, Test-DeploymentIntegrity, Repair-SystemDirectories