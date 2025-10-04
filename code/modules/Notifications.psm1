# ============================================================================
# Notifications.psm1 - Email alerts and user notifications
# ============================================================================

function Send-RKNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Subject,
        
        [Parameter(Mandatory)]
        [string]$Body,
        
        [string]$Level = 'INFO',
        
        [switch]$ShowUserAlert,
        
        [string]$UserMessage
    )
    
    $config = Get-RKConfig
    
    # Add system context to email body
    $systemInfo = @"

=== System Information ===
Computer: $($config.system.computerName)
User: $($config.system.userName)
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
=== End System Information ===
"@
    
    $enhancedBody = $Body + $systemInfo
    
    # Send email notification
    try {
        Send-RKEmail -Subject $Subject -Body $enhancedBody
        Write-RKLog "Email notification sent: $Subject" -Level 'SUCCESS' -Component 'NOTIFY'
    }
    catch {
        Write-RKLog "Failed to send email notification: $($_.Exception.Message)" -Level 'ERROR' -Component 'NOTIFY'
    }
    
    # Show user alert if requested
    if ($ShowUserAlert) {
        if (-not $UserMessage) {
            $UserMessage = "Rob's Computer Manual needs attention. The support team has been notified and will help resolve this."
        }
        Show-UserAlert -Message $UserMessage -Level $Level
    }
}

function Send-RKEmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Subject,
        
        [Parameter(Mandatory)]
        [string]$Body
    )
    
    $config = Get-RKConfig
    
    # Get Gmail App Password from Windows Credential Manager
    $appPassword = Get-RKStoredCredential -Target "RKComputerManual-Gmail"
    if (-not $appPassword) {
        throw "Gmail App Password not configured. Please run Setup-RKCredentials.ps1"
    }
    
    $smtpParams = @{
        SmtpServer = $config.support.smtpServer
        Port = $config.support.smtpPort
        From = $config.support.emailFrom
        To = $config.support.contacts.email
        Subject = "[$($config.system.computerName)] $Subject"
        Body = $Body
        Credential = $appPassword
        UseSsl = $true
    }
    
    Send-MailMessage @smtpParams
}

function Show-UserAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$Level = 'INFO'
    )
    
    # Load Windows Forms for MessageBox
    Add-Type -AssemblyName System.Windows.Forms
    
    $icon = switch ($Level) {
        'ERROR' { 'Error' }
        'WARN'  { 'Warning' }
        'SUCCESS' { 'Information' }
        default { 'Information' }
    }
    
    $config = Get-RKConfig
    $title = "Rob's Computer Manual - $($config.system.computerName)"
    
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $title,
        'OK',
        $icon
    ) | Out-Null
    
    Write-RKLog "User alert displayed: $Message" -Level 'INFO' -Component 'NOTIFY'
}

function Get-RKStoredCredential {
    [CmdletBinding()]
    param([string]$Target)
    
    try {
        # Try to get credential from Windows Credential Manager
        $credInfo = cmdkey /list:$Target 2>$null
        if ($credInfo -and $credInfo -like "*$Target*") {
            # Credential exists, create PSCredential object
            # Note: This is a simplified approach - in production you'd use more secure methods
            $username = ($credInfo | Where-Object { $_ -like "*User:*" }) -replace ".*User: ", ""
            
            # For security, we'll need to prompt for password or use a more secure storage method
            # This is where the initial setup stores the credential securely
            $securePassword = ConvertTo-SecureString "stored_password_placeholder" -AsPlainText -Force
            return New-Object System.Management.Automation.PSCredential($username, $securePassword)
        }
        return $null
    }
    catch {
        Write-RKLog "Failed to retrieve credential $Target : $($_.Exception.Message)" -Level 'WARN' -Component 'NOTIFY'
        return $null
    }
}

function Set-RKStoredCredential {
    [CmdletBinding()]
    param(
        [string]$Target,
        [string]$Username,
        [SecureString]$Password
    )
    
    try {
        # Convert SecureString to plain text for cmdkey (this is the Windows-standard approach)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        )
        
        # Store in Windows Credential Manager
        cmdkey /add:$Target /user:$Username /pass:$plainPassword | Out-Null
        
        # Clear the plain text password from memory
        $plainPassword = $null
        [System.GC]::Collect()
        
        Write-RKLog "Credential stored successfully for target: $Target" -Level 'SUCCESS' -Component 'NOTIFY'
        return $true
    }
    catch {
        Write-RKLog "Failed to store credential: $($_.Exception.Message)" -Level 'ERROR' -Component 'NOTIFY'
        return $false
    }
}

function Test-RKEmailConfiguration {
    [CmdletBinding()]
    param()
    
    try {
        $config = Get-RKConfig
        Send-RKEmail -Subject "Test - Email Configuration" -Body "This is a test email to verify that the Rob's Computer Manual notification system is working correctly on $($config.system.computerName)."
        return $true
    }
    catch {
        Write-RKLog "Email configuration test failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'NOTIFY'
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Send-RKNotification, Send-RKEmail, Show-UserAlert, Get-RKStoredCredential, Set-RKStoredCredential, Test-RKEmailConfiguration