# rk-comp-wksp Maintenance Guide

**Target Audience**: Kent Gale (System Administrator)  
**System Status**: Production Deployment  
**Maintenance Philosophy**: Proactive monitoring with reactive troubleshooting  

## Overview

The rk-comp-wksp system is designed for minimal maintenance overhead through comprehensive automation and self-healing capabilities. This guide provides procedures for monitoring, troubleshooting, and maintaining the system in production.

## Monitoring Strategy

### Automated Monitoring

#### Email Notification System
**Purpose**: Immediate alert for system issues requiring attention

**Notification Triggers**:
- Web server startup failures
- Git pull/update failures  
- Component installation problems
- Scheduled task execution failures
- Repository conflict resolution failures

**Email Format**:
```
Subject: [RK-System] Alert: [Component] Issue on Rob's Machine
From: robkanzer@robkanzer.com
To: kent@kentgale.com

Alert Details:
- Timestamp: 2025-09-26 14:30:15
- Component: Web Server
- Issue: Failed to start on port 8080
- Error: Port already in use
- Auto-Recovery: Attempting port 8081
- Status: Resolved automatically
- Action Required: None

System Health Summary:
- Repository: Healthy
- Components: All functional
- Last Update: 2025-09-26 06:00:00
- Next Update: 2025-09-27 06:00:00

Logs available at: C:\Users\Rob\Documents\Rob's Computer Manual\logs\
```

#### Log Monitoring
**Automatic Rotation**: 30-day retention with automatic cleanup  
**Log Locations**: `%USERPROFILE%\Documents\Rob's Computer Manual\logs\`

**Log Files**:
- `webserver_YYYYMMDD.log` - Web server operations
- `update_YYYYMMDD.log` - Git pulls and content updates
- `health_YYYYMMDD.log` - System diagnostics
- `components_YYYYMMDD.log` - Component installations/updates

### Manual Monitoring

#### Weekly Health Check (Recommended)
```powershell
# Connect to Rob's machine via AnyDesk
# Navigate to system directory
Set-Location "$env:USERPROFILE\rk-comp-wksp\code"

# Run comprehensive health check
.\Health-Check.ps1

# Review recent logs
Get-ChildItem "$env:USERPROFILE\Documents\Rob's Computer Manual\logs" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 5

# Check scheduled task status
Get-ScheduledTask | Where-Object {$_.TaskName -like "*RK*"} | 
    Select-Object TaskName, State, LastRunTime, NextRunTime
```

#### Monthly System Review
1. **Component Versions**: Verify Python, Git versions current
2. **Log Analysis**: Review error patterns and frequency
3. **Performance Check**: Web server response times
4. **Credential Validation**: Test email notification system
5. **Repository Health**: Check for any manual changes or conflicts

## Troubleshooting Procedures

### Web Server Issues

#### Problem: Web Server Won't Start
**Symptoms**: Rob reports manual not accessible, port 8080 errors in logs

**Diagnostic Steps**:
```powershell
# Check if web server process is running
Get-Process python -ErrorAction SilentlyContinue

# Check port availability
netstat -an | findstr :8080

# Review web server logs
Get-Content "$env:USERPROFILE\Documents\Rob's Computer Manual\logs\webserver_$(Get-Date -Format 'yyyyMMdd').log" -Tail 20
```

**Resolution**:
```powershell
# Kill any stuck Python processes
Get-Process python -ErrorAction SilentlyContinue | Stop-Process -Force

# Restart web server with alternative port
.\Start-WebServer.ps1

# If persistent issues, restart web server management
.\Manage-WebServer.ps1 -Action Restart
```

#### Problem: Web Server Runs But Content Not Loading
**Symptoms**: Browser shows directory listing or 404 errors

**Diagnostic Steps**:
```powershell
# Verify content deployment
Test-Path "$env:USERPROFILE\Documents\Rob's Computer Manual\index.html"

# Check content directory structure
Get-ChildItem "$env:USERPROFILE\Documents\Rob's Computer Manual" -Recurse | Select-Object Name, Length

# Verify manual update process
.\Update-Manual.ps1 -Verbose
```

**Resolution**:
```powershell
# Force content re-deployment
.\Update-Manual.ps1

# If content missing, manual recovery
if (!(Test-Path "$env:USERPROFILE\Documents\Rob's Computer Manual\index.html")) {
    Copy-Item "$env:USERPROFILE\rk-comp-wksp\rk-comp-man\*" "$env:USERPROFILE\Documents\Rob's Computer Manual\" -Recurse -Force
}
```

### Git Repository Issues

#### Problem: Git Pull Failures
**Symptoms**: Content not updating, git errors in logs, email alerts

**Diagnostic Steps**:
```powershell
# Check repository status
Set-Location "$env:USERPROFILE\rk-comp-wksp"
git status
git remote -v

# Check git configuration
git config --list

# Test connectivity to GitHub
git fetch --dry-run
```

**Resolution - Authentication Issues**:
```powershell
# Reconfigure Git credentials
git config --global user.name "Rob Kanzer"
git config --global user.email "robkanzer@robkanzer.com"

# If using personal access token, update credentials
git config --global credential.helper store
```

**Resolution - Repository Conflicts**:
```powershell
# Use automated conflict resolution
.\Update-Manual.ps1

# Manual conflict resolution if needed
git fetch origin
git reset --hard origin/main
```

**Resolution - Corrupt Repository**:
```powershell
# Backup current content
.\Recovery.psm1; Backup-RKContent

# Re-clone repository
Set-Location "$env:USERPROFILE"
Remove-Item "rk-comp-wksp" -Recurse -Force
git clone https://github.com/kentonium3/rk-comp-wksp.git
Set-Location "rk-comp-wksp\code"

# Re-deploy system
.\Deploy-RKSystem.ps1 -SkipCredentials
```

### Email Notification Issues

#### Problem: No Email Alerts Received
**Symptoms**: System appears to be failing but no notifications arrive

**Diagnostic Steps**:
```powershell
# Test email configuration
.\Setup-RKCredentials.ps1 -TestOnly

# Check Gmail App Password validity
# (App passwords can expire or be revoked)

# Review notification module
Import-Module .\modules\Notifications.psm1 -Force
Send-RKEmail -Subject "Test Notification" -Body "Manual test from maintenance"
```

**Resolution**:
```powershell
# Regenerate Gmail App Password
# 1. Log into Rob's Gmail account
# 2. Go to Security > 2-Step Verification > App passwords
# 3. Delete old "Windows Computer" app password
# 4. Generate new app password
# 5. Run credential setup with new password

.\Setup-RKCredentials.ps1
```

### Component Update Issues

#### Problem: Python or Git Installation Failures
**Symptoms**: Component update errors, missing dependencies

**Diagnostic Steps**:
```powershell
# Check component availability
winget list | findstr Python
winget list | findstr Git

# Test component functionality
python --version
git --version

# Review component update logs
Get-Content "$env:USERPROFILE\Documents\Rob's Computer Manual\logs\components_$(Get-Date -Format 'yyyyMMdd').log"
```

**Resolution**:
```powershell
# Manual component installation
winget install Python.Python.3.11
winget install Git.Git

# Verify installations
python --version
git --version

# Update system paths if needed
$env:PATH += ";C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python311"
$env:PATH += ";C:\Program Files\Git\bin"
```

### Scheduled Task Issues

#### Problem: Tasks Not Executing
**Symptoms**: Manual updates not happening daily, web server not starting on login

**Diagnostic Steps**:
```powershell
# Check task status
Get-ScheduledTask | Where-Object {$_.TaskName -like "*RK*"}

# Check task history
Get-WinEvent -LogName "Microsoft-Windows-TaskScheduler/Operational" | 
    Where-Object {$_.Message -like "*RK*"} | 
    Select-Object TimeCreated, Id, LevelDisplayName, Message | 
    Sort-Object TimeCreated -Descending

# Test manual task execution
Start-ScheduledTask -TaskName "RK-Update-Daily"
```

**Resolution**:
```powershell
# Re-create scheduled tasks
# First remove existing tasks
Get-ScheduledTask | Where-Object {$_.TaskName -like "*RK*"} | Unregister-ScheduledTask -Confirm:$false

# Re-run deployment to recreate tasks
.\Deploy-RKSystem.ps1 -TasksOnly
```

## Performance Optimization

### System Performance Monitoring

#### Resource Usage Check
```powershell
# Monitor system resource usage
Get-Process python | Select-Object ProcessName, CPU, WorkingSet
Get-Process | Where-Object {$_.ProcessName -like "*git*"} | Select-Object ProcessName, CPU, WorkingSet

# Check disk space usage
Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace
```

#### Web Server Performance
```powershell
# Test web server response time
Measure-Command { Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing }

# Monitor web server process
Get-Process python | Where-Object {$_.CommandLine -like "*http.server*"}
```

### Optimization Recommendations

#### Log Management
```powershell
# Adjust log rotation if disk space is limited
# Edit settings.json to reduce retention period
$config = Get-Content "$env:USERPROFILE\rk-comp-wksp\config\settings.json" | ConvertFrom-Json
$config.Logging.RetentionDays = 14  # Reduce from 30 to 14 days
$config | ConvertTo-Json -Depth 10 | Set-Content "$env:USERPROFILE\rk-comp-wksp\config\settings.json"
```

#### Update Frequency
```powershell
# Modify daily update schedule if needed
# Use Task Scheduler GUI or PowerShell to adjust triggers
$task = Get-ScheduledTask -TaskName "RK-Update-Daily"
$trigger = New-ScheduledTaskTrigger -Daily -At "3:00 AM"  # Change from 6:00 AM
Set-ScheduledTask -TaskName "RK-Update-Daily" -Trigger $trigger
```

## System Updates and Upgrades

### PowerShell Module Updates
```powershell
# Update system modules (when Kent updates GitHub)
Set-Location "$env:USERPROFILE\rk-comp-wksp"
git pull

# Re-import updated modules
Get-Module RK* | Remove-Module -Force
Import-Module "$env:USERPROFILE\rk-comp-wksp\code\modules\*.psm1" -Force
```

### Component Updates
```powershell
# Update Python
winget upgrade Python.Python.3.11

# Update Git
winget upgrade Git.Git

# Verify updates
python --version
git --version
```

### Configuration Updates
```powershell
# Update email addresses or other settings
$config = Get-Content "$env:USERPROFILE\rk-comp-wksp\config\settings.json" | ConvertFrom-Json
$config.Email.ToAddress = "new-kent-email@example.com"
$config | ConvertTo-Json -Depth 10 | Set-Content "$env:USERPROFILE\rk-comp-wksp\config\settings.json"

# Test updated configuration
.\Health-Check.ps1
```

## Security Maintenance

### Credential Management
```powershell
# Rotate Gmail App Password (recommended every 6 months)
# 1. Generate new app password in Gmail
# 2. Update system credentials
.\Setup-RKCredentials.ps1

# Verify credential security
Get-StoredCredential -Target "RK-Gmail-SMTP" | Select-Object UserName
```

### Access Review
- **Monthly**: Review AnyDesk access logs
- **Quarterly**: Verify Gmail app password is still active
- **Annually**: Review overall system security posture

## Disaster Recovery

### Complete System Recovery
```powershell
# Full system rebuild if catastrophic failure
# 1. Backup any user-created content
Backup-RKContent -BackupPath "$env:USERPROFILE\Desktop\RK-Emergency-Backup"

# 2. Clean installation
Remove-Item "$env:USERPROFILE\rk-comp-wksp" -Recurse -Force
Remove-Item "$env:USERPROFILE\Documents\Rob's Computer Manual" -Recurse -Force

# 3. Fresh deployment
git clone https://github.com/kentonium3/rk-comp-wksp.git "$env:USERPROFILE\rk-comp-wksp"
Set-Location "$env:USERPROFILE\rk-comp-wksp\code"
.\Deploy-RKSystem.ps1

# 4. Restore user content if needed
Restore-RKContent -BackupPath "$env:USERPROFILE\Desktop\RK-Emergency-Backup"
```

### Backup Strategy
```powershell
# Create system backup (recommend monthly)
$backupPath = "$env:USERPROFILE\Desktop\RK-System-Backup-$(Get-Date -Format 'yyyy-MM-dd')"
New-Item -Path $backupPath -ItemType Directory

# Backup configuration
Copy-Item "$env:USERPROFILE\rk-comp-wksp\config\*" "$backupPath\config\" -Recurse
Copy-Item "$env:USERPROFILE\rk-comp-wksp\code\*" "$backupPath\code\" -Recurse

# Backup current content
Copy-Item "$env:USERPROFILE\Documents\Rob's Computer Manual\*" "$backupPath\content\" -Recurse

# Export scheduled tasks
Export-ScheduledTask -TaskName "RK-Update-Daily" | Out-File "$backupPath\tasks.xml"
```

## Maintenance Schedule

### Daily (Automated)
- System health checks
- Content updates
- Log rotation
- Email notifications

### Weekly (Kent - 10 minutes)
- Review email alerts
- Check system health summary
- Verify scheduled tasks running

### Monthly (Kent - 30 minutes)
- Review performance metrics
- Check component versions
- Analyze log patterns
- Test email notifications

### Quarterly (Kent - 1 hour)
- Full system health assessment
- Security review
- Performance optimization
- Backup verification

### Annually (Kent - 2 hours)
- Complete system review
- Security audit
- Performance baseline update
- Documentation review

## Escalation Procedures

### Level 1: Automated Recovery
- System attempts self-healing
- Email notification sent to Kent
- User sees friendly error message

### Level 2: Remote Troubleshooting (Kent)
- AnyDesk remote access
- Diagnostic procedures from this guide
- Manual intervention if needed

### Level 3: On-site Support
- If remote access unavailable
- Physical access to Rob's machine
- Complete system rebuild if necessary

## Contact Information

**Primary Support**: Kent Gale  
**Email**: kent@kentgale.com  
**Remote Access**: AnyDesk  
**Backup Contact**: [To be determined]  

**System Status**: Production Ready  
**Last Updated**: September 26, 2025  
**Next Review**: October 26, 2025

---

**Maintenance Confidence**: High - Comprehensive monitoring with proven recovery procedures  
**Support Model**: Proactive automation with reactive troubleshooting  
**Success Metric**: <1 hour monthly maintenance overhead for Kent