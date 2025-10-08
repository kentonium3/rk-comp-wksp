# ============================================================================
# Deploy-RKSystem.ps1 - Complete system deployment and setup
# ============================================================================

param(
    [string]$TargetUser = $env:USERNAME,
    [string]$GitHubRepo = "https://github.com/kentonium3/rk-comp-wksp.git",
    [switch]$SkipCredentials,
    [switch]$SkipScheduledTasks,
    [switch]$Force
)

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "  Rob's Computer Manual - System Deployment" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

# Check if running as administrator for scheduled tasks
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

Write-Host "Target User: $TargetUser" -ForegroundColor Cyan
Write-Host "Repository: $GitHubRepo" -ForegroundColor Cyan
Write-Host "Administrator: $(if($isAdmin){'Yes'}else{'No'})" -ForegroundColor Cyan
Write-Host ""

try {
    $userProfile = if ($TargetUser -eq $env:USERNAME) { $env:USERPROFILE } else { "C:\Users\$TargetUser" }
    $repoPath = Join-Path $userProfile "rk-comp-wksp"
    $deployPath = Join-Path $userProfile "Documents\Rob's Computer Manual"
    $desktopPath = Join-Path $userProfile "Desktop"
    
    Write-Host "Installation Paths:" -ForegroundColor Yellow
    Write-Host "  Repository: $repoPath" -ForegroundColor Gray
    Write-Host "  Manual: $deployPath" -ForegroundColor Gray
    Write-Host "  Desktop: $desktopPath" -ForegroundColor Gray
    Write-Host ""
    
    # Step 1: Check Prerequisites
    Write-Host "Step 1: Checking Prerequisites..." -ForegroundColor Yellow
    
    # Check if Git is available
    $gitAvailable = $false
    try {
        $gitVersion = git --version 2>&1
        if ($gitVersion -match "git version") {
            Write-Host "  [OK] Git found: $gitVersion" -ForegroundColor Green
            $gitAvailable = $true
        }
    }
    catch {
        Write-Host "  [X] Git not found" -ForegroundColor Red
    }
    
    # Check if Python is available
    $pythonAvailable = $false
    try {
        $pythonVersion = python --version 2>&1
        if ($pythonVersion -match "Python \d+\.\d+") {
            Write-Host "  [OK] Python found: $pythonVersion" -ForegroundColor Green
            $pythonAvailable = $true
        }
    }
    catch {
        Write-Host "  [X] Python not found" -ForegroundColor Red
    }
    
    # Check if winget is available for installing missing components
    $wingetAvailable = $false
    try {
        $wingetVersion = winget --version 2>&1
        if ($wingetVersion -match "v\d+\.\d+") {
            Write-Host "  [OK] Windows Package Manager found: $wingetVersion" -ForegroundColor Green
            $wingetAvailable = $true
        }
    }
    catch {
        Write-Host "  [X] Windows Package Manager not found" -ForegroundColor Yellow
    }
    
    # Step 2: Install Missing Components
    if (-not $gitAvailable -or -not $pythonAvailable) {
        Write-Host ""
        Write-Host "Step 2: Installing Missing Components..." -ForegroundColor Yellow
        
        if ($wingetAvailable) {
            if (-not $gitAvailable) {
                Write-Host "  Installing Git..." -ForegroundColor Gray
                winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements | Out-Null
                if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
                    Write-Host "  [OK] Git installed" -ForegroundColor Green
                    # Refresh PATH
                    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                } else {
                    Write-Host "  [X] Git installation failed" -ForegroundColor Red
                }
            }
            
            if (-not $pythonAvailable) {
                Write-Host "  Installing Python..." -ForegroundColor Gray
                winget install --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements | Out-Null
                if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
                    Write-Host "  [OK] Python installed" -ForegroundColor Green
                    # Refresh PATH
                    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                    
                    # Ensure Python is in System PATH for scheduled tasks
                    if ($isAdmin) {
                        Write-Host "  Configuring Python for system-wide access..." -ForegroundColor Gray
                        $pythonLocations = @(
                            "$env:LOCALAPPDATA\Programs\Python\Python*",
                            "C:\Python*",
                            "C:\Program Files\Python*"
                        )
                        
                        $pythonDir = $null
                        foreach ($pattern in $pythonLocations) {
                            $found = Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                            if ($found) {
                                $pythonDir = $found.FullName
                                break
                            }
                        }
                        
                        if ($pythonDir) {
                            $systemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
                            $pathsToAdd = @($pythonDir, (Join-Path $pythonDir "Scripts"))
                            $needsUpdate = $false
                            
                            foreach ($pathToAdd in $pathsToAdd) {
                                if ($systemPath -notlike "*$pathToAdd*") {
                                    $systemPath += ";$pathToAdd"
                                    $needsUpdate = $true
                                }
                            }
                            
                            if ($needsUpdate) {
                                [Environment]::SetEnvironmentVariable("PATH", $systemPath, "Machine")
                                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                                Write-Host "  [OK] Python added to System PATH" -ForegroundColor Green
                            } else {
                                Write-Host "  [OK] Python already in System PATH" -ForegroundColor Green
                            }
                        } else {
                            Write-Host "  [!] Could not locate Python installation directory" -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "  [!] Admin privileges required to add Python to System PATH" -ForegroundColor Yellow
                        Write-Host "      Scheduled tasks may not work reliably" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  [X] Python installation failed" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "  [!] Cannot install components automatically - Windows Package Manager not available" -ForegroundColor Yellow
            Write-Host "  Please install Git and Python manually before continuing." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Git: https://git-scm.com/download/windows" -ForegroundColor White
            Write-Host "  Python: https://www.python.org/downloads/windows/" -ForegroundColor White
            
            $continue = Read-Host "`n  Continue anyway? (y/N)"
            if ($continue -notlike "y*") {
                Write-Host "Deployment cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    } else {
        Write-Host "  [OK] All prerequisites satisfied" -ForegroundColor Green
    }
    
    # Step 3: Clone Repository
    Write-Host ""
    Write-Host "Step 3: Setting up Repository..." -ForegroundColor Yellow
    
    if (Test-Path $repoPath) {
        if ($Force) {
            Write-Host "  Removing existing repository (Force flag set)..." -ForegroundColor Gray
            Remove-Item $repoPath -Recurse -Force
        } else {
            Write-Host "  Repository already exists at $repoPath" -ForegroundColor Yellow
            $overwrite = Read-Host "  Overwrite existing repository? (y/N)"
            if ($overwrite -like "y*") {
                Remove-Item $repoPath -Recurse -Force
            } else {
                Write-Host "  Using existing repository" -ForegroundColor Green
            }
        }
    }
    
    if (-not (Test-Path $repoPath)) {
        Write-Host "  Cloning repository from $GitHubRepo..." -ForegroundColor Gray
        $parentDir = Split-Path $repoPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        }
        
        Push-Location $parentDir
        git clone $GitHubRepo (Split-Path $repoPath -Leaf) 2>&1 | Out-Null
        Pop-Location
        
        if (Test-Path $repoPath) {
            Write-Host "  [OK] Repository cloned successfully" -ForegroundColor Green
        } else {
            throw "Failed to clone repository"
        }
    }
    
    # Configure git for this user
    Push-Location $repoPath
    git config user.name "$TargetUser - $env:COMPUTERNAME"
    git config user.email "robkanzer@robkanzer.com"
    git config credential.helper manager-core
    git config credential.useHttpPath true
    Pop-Location
    Write-Host "  [OK] Git configuration updated" -ForegroundColor Green
    Write-Host "    Note: If prompted for GitHub credentials, use kentonium3 username" -ForegroundColor Gray
    
    # Step 4: Create Configuration
    Write-Host ""
    Write-Host "Step 4: Creating Configuration..." -ForegroundColor Yellow
    
    $configDir = Join-Path $repoPath "config"
    if (-not (Test-Path $configDir)) {
        New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    }
    
    $configPath = Join-Path $configDir "settings.json"
    $config = @{
        support = @{
            contacts = @(
                @{ name = "Kent Gale"; email = "kentgale@gmail.com" }
            )
            emailFrom = "robkanzer@robkanzer.com"
            smtpServer = "smtp.gmail.com"
            smtpPort = 587
        }
        webServer = @{
            port = 8080
            docRoot = $deployPath
        }
        repository = @{
            localPath = $repoPath
            deployPath = $deployPath
            githubUrl = $GitHubRepo
        }
        logging = @{
            path = Join-Path $deployPath "logs"
            retentionDays = 30
        }
        system = @{
            computerName = $env:COMPUTERNAME
            userName = $TargetUser
            userProfile = $userProfile
        }
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    Write-Host "  [OK] Configuration file created" -ForegroundColor Green
    
    # Step 5: Initial Deployment
    Write-Host ""
    Write-Host "Step 5: Deploying Manual Content..." -ForegroundColor Yellow
    
    $sourceContent = Join-Path $repoPath "rk-comp-man"
    
    if (Test-Path $sourceContent) {
        # Create deployment directory if it doesn't exist
        if (-not (Test-Path $deployPath)) {
            New-Item -Path $deployPath -ItemType Directory -Force | Out-Null
        }
        
        # Copy all content from repository to deployment location
        Copy-Item "$sourceContent\*" -Destination $deployPath -Recurse -Force
        
        if (Test-Path (Join-Path $deployPath "index.html")) {
            Write-Host "  [OK] Manual content deployed" -ForegroundColor Green
        } else {
            Write-Host "  [!] Manual deployment may have failed - index.html not found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [!] Manual content not found in repository" -ForegroundColor Yellow
    }
    
    # Step 6: Create Desktop Shortcuts
    Write-Host ""
    Write-Host "Step 6: Creating Desktop Shortcuts..." -ForegroundColor Yellow
    
    # 1. Refresh batch file shortcut
    $batchFile = Join-Path $repoPath "code\Manual-Refresh.bat"
    $refreshShortcut = Join-Path $desktopPath "Refresh Rob's Manual.bat"
    
    if (Test-Path $batchFile) {
        Copy-Item $batchFile $refreshShortcut -Force
        Write-Host "  [OK] Refresh shortcut created" -ForegroundColor Green
    } else {
        Write-Host "  [!] Manual refresh batch file not found" -ForegroundColor Yellow
    }
    
    # 2. Browser shortcut with custom icon
    $iconFile = Join-Path $repoPath "code\RKMan.ico"
    $browserShortcut = Join-Path $desktopPath "Rob's Computer Manual.url"
    
    if (Test-Path $iconFile) {
        $urlContent = @"
[InternetShortcut]
URL=http://localhost:8080
IconFile=$iconFile
IconIndex=0
"@
        Set-Content -Path $browserShortcut -Value $urlContent -Encoding ASCII
        Write-Host "  [OK] Browser shortcut created with custom icon" -ForegroundColor Green
    } else {
        # Create without custom icon if icon file missing
        $urlContent = @"
[InternetShortcut]
URL=http://localhost:8080
"@
        Set-Content -Path $browserShortcut -Value $urlContent -Encoding ASCII
        Write-Host "  [OK] Browser shortcut created (icon file not found)" -ForegroundColor Yellow
    }
    
    # Step 7: Set up Scheduled Tasks
    if (-not $SkipScheduledTasks) {
        Write-Host ""
        Write-Host "Step 7: Setting up Scheduled Tasks..." -ForegroundColor Yellow
        
        if ($isAdmin) {
            try {
                # Web Server startup task
                $webServerAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$repoPath\code\Start-WebServer.ps1`" -Silent"
                $webServerTrigger = New-ScheduledTaskTrigger -AtLogOn -User $TargetUser
                $webServerSettings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
                Register-ScheduledTask -TaskName "RK-ComputerManual-WebServer" -Action $webServerAction -Trigger $webServerTrigger -Settings $webServerSettings -Description "Starts web server for Rob's Computer Manual" -User $TargetUser -Force | Out-Null
                Write-Host "  [OK] Web server startup task created" -ForegroundColor Green
                
                # Daily update task
                $updateAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$repoPath\code\Update-Manual.ps1`" -Silent"
                $updateTrigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
                $updateSettings = New-ScheduledTaskSettingsSet -Hidden -StartWhenAvailable -RunOnlyIfNetworkAvailable
                Register-ScheduledTask -TaskName "RK-ComputerManual-DailyUpdate" -Action $updateAction -Trigger $updateTrigger -Settings $updateSettings -Description "Daily update of Rob's Computer Manual content" -User $TargetUser -Force | Out-Null
                Write-Host "  [OK] Daily update task created" -ForegroundColor Green
                
                # Weekly component update task
                $componentAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$repoPath\code\Update-Components.ps1`" -Silent"
                $componentTrigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At 8:00AM
                $componentSettings = New-ScheduledTaskSettingsSet -Hidden -StartWhenAvailable -RunOnlyIfNetworkAvailable
                Register-ScheduledTask -TaskName "RK-ComputerManual-WeeklyMaintenance" -Action $componentAction -Trigger $componentTrigger -Settings $componentSettings -Description "Weekly maintenance and component updates" -User $TargetUser -Force | Out-Null
                Write-Host "  [OK] Weekly maintenance task created" -ForegroundColor Green
                
            }
            catch {
                Write-Host "  [X] Failed to create scheduled tasks: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  [!] Administrator privileges required for scheduled tasks" -ForegroundColor Yellow
            Write-Host "    Run this script as administrator to set up automated tasks" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Skipping scheduled tasks (SkipScheduledTasks flag set)" -ForegroundColor Gray
    }
    
    # Step 8: Configure Credentials
    if (-not $SkipCredentials) {
        Write-Host ""
        Write-Host "Step 8: Configuring Email Credentials..." -ForegroundColor Yellow
        
        $setupScript = Join-Path $repoPath "code\Setup-RKCredentials.ps1"
        if (Test-Path $setupScript) {
            $runSetup = Read-Host "  Run credential setup now? (Y/n)"
            if ($runSetup -notlike "n*") {
                Push-Location (Join-Path $repoPath "code")
                powershell.exe -ExecutionPolicy Bypass -File "Setup-RKCredentials.ps1"
                Pop-Location
            } else {
                Write-Host "  [!] Skipping credential setup - run Setup-RKCredentials.ps1 later" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [!] Credential setup script not found" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Skipping credential setup (SkipCredentials flag set)" -ForegroundColor Gray
    }
    
    # Step 9: Start Web Server
    Write-Host ""
    Write-Host "Step 9: Starting Web Server..." -ForegroundColor Yellow
    
    $webServerScript = Join-Path $repoPath "code\Start-WebServer.ps1"
    if (Test-Path $webServerScript) {
        Push-Location (Join-Path $repoPath "code")
        powershell.exe -ExecutionPolicy Bypass -File "Start-WebServer.ps1" -Silent
        Pop-Location
        
        Start-Sleep -Seconds 3
        
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -UseBasicParsing
            Write-Host "  [OK] Web server started successfully" -ForegroundColor Green
            Write-Host "  Manual URL: http://localhost:8080" -ForegroundColor Cyan
        }
        catch {
            Write-Host "  [!] Web server may not have started properly" -ForegroundColor Yellow
        }
    }
    
    # Step 10: Final Health Check
    Write-Host ""
    Write-Host "Step 10: Final Health Check..." -ForegroundColor Yellow
    
    $healthScript = Join-Path $repoPath "code\Health-Check.ps1"
    if (Test-Path $healthScript) {
        Push-Location (Join-Path $repoPath "code")
        powershell.exe -ExecutionPolicy Bypass -File "Health-Check.ps1"
        Pop-Location
    }
    
    # Deployment Summary
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "  Deployment Complete!" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installation Summary:" -ForegroundColor Cyan
    Write-Host "  Repository: $repoPath" -ForegroundColor White
    Write-Host "  Manual: $deployPath" -ForegroundColor White
    Write-Host "  Web Server: http://localhost:8080" -ForegroundColor White
    Write-Host "  Desktop Shortcut: Refresh Rob's Manual.bat" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Open http://localhost:8080 to access the manual" -ForegroundColor White
    Write-Host "  2. Test the desktop refresh shortcut" -ForegroundColor White
    Write-Host "  3. Complete email credential setup if not done" -ForegroundColor White
    Write-Host "  4. Verify scheduled tasks are working (if admin)" -ForegroundColor White
    Write-Host ""
    Write-Host "Support: Kent Gale - kentgale@gmail.com" -ForegroundColor Cyan
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Host "Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error message above and try again." -ForegroundColor Yellow
    Write-Host "For assistance, contact: kentgale@gmail.com" -ForegroundColor Yellow
    exit 1
}