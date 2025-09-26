# rk-comp-wksp Deployment Guide

**Target Environment**: Rob's Windows Machine  
**Prerequisites**: Administrator access during initial setup  
**Estimated Time**: 30-45 minutes  
**Remote Access**: AnyDesk session with Kent  

## Pre-Deployment Checklist

### Information Required
- [ ] Rob's Gmail address: `robkanzer@robkanzer.com`
- [ ] Kent's notification email: `kent@kentgale.com` 
- [ ] Rob's Windows username (for path tokenization)
- [ ] AnyDesk connection details for remote setup session

### System Requirements
- [ ] Windows 10/11 with PowerShell 5.1+
- [ ] Internet connectivity for component downloads
- [ ] Modern web browser (Chrome, Firefox, Edge)
- [ ] ~500MB free disk space
- [ ] Administrator privileges for initial setup

## Deployment Process

### Phase 1: Pre-Deployment Setup (Kent)

#### 1.1 Repository Preparation
```bash
# Verify latest code is committed
cd ~/Vaults-repos/rk-comp-wksp
git status
git log -1 --oneline

# Ensure all documentation is current
ls -la docs/
```

#### 1.2 Configuration Review
```bash
# Verify settings.json has correct email addresses
cat config/settings.json | grep -A5 "Email"
```

#### 1.3 AnyDesk Session Setup
- [ ] Coordinate remote access session with Rob
- [ ] Verify AnyDesk connectivity
- [ ] Confirm administrator access availability

### Phase 2: Windows Machine Setup (Remote Session)

#### 2.1 Initial Directory Setup
```powershell
# Create base directory structure
New-Item -Path "$env:USERPROFILE\rk-comp-wksp" -ItemType Directory -Force
Set-Location "$env:USERPROFILE\rk-comp-wksp"
```

#### 2.2 Repository Clone
```powershell
# Clone repository (if Git available) or download ZIP
git clone https://github.com/kentonium3/rk-comp-wksp.git .

# Alternative: Download and extract ZIP if Git not available
# Manual download from GitHub and extract to folder
```

#### 2.3 PowerShell Execution Policy
```powershell
# Check current execution policy
Get-ExecutionPolicy

# Set execution policy for current user (if restricted)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify change
Get-ExecutionPolicy -List
```

### Phase 3: Automated Deployment

#### 3.1 Run Main Deployment Script
```powershell
# Navigate to code directory
Set-Location "$env:USERPROFILE\rk-comp-wksp\code"

# Execute main deployment script
.\Deploy-RKSystem.ps1
```

#### 3.2 Deployment Script Process
The deployment script will automatically:
1. **Module Installation**: Copy PowerShell modules to system location
2. **Directory Creation**: Set up all required directories
3. **Component Installation**: Install Python and Git via winget
4. **Path Configuration**: Resolve all tokenized paths for current user
5. **Credential Setup**: Prompt for Gmail App Password
6. **Task Scheduling**: Create Windows scheduled tasks
7. **Desktop Shortcuts**: Create user-friendly shortcuts
8. **Initial Health Check**: Verify complete system functionality

#### 3.3 Monitor Deployment Progress
Watch for:
- ✅ Module installation confirmations
- ✅ Component installation progress
- ✅ Credential configuration prompts
- ✅ Task creation notifications
- ✅ Health check results

### Phase 4: Gmail App Password Configuration

#### 4.1 Generate Gmail App Password (Rob's Account)
1. **Access Gmail Security Settings**:
   - Navigate to `myaccount.google.com`
   - Go to Security → 2-Step Verification
   - Select "App passwords"

2. **Create App Password**:
   - Select "Mail" as app type
   - Select "Windows Computer" as device
   - Generate 16-character password
   - **Record password securely**

#### 4.2 Configure Credentials in System
```powershell
# Run credential setup script
.\Setup-RKCredentials.ps1

# Enter Rob's Gmail address: robkanzer@robkanzer.com
# Enter generated 16-character app password
# Verify with test email
```

### Phase 5: System Validation

#### 5.1 Comprehensive Health Check
```powershell
# Run complete system diagnostics
.\Health-Check.ps1

# Expected results:
# ✅ All PowerShell modules loaded
# ✅ Python installation verified
# ✅ Git configuration valid
# ✅ Repository cloned successfully
# ✅ Email notifications working
# ✅ Web server ready to start
# ✅ Scheduled tasks created
```

#### 5.2 Manual Function Testing

**Test Web Server Startup**:
```powershell
.\Start-WebServer.ps1
# Verify web server starts on localhost:8080
# Open browser to http://localhost:8080
```

**Test Manual Update**:
```powershell
.\Update-Manual.ps1
# Verify git pull operation
# Verify content deployment
# Check for notification email
```

**Test Desktop Shortcuts**:
- [ ] Double-click "Computer Manual" shortcut → Opens browser to manual
- [ ] Double-click "Refresh Manual" shortcut → Updates content and shows progress

### Phase 6: Scheduled Task Configuration

#### 6.1 Verify Task Creation
```powershell
# Check that all scheduled tasks were created
Get-ScheduledTask | Where-Object {$_.TaskName -like "*RK*"}

# Expected tasks:
# - RK-WebServer-Login (trigger: user login)
# - RK-Update-Daily (trigger: daily 6:00 AM)
# - RK-WebServer-Wake (trigger: system wake)
```

#### 6.2 Test Task Execution
```powershell
# Manually run update task
Start-ScheduledTask -TaskName "RK-Update-Daily"

# Verify task execution in logs
Get-Content "$env:USERPROFILE\Documents\Rob's Computer Manual\logs\*.log" | Select-Object -Last 10
```

### Phase 7: User Training

#### 7.1 Show Rob Basic Operations

**Daily Usage**:
- Desktop shortcut "Computer Manual" opens the reference
- System runs automatically in background
- No technical intervention required

**Manual Updates** (if needed):
- Desktop shortcut "Refresh Manual" updates content immediately
- Progress shown in popup notification
- Email sent to Kent if problems occur

**Troubleshooting Contact**:
- Kent receives automatic email alerts for any system issues
- AnyDesk available for remote troubleshooting
- System logs all operations for diagnostics

#### 7.2 Initial Content Review
- [ ] Open manual in browser
- [ ] Navigate through sections
- [ ] Verify all assets load correctly
- [ ] Test search functionality (if implemented)

## Post-Deployment Verification

### Immediate Checks (Day 1)
- [ ] Web server automatically starts on login
- [ ] Manual content accessible via browser
- [ ] Desktop shortcuts function correctly
- [ ] System logs created in correct location

### Ongoing Monitoring (Week 1)
- [ ] Daily updates execute successfully
- [ ] Email notifications reach Kent
- [ ] No error patterns in logs
- [ ] System remains responsive

### Health Verification Commands
```powershell
# Quick system check
.\Health-Check.ps1

# View recent logs
Get-ChildItem "$env:USERPROFILE\Documents\Rob's Computer Manual\logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Check scheduled task status
Get-ScheduledTask | Where-Object {$_.TaskName -like "*RK*"} | Select-Object TaskName, State, LastRunTime
```

## Rollback Procedure

### If Deployment Fails

#### 1. Remove Scheduled Tasks
```powershell
Get-ScheduledTask | Where-Object {$_.TaskName -like "*RK*"} | Unregister-ScheduledTask -Confirm:$false
```

#### 2. Clean Up Directories
```powershell
Remove-Item -Path "$env:USERPROFILE\rk-comp-wksp" -Recurse -Force
Remove-Item -Path "$env:USERPROFILE\Documents\Rob's Computer Manual" -Recurse -Force
```

#### 3. Reset Execution Policy (if changed)
```powershell
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser
```

#### 4. Remove Desktop Shortcuts
```powershell
Remove-Item -Path "$env:USERPROFILE\Desktop\Computer Manual.lnk" -Force
Remove-Item -Path "$env:USERPROFILE\Desktop\Refresh Manual.lnk" -Force
```

## Troubleshooting Common Issues

### PowerShell Execution Policy
**Problem**: Scripts won't execute  
**Solution**: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Component Installation Failures
**Problem**: Python or Git installation fails  
**Solution**: Manual installation from official websites, then re-run `.\Update-Components.ps1`

### Port 8080 Conflicts
**Problem**: Web server can't start due to port conflict  
**Solution**: System automatically tries alternative ports 8081-8090

### Gmail Authentication Issues
**Problem**: Email notifications fail  
**Solution**: Re-run `.\Setup-RKCredentials.ps1` with new App Password

### Git Credential Issues
**Problem**: Repository updates fail due to authentication  
**Solution**: Configure Git credentials manually:
```powershell
git config --global user.name "Rob Kanzer"
git config --global user.email "robkanzer@robkanzer.com"
```

## Success Criteria

### Deployment Complete When:
- [x] All PowerShell modules load without errors
- [x] Python and Git installed and functional  
- [x] Gmail notifications working (test email sent)
- [x] Web server starts and serves content on localhost:8080
- [x] Desktop shortcuts created and functional
- [x] Scheduled tasks created and tested
- [x] Manual content accessible and current
- [x] System logs created and rotating properly
- [x] Rob can access manual without technical intervention

### Long-term Success Metrics:
- Daily updates execute without issues
- Email notifications reach Kent for any problems
- System operates invisibly to Rob
- Manual content stays current automatically
- Minimal maintenance overhead for Kent

---

**Deployment Confidence**: High - Comprehensive automation with robust error handling  
**Support Contact**: Kent Gale via email or AnyDesk  
**Next Steps**: Regular monitoring and content updates via Obsidian workflow