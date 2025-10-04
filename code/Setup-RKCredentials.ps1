# ============================================================================
# Setup-RKCredentials.ps1 - One-time setup for Gmail App Password
# ============================================================================

# Get script directory and import modules
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$modulesDir = Join-Path $scriptDir "modules"

try {
    Import-Module (Join-Path $modulesDir "Configuration.psm1") -Force
    Import-Module (Join-Path $modulesDir "Logging.psm1") -Force
    Import-Module (Join-Path $modulesDir "Notifications.psm1") -Force
}
catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "  Rob's Computer Manual - Credential Setup" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""

try {
    $config = Get-RKConfig
    
    Write-Host "This setup will configure email notifications for the computer manual system." -ForegroundColor Yellow
    Write-Host "Computer: $($config.system.computerName)" -ForegroundColor Cyan
    Write-Host "User: $($config.system.userName)" -ForegroundColor Cyan
    Write-Host "Email Account: $($config.support.emailFrom)" -ForegroundColor Cyan
    Write-Host ""
    
    # Check if credentials already exist
    $existingCredential = Get-RKStoredCredential -Target "RKComputerManual-Gmail"
    if ($existingCredential) {
        Write-Host "Gmail credentials are already configured." -ForegroundColor Yellow
        $response = Read-Host "Do you want to update them? (y/N)"
        if ($response -notlike "y*") {
            Write-Host "Setup cancelled. Existing credentials will be used." -ForegroundColor Green
            exit 0
        }
    }
    
    Write-Host "To create a Gmail App Password:" -ForegroundColor Cyan
    Write-Host "1. Go to https://myaccount.google.com/security" -ForegroundColor White
    Write-Host "2. Enable 2-factor authentication if not already enabled" -ForegroundColor White
    Write-Host "3. Go to 'App passwords' and create a new app password" -ForegroundColor White
    Write-Host "4. Select 'Mail' and 'Windows Computer' as the app and device" -ForegroundColor White
    Write-Host "5. Copy the 16-character password (no spaces)" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: The app password should look like: abcd efgh ijkl mnop" -ForegroundColor Yellow
    Write-Host "Enter it without spaces: abcdefghijklmnop" -ForegroundColor Yellow
    Write-Host ""
    
    # Get the app password
    $appPassword = Read-Host "Enter the Gmail App Password" -AsSecureString
    
    if (-not $appPassword -or $appPassword.Length -eq 0) {
        Write-Host "No password entered. Setup cancelled." -ForegroundColor Red
        exit 1
    }
    
    # Store the credential
    Write-Host ""
    Write-Host "Storing credential securely..." -ForegroundColor Yellow
    
    $credentialStored = Set-RKStoredCredential -Target "RKComputerManual-Gmail" -Username $config.support.emailFrom -Password $appPassword
    
    if (-not $credentialStored) {
        Write-Host "Failed to store credentials. Please try again." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[OK] Credential stored successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Testing email configuration..." -ForegroundColor Yellow
    
    # Test email sending
    try {
        $testBody = @"
This is a test email to confirm that the Rob's Computer Manual notification system is working correctly.

System Information:
- Computer: $($config.system.computerName)
- User: $($config.system.userName)
- Setup Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- PowerShell Version: $($PSVersionTable.PSVersion)
- OS: $([System.Environment]::OSVersion.VersionString)

If you receive this email, the notification system is configured properly and ready to send alerts about the computer manual system.

Test completed successfully.
"@
        
        Send-RKEmail -Subject "Test - Credential Setup Complete" -Body $testBody
        Write-Host "[OK] Email test successful! Credentials configured correctly." -ForegroundColor Green
        
        # Log the successful setup
        Write-RKLog "Gmail credentials configured and tested successfully" -Level 'SUCCESS' -Component 'SETUP'
        
    }
    catch {
        Write-Host "[X] Email test failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Possible issues:" -ForegroundColor Yellow
        Write-Host "- App password may be incorrect" -ForegroundColor White
        Write-Host "- 2-factor authentication may not be enabled" -ForegroundColor White
        Write-Host "- Network connectivity issues" -ForegroundColor White
        Write-Host "- Gmail security settings may be blocking the connection" -ForegroundColor White
        Write-Host ""
        Write-Host "Please check the App Password and try running this setup again." -ForegroundColor Red
        
        # Log the failure
        Write-RKLog "Email test failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'SETUP'
        
        exit 1
    }
    
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host "  Setup Completed Successfully!" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "The computer manual system is now ready to send notifications." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Run Update-Manual.ps1 to download the latest manual content" -ForegroundColor White
    Write-Host "2. Run Start-WebServer.ps1 to start the manual web server" -ForegroundColor White
    Write-Host "3. Set up scheduled tasks for automatic updates" -ForegroundColor White
    Write-Host ""
    Write-Host "Support contact: $($config.support.contacts[0].name) - $($config.support.contacts[0].email)" -ForegroundColor Yellow
    Write-Host ""
    
    # Offer to run initial setup tasks
    $runSetup = Read-Host "Would you like to run the initial manual update now? (Y/n)"
    if ($runSetup -notlike "n*") {
        Write-Host ""
        Write-Host "Running initial manual update..." -ForegroundColor Yellow
        
        try {
            $updateScript = Join-Path $scriptDir "Update-Manual.ps1"
            if (Test-Path $updateScript) {
                & $updateScript -Force
                Write-Host "[OK] Initial manual update completed!" -ForegroundColor Green
            } else {
                Write-Host "Update-Manual.ps1 not found. Please run it manually later." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Manual update failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "You can run Update-Manual.ps1 manually later." -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "Setup complete! Press any key to exit..." -ForegroundColor Green
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
}
catch {
    Write-Host ""
    Write-Host "Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please try running the setup again or contact support." -ForegroundColor Yellow
    Write-Host "Support: $($config.support.contacts[0].email)" -ForegroundColor Yellow
    
    # Log the failure
    Write-RKLog "Credential setup failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'SETUP'
    
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Red
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}