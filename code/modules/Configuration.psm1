# ============================================================================
# Configuration.psm1 - Centralized configuration management
# ============================================================================

function ConvertTo-Hashtable {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    
    process {
        if ($null -eq $InputObject) { return $null }
        
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @()
            foreach ($object in $InputObject) {
                $collection += ConvertTo-Hashtable $object
            }
            return ,$collection
        }
        elseif ($InputObject -is [PSCustomObject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable $property.Value
            }
            return $hash
        }
        else {
            return $InputObject
        }
    }
}

function Get-RKConfig {
    [CmdletBinding()]
    param()
    
    # Use current user for cross-machine compatibility
    $configPath = "$env:USERPROFILE\rk-comp-wksp\config\settings.json"
    
    # Default configuration with tokenized paths
    $defaultConfig = @{
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
            docRoot = "$env:USERPROFILE\Documents\Rob's Computer Manual"
        }
        repository = @{
            localPath = "$env:USERPROFILE\rk-comp-wksp"
            deployPath = "$env:USERPROFILE\Documents\Rob's Computer Manual"
            githubUrl = "https://github.com/kentonium3/rk-comp-wksp.git"
        }
        logging = @{
            path = "$env:USERPROFILE\Documents\Rob's Computer Manual\logs"
            retentionDays = 30
        }
        system = @{
            computerName = $env:COMPUTERNAME
            userName = $env:USERNAME
            userProfile = $env:USERPROFILE
        }
    }
    
    if (Test-Path $configPath) {
        try {
            # PowerShell 5.1 compatible JSON parsing
            $jsonObject = Get-Content $configPath -Raw | ConvertFrom-Json
            $config = ConvertTo-Hashtable $jsonObject
            
            # Ensure paths are expanded for current user/machine
            $config = Expand-ConfigPaths -Config $config
            return $config
        }
        catch {
            Write-Warning "Config file corrupted, using defaults: $($_.Exception.Message)"
            return $defaultConfig
        }
    }
    else {
        # Create default config file
        $configDir = Split-Path $configPath -Parent
        if (!(Test-Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
        return $defaultConfig
    }
}

function Expand-ConfigPaths {
    [CmdletBinding()]
    param(
        [hashtable]$Config
    )
    
    # Expand environment variables in path strings
    foreach ($section in $Config.Keys) {
        if ($Config[$section] -is [hashtable]) {
            foreach ($key in $Config[$section].Keys) {
                if ($Config[$section][$key] -is [string] -and $Config[$section][$key] -like "*`$env:*") {
                    $Config[$section][$key] = [Environment]::ExpandEnvironmentVariables($Config[$section][$key])
                }
            }
        }
    }
    
    # Update system info for current machine
    $Config.system = @{
        computerName = $env:COMPUTERNAME
        userName = $env:USERNAME
        userProfile = $env:USERPROFILE
    }
    
    return $Config
}

function Set-RKConfigValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Section,
        
        [Parameter(Mandatory)]
        [string]$Key,
        
        [Parameter(Mandatory)]
        $Value
    )
    
    $config = Get-RKConfig
    
    if (-not $config[$Section]) {
        $config[$Section] = @{}
    }
    
    $config[$Section][$Key] = $Value
    
    $configPath = "$env:USERPROFILE\rk-comp-wksp\config\settings.json"
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    
    Write-Verbose "Updated config: $Section.$Key = $Value"
}

# Export functions
Export-ModuleMember -Function Get-RKConfig, Set-RKConfigValue
