# ============================================================================
# Update-Components.ps1 - System component updates (Python, Git, future tools)
# ============================================================================

param(
    [switch]$Silent,
    [string[]]$Components = @('Python', 'Git'),
    [switch]$Force
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

try {
    Write-RKLog "Starting component update check for: $($Components -join ', ')" -Component 'COMPONENTS'
    
    $config = Get-RKConfig
    $updateResults = @{}
    $installationLogs = @()
    
    # Check if winget is available
    $wingetAvailable = $false
    try {
        $wingetVersion = winget --version 2>&1
        if ($wingetVersion -and $wingetVersion -match "v\d+\.\d+") {
            $wingetAvailable = $true
            Write-RKLog "Windows Package Manager available: $wingetVersion" -Component 'COMPONENTS'
        }
    }
    catch {
        Write-RKLog "Windows Package Manager not available, will use alternative installation methods" -Level 'WARN' -Component 'COMPONENTS'
    }
    
    # Process each requested component
    foreach ($component in $Components) {
        $updateResults[$component] = @{
            WasInstalled = $false
            WasUpdated = $false
            Version = $null
            Error = $null
        }
        
        switch ($component) {
            'Python' {
                Write-RKLog "Checking Python installation" -Component 'COMPONENTS'
                
                $pythonInstalled = Test-PythonInstallation
                if (-not $pythonInstalled -or $Force) {
                    if ($pythonInstalled -and $Force) {
                        Write-RKLog "Force flag set, reinstalling Python" -Component 'COMPONENTS'
                    } else {
                        Write-RKLog "Python not found, installing" -Component 'COMPONENTS'
                    }
                    
                    try {
                        if ($wingetAvailable) {
                            Write-RKLog "Installing Python via Windows Package Manager" -Component 'COMPONENTS'
                            $installResult = winget install --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements 2>&1
                            $installationLogs += "Python installation output: $installResult"
                            
                            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
                                # Exit code -1978335189 often means "already installed" which is fine
                                Write-RKLog "Python installation completed via winget" -Level 'SUCCESS' -Component 'COMPONENTS'
                                $updateResults['Python'].WasInstalled = $true
                                
                                # Refresh PATH environment variable
                                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                                
                                # Verify installation
                                Start-Sleep -Seconds 5
                                if (Test-PythonInstallation) {
                                    $pythonVersion = python --version 2>&1
                                    $updateResults['Python'].Version = $pythonVersion
                                    Write-RKLog "Python verification successful: $pythonVersion" -Level 'SUCCESS' -Component 'COMPONENTS'
                                } else {
                                    throw "Python installation verification failed"
                                }
                            }
                            else {
                                throw "Python installation failed with exit code $LASTEXITCODE"
                            }
                        }
                        else {
                            # Fallback: Download and install Python manually
                            Write-RKLog "Installing Python via direct download (winget not available)" -Component 'COMPONENTS'
                            $pythonUrl = "https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"
                            $pythonInstaller = "$env:TEMP\python-installer.exe"
                            
                            Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
                            $installArgs = "/quiet InstallAllUsers=1 PrependPath=1 TargetDir=`"C:\Python312`""
                            $installProcess = Start-Process -FilePath $pythonInstaller -ArgumentList $installArgs -Wait -PassThru
                            
                            if ($installProcess.ExitCode -eq 0) {
                                Write-RKLog "Python installation completed via direct download" -Level 'SUCCESS' -Component 'COMPONENTS'
                                $updateResults['Python'].WasInstalled = $true
                                
                                # Clean up installer
                                Remove-Item $pythonInstaller -Force -ErrorAction SilentlyContinue
                                
                                # Refresh PATH
                                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                            }
                            else {
                                throw "Python installation failed with exit code $($installProcess.ExitCode)"
                            }
                        }
                    }
                    catch {
                        $errorMsg = "Failed to install Python: $($_.Exception.Message)"
                        Write-RKLog $errorMsg -Level 'ERROR' -Component 'COMPONENTS'
                        $updateResults['Python'].Error = $errorMsg
                    }
                }
                else {
                    $pythonVersion = python --version 2>&1
                    $updateResults['Python'].Version = $pythonVersion
                    Write-RKLog "Python already installed: $pythonVersion" -Level 'SUCCESS' -Component 'COMPONENTS'
                }
            }
            
            'Git' {
                Write-RKLog "Checking Git installation" -Component 'COMPONENTS'
                
                $gitInstalled = Test-GitInstallation
                if (-not $gitInstalled -or $Force) {
                    if ($gitInstalled -and $Force) {
                        Write-RKLog "Force flag set, reinstalling Git" -Component 'COMPONENTS'
                    } else {
                        Write-RKLog "Git not found, installing" -Component 'COMPONENTS'
                    }
                    
                    try {
                        if ($wingetAvailable) {
                            Write-RKLog "Installing Git via Windows Package Manager" -Component 'COMPONENTS'
                            $installResult = winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements 2>&1
                            $installationLogs += "Git installation output: $installResult"
                            
                            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
                                Write-RKLog "Git installation completed via winget" -Level 'SUCCESS' -Component 'COMPONENTS'
                                $updateResults['Git'].WasInstalled = $true
                                
                                # Refresh PATH environment variable
                                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                                
                                # Verify installation
                                Start-Sleep -Seconds 5
                                if (Test-GitInstallation) {
                                    $gitVersion = git --version 2>&1
                                    $updateResults['Git'].Version = $gitVersion
                                    Write-RKLog "Git verification successful: $gitVersion" -Level 'SUCCESS' -Component 'COMPONENTS'
                                } else {
                                    throw "Git installation verification failed"
                                }
                            }
                            else {
                                throw "Git installation failed with exit code $LASTEXITCODE"
                            }
                        }
                        else {
                            # Fallback: Download and install Git manually
                            Write-RKLog "Installing Git via direct download (winget not available)" -Component 'COMPONENTS'
                            $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.2/Git-2.42.0.2-64-bit.exe"
                            $gitInstaller = "$env:TEMP\git-installer.exe"
                            
                            Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing
                            $installArgs = "/VERYSILENT /NORESTART /NOCANCEL /SP- /SUPPRESSMSGBOXES"
                            $installProcess = Start-Process -FilePath $gitInstaller -ArgumentList $installArgs -Wait -PassThru
                            
                            if ($installProcess.ExitCode -eq 0) {
                                Write-RKLog "Git installation completed via direct download" -Level 'SUCCESS' -Component 'COMPONENTS'
                                $updateResults['Git'].WasInstalled = $true
                                
                                # Clean up installer
                                Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue
                                
                                # Refresh PATH
                                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                            }
                            else {
                                throw "Git installation failed with exit code $($installProcess.ExitCode)"
                            }
                        }
                    }
                    catch {
                        $errorMsg = "Failed to install Git: $($_.Exception.Message)"
                        Write-RKLog $errorMsg -Level 'ERROR' -Component 'COMPONENTS'
                        $updateResults['Git'].Error = $errorMsg
                    }
                }
                else {
                    $gitVersion = git --version 2>&1
                    $updateResults['Git'].Version = $gitVersion
                    Write-RKLog "Git already installed: $gitVersion" -Level 'SUCCESS' -Component 'COMPONENTS'
                }
            }
            
            # Future components can be added here
            # 'AppsScript' {
            #     # Implementation for Google Apps Script tools
            # }
            # 'CustomTools' {
            #     # Implementation for custom utility tools
            # }
            
            default {
                Write-RKLog "Unknown component requested: $component" -Level 'WARN' -Component 'COMPONENTS'
                $updateResults[$component].Error = "Unknown component"
            }
        }
    }
    
    # Report results
    $successfulUpdates = @()
    $failedUpdates = @()
    
    foreach ($component in $updateResults.Keys) {
        $result = $updateResults[$component]
        if ($result.Error) {
            $failedUpdates += "$component (Error: $($result.Error))"
        } elseif ($result.WasInstalled -or $result.WasUpdated) {
            $successfulUpdates += "$component ($($result.Version))"
        }
    }
    
    # Create summary
    $summary = @"
Component Update Summary:
Computer: $($config.system.computerName)
User: $($config.system.userName)
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Successful: $($successfulUpdates.Count)
$($successfulUpdates | ForEach-Object { "  ✓ $_" } | Out-String)

Failed: $($failedUpdates.Count)
$($failedUpdates | ForEach-Object { "  ✗ $_" } | Out-String)

Installation Logs:
$($installationLogs | Out-String)
"@
    
    if ($successfulUpdates.Count -gt 0) {
        $message = "Component updates completed: $($successfulUpdates -join ', ')"
        Write-RKLog $message -Level 'SUCCESS' -Component 'COMPONENTS'
        
        if (-not $Silent) {
            Send-RKNotification -Subject "Components Updated" -Body $summary
        }
    }
    
    if ($failedUpdates.Count -gt 0) {
        $message = "Some component updates failed: $($failedUpdates -join ', ')"
        Write-RKLog $message -Level 'ERROR' -Component 'COMPONENTS'
        
        if (-not $Silent) {
            Send-RKNotification -Subject "Component Update Failures" -Body $summary -ShowUserAlert -UserMessage "Some computer tools could not be updated automatically. The support team has been notified and will fix this."
        }
    }
    
    if ($successfulUpdates.Count -eq 0 -and $failedUpdates.Count -eq 0) {
        Write-RKLog "All components are up to date" -Level 'SUCCESS' -Component 'COMPONENTS'
    }
    
    # Exit with appropriate code
    if ($failedUpdates.Count -gt 0) {
        exit 1
    } else {
        exit 0
    }
}
catch {
    $errorMsg = "Critical error in component update: $($_.Exception.Message)"
    Write-RKLog $errorMsg -Level 'ERROR' -Component 'COMPONENTS'
    
    if (-not $Silent) {
        Send-RKNotification -Subject "Component Update Critical Error" -Body $errorMsg -ShowUserAlert -UserMessage "There was a serious problem updating your computer's tools. The support team has been notified."
    }
    exit 1
}