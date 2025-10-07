# ============================================================================
# SystemChecks.psm1 - Component validation and health checks
# ============================================================================

function Test-RKSystemHealth {
    [CmdletBinding()]
    param([switch]$Detailed)
    
    Write-RKLog "Starting system health check" -Component 'HEALTH'
    
    $results = @{
        Overall = $true
        Python = Test-PythonInstallation
        Git = Test-GitInstallation
        Repository = Test-RepositoryHealth
        WebServer = Test-WebServerStatus
        Directories = Test-DirectoryStructure
        Credentials = Test-CredentialsConfigured
        Network = Test-NetworkConnectivity
    }
    
    # Overall health is true only if all components are healthy
    $results.Overall = -not ($results.Values | Where-Object { $_ -eq $false })
    
    if ($Detailed) {
        $results.Details = Get-SystemDetails
    }
    
    $status = if ($results.Overall) { "HEALTHY" } else { "NEEDS ATTENTION" }
    Write-RKLog "System health check completed: $status" -Level $(if ($results.Overall) { 'SUCCESS' } else { 'WARN' }) -Component 'HEALTH'
    
    return $results
}

function Find-PythonExecutable {
    [CmdletBinding()]
    param()
    
    # Try to find python command first
    try {
        $pythonCmd = Get-Command python -ErrorAction Stop
        return $pythonCmd.Source
    }
    catch {
        # Python not in PATH, search common locations
        $searchPaths = @(
            "$env:LOCALAPPDATA\Programs\Python\Python*\python.exe",
            "C:\Python*\python.exe",
            "C:\Program Files\Python*\python.exe",
            "C:\Program Files (x86)\Python*\python.exe"
        )
        
        foreach ($pattern in $searchPaths) {
            $found = Get-ChildItem $pattern -ErrorAction SilentlyContinue | 
                     Sort-Object LastWriteTime -Descending | 
                     Select-Object -First 1
            
            if ($found) {
                Write-RKLog "Found Python at: $($found.FullName)" -Level 'SUCCESS' -Component 'HEALTH'
                return $found.FullName
            }
        }
        
        Write-RKLog "Python executable not found in common locations" -Level 'ERROR' -Component 'HEALTH'
        return $null
    }
}

function Test-PythonInstallation {
    [CmdletBinding()]
    param()
    
    try {
        $pythonPath = Find-PythonExecutable
        if (-not $pythonPath) {
            Write-RKLog "Python not found" -Level 'ERROR' -Component 'HEALTH'
            return $false
        }
        
        $pythonVersion = & $pythonPath --version 2>&1
        if ($pythonVersion -match "Python \d+\.\d+") {
            Write-RKLog "Python check passed: $pythonVersion" -Level 'SUCCESS' -Component 'HEALTH'
            
            # Store Python path for later use
            $global:RKPythonPath = $pythonPath
            return $true
        }
        else {
            Write-RKLog "Python not found or invalid version: $pythonVersion" -Level 'ERROR' -Component 'HEALTH'
            return $false
        }
    }
    catch {
        Write-RKLog "Python check failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'HEALTH'
        return $false
    }
}

function Test-GitInstallation {
    [CmdletBinding()]
    param()
    
    try {
        $gitVersion = git --version 2>&1
        if ($gitVersion -match "git version") {
            Write-RKLog "Git check passed: $gitVersion" -Level 'SUCCESS' -Component 'HEALTH'
            return $true
        }
        else {
            Write-RKLog "Git not found or invalid version: $gitVersion" -Level 'ERROR' -Component 'HEALTH'
            return $false
        }
    }
    catch {
        Write-RKLog "Git check failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'HEALTH'
        return $false
    }
}

function Test-RepositoryHealth {
    [CmdletBinding()]
    param()
    
    $config = Get-RKConfig
    $repoPath = $config.repository.localPath
    
    if (!(Test-Path $repoPath)) {
        Write-RKLog "Repository directory missing: $repoPath" -Level 'ERROR' -Component 'HEALTH'
        return $false
    }
    
    $gitDir = Join-Path $repoPath '.git'
    if (!(Test-Path $gitDir)) {
        Write-RKLog "Git repository not initialized: $gitDir" -Level 'ERROR' -Component 'HEALTH'
        return $false
    }
    
    try {
        Push-Location $repoPath
        
        # Check if we can run git status
        $status = git status --porcelain 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-RKLog "Repository status check failed: $status" -Level 'ERROR' -Component 'HEALTH'
            return $false
        }
        
        # Check if remote is configured
        $remote = git remote get-url origin 2>&1
        if ($LASTEXITCODE -ne 0 -or !$remote) {
            Write-RKLog "Repository remote not configured" -Level 'ERROR' -Component 'HEALTH'
            return $false
        }
        
        Write-RKLog "Repository health check passed. Remote: $remote" -Level 'SUCCESS' -Component 'HEALTH'
        return $true
    }
    catch {
        Write-RKLog "Repository health check failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'HEALTH'
        return $false
    }
    finally {
        Pop-Location
    }
}

function Test-WebServerStatus {
    [CmdletBinding()]
    param()
    
    $config = Get-RKConfig
    $port = $config.webServer.port
    
    try {
        # Test if port is open and responding
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.ReceiveTimeout = 3000
        $tcpClient.SendTimeout = 3000
        $tcpClient.Connect("127.0.0.1", $port)
        $tcpClient.Close()
        
        # Try to get a response
        $response = Invoke-WebRequest -Uri "http://localhost:$port" -TimeoutSec 5 -ErrorAction Stop
        Write-RKLog "Web server check passed on port $port" -Level 'SUCCESS' -Component 'HEALTH'
        return $true
    }
    catch {
        Write-RKLog "Web server not responding on port $port : $($_.Exception.Message)" -Level 'WARN' -Component 'HEALTH'
        return $false
    }
}

function Test-DirectoryStructure {
    [CmdletBinding()]
    param()
    
    $config = Get-RKConfig
    $requiredPaths = @(
        $config.repository.localPath,
        $config.repository.deployPath,
        $config.logging.path,
        (Join-Path $config.repository.localPath "code"),
        (Join-Path $config.repository.localPath "rk-comp-man")
    )
    
    $allExist = $true
    $missingPaths = @()
    
    foreach ($path in $requiredPaths) {
        if (!(Test-Path $path)) {
            Write-RKLog "Required directory missing: $path" -Level 'ERROR' -Component 'HEALTH'
            $missingPaths += $path
            $allExist = $false
        }
    }
    
    if ($allExist) {
        Write-RKLog "Directory structure check passed" -Level 'SUCCESS' -Component 'HEALTH'
    } else {
        Write-RKLog "Missing directories: $($missingPaths -join ', ')" -Level 'ERROR' -Component 'HEALTH'
    }
    
    return $allExist
}

function Test-CredentialsConfigured {
    [CmdletBinding()]
    param()
    
    try {
        $credential = Get-RKStoredCredential -Target "RKComputerManual-Gmail"
        if ($credential) {
            Write-RKLog "Gmail credentials configured" -Level 'SUCCESS' -Component 'HEALTH'
            return $true
        } else {
            Write-RKLog "Gmail credentials not configured" -Level 'WARN' -Component 'HEALTH'
            return $false
        }
    }
    catch {
        Write-RKLog "Credential check failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'HEALTH'
        return $false
    }
}

function Test-NetworkConnectivity {
    [CmdletBinding()]
    param()
    
    try {
        # Test basic internet connectivity
        $googleTest = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet -ErrorAction Stop
        if (-not $googleTest) {
            Write-RKLog "No internet connectivity detected" -Level 'ERROR' -Component 'HEALTH'
            return $false
        }
        
        # Test GitHub connectivity
        $githubTest = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet -ErrorAction Stop
        if (-not $githubTest) {
            Write-RKLog "Cannot reach GitHub" -Level 'ERROR' -Component 'HEALTH'
            return $false
        }
        
        # Test Gmail SMTP connectivity
        $config = Get-RKConfig
        $smtpTest = Test-NetConnection -ComputerName $config.support.smtpServer -Port $config.support.smtpPort -InformationLevel Quiet -ErrorAction Stop
        if (-not $smtpTest) {
            Write-RKLog "Cannot reach Gmail SMTP server" -Level 'WARN' -Component 'HEALTH'
            return $false
        }
        
        Write-RKLog "Network connectivity check passed" -Level 'SUCCESS' -Component 'HEALTH'
        return $true
    }
    catch {
        Write-RKLog "Network connectivity check failed: $($_.Exception.Message)" -Level 'ERROR' -Component 'HEALTH'
        return $false
    }
}

function Get-SystemDetails {
    [CmdletBinding()]
    param()
    
    try {
        $config = Get-RKConfig
        
        return @{
            ComputerName = $config.system.computerName
            UserName = $config.system.userName
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            OSVersion = [System.Environment]::OSVersion.VersionString
            DotNetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
            TimeZone = (Get-TimeZone).DisplayName
            LastBootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
            Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
            WorkingDirectory = (Get-Location).Path
            ExecutionPolicy = (Get-ExecutionPolicy).ToString()
            LogSummary = Get-RKLogSummary -Days 1
        }
    }
    catch {
        Write-RKLog "Failed to gather system details: $($_.Exception.Message)" -Level 'WARN' -Component 'HEALTH'
        return @{ Error = $_.Exception.Message }
    }
}

function Test-RequiredComponents {
    [CmdletBinding()]
    param(
        [string[]]$Components = @('Python', 'Git', 'Repository', 'Directories')
    )
    
    $results = @{}
    
    foreach ($component in $Components) {
        switch ($component) {
            'Python' { $results[$component] = Test-PythonInstallation }
            'Git' { $results[$component] = Test-GitInstallation }
            'Repository' { $results[$component] = Test-RepositoryHealth }
            'WebServer' { $results[$component] = Test-WebServerStatus }
            'Directories' { $results[$component] = Test-DirectoryStructure }
            'Credentials' { $results[$component] = Test-CredentialsConfigured }
            'Network' { $results[$component] = Test-NetworkConnectivity }
            default { 
                Write-RKLog "Unknown component requested: $component" -Level 'WARN' -Component 'HEALTH'
                $results[$component] = $false 
            }
        }
    }
    
    return $results
}

function Get-WebServerProcess {
    [CmdletBinding()]
    param()
    
    $config = Get-RKConfig
    $port = $config.webServer.port
    
    try {
        # Find process using the web server port
        $connections = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        if ($connections) {
            foreach ($conn in $connections) {
                $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                if ($process) {
                    return @{
                        ProcessId = $process.Id
                        ProcessName = $process.ProcessName
                        StartTime = $process.StartTime
                        Port = $port
                        State = $conn.State
                    }
                }
            }
        }
        return $null
    }
    catch {
        Write-RKLog "Failed to get web server process info: $($_.Exception.Message)" -Level 'WARN' -Component 'HEALTH'
        return $null
    }
}

# Export functions
Export-ModuleMember -Function Test-RKSystemHealth, Find-PythonExecutable, Test-PythonInstallation, Test-GitInstallation, Test-RepositoryHealth, Test-WebServerStatus, Test-DirectoryStructure, Test-CredentialsConfigured, Test-NetworkConnectivity, Get-SystemDetails, Test-RequiredComponents, Get-WebServerProcess