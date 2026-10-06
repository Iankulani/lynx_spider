# ============================================
# LYNX-SPIDER-V1 - PowerShell Installer
# Author: Ian Carter Kulani
# ============================================

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$InstallDir = "$env:ProgramFiles\LynxSpider",
    [string]$PythonVersion = "3.11",
    [switch]$SkipDependencies,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ============ HELPER FUNCTIONS ============
function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        🕷️  LYNX-SPIDER-V1 - PowerShell Installation                         ║" -ForegroundColor Cyan
    Write-Host "║        Author: Ian Carter Kulani                                             ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "Blue" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# ============ SYSTEM CHECKS ============
function Test-SystemRequirements {
    Write-Log "Checking system requirements..." "INFO"
    
    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-Log "Windows 10 or later required. Found: $osVersion" "ERROR"
        exit 1
    }
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log "PowerShell 5.0 or later required" "ERROR"
        exit 1
    }
    
    # Check architecture
    $arch = $env:PROCESSOR_ARCHITECTURE
    Write-Log "Architecture: $arch" "INFO"
    
    # Check admin
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Log "Administrator privileges required" "ERROR"
        exit 1
    }
    
    Write-Log "System requirements met" "SUCCESS"
}

# ============ PYTHON INSTALLATION ============
function Install-Python {
    Write-Log "Checking Python installation..." "INFO"
    
    $pythonCmd = $null
    
    # Check for python
    if (Test-Command "python") {
        $pythonCmd = "python"
    } elseif (Test-Command "python3") {
        $pythonCmd = "python3"
    }
    
    if ($pythonCmd) {
        $version = & $pythonCmd --version 2>&1
        Write-Log "Found: $version" "SUCCESS"
        return $pythonCmd
    }
    
    # Install Python
    Write-Log "Python not found. Installing Python $PythonVersion..." "WARNING"
    
    $pythonUrl = "https://www.python.org/ftp/python/$PythonVersion.7/python-$PythonVersion.7-amd64.exe"
    $installer = "$env:TEMP\python-installer.exe"
    
    Write-Log "Downloading Python from $pythonUrl..." "INFO"
    Invoke-WebRequest -Uri $pythonUrl -OutFile $installer -UseBasicParsing
    
    if (-not (Test-Path $installer)) {
        Write-Log "Failed to download Python" "ERROR"
        exit 1
    }
    
    Write-Log "Installing Python..." "INFO"
    $process = Start-Process -FilePath $installer -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_test=0" -Wait -PassThru
    
    Remove-Item $installer -Force -ErrorAction SilentlyContinue
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    if (Test-Command "python") {
        Write-Log "Python installed successfully" "SUCCESS"
        return "python"
    } else {
        Write-Log "Python installation failed" "ERROR"
        exit 1
    }
}

# ============ CREATE DIRECTORIES ============
function New-InstallDirectories {
    Write-Log "Creating installation directories..." "INFO"
    
    $dirs = @(
        $InstallDir,
        "$InstallDir\.lynx_spider",
        "$InstallDir\.lynx_spider\payloads",
        "$InstallDir\.lynx_spider\workspaces",
        "$InstallDir\.lynx_spider\scans",
        "$InstallDir\.lynx_spider\reports",
        "$InstallDir\.lynx_spider\phishing_pages",
        "$InstallDir\.lynx_spider\captured_credentials",
        "$InstallDir\.lynx_spider\ssh_keys",
        "$InstallDir\.lynx_spider\traffic_logs",
        "$InstallDir\.lynx_spider\keylog_exfil",
        "$InstallDir\.lynx_spider\deployments",
        "$InstallDir\lynx_spider_reports",
        "$InstallDir\logs"
    )
    
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    Write-Log "Directories created" "SUCCESS"
}

# ============ COPY FILES ============
function Copy-ApplicationFiles {
    param([string]$SourceDir)
    
    Write-Log "Copying application files..." "INFO"
    
    # Copy main application
    $mainApp = Join-Path $SourceDir "lynx_spider.py"
    if (Test-Path $mainApp) {
        Copy-Item $mainApp -Destination $InstallDir -Force
    } else {
        Write-Log "lynx_spider.py not found in $SourceDir" "ERROR"
        exit 1
    }
    
    # Copy requirements
    $requirements = Join-Path $SourceDir "requirements.txt"
    if (Test-Path $requirements) {
        Copy-Item $requirements -Destination $InstallDir -Force
    }
    
    # Copy config directory
    $configDir = Join-Path $SourceDir "config"
    if (Test-Path $configDir) {
        Copy-Item $configDir -Destination $InstallDir -Recurse -Force
    }
    
    Write-Log "Application files copied" "SUCCESS"
}

# ============ CREATE VIRTUAL ENVIRONMENT ============
function New-VirtualEnvironment {
    param([string]$PythonCmd)
    
    Write-Log "Creating virtual environment..." "INFO"
    
    $venvDir = Join-Path $InstallDir "venv"
    
    if (Test-Path $venvDir) {
        if ($Force) {
            Remove-Item $venvDir -Recurse -Force
        } else {
            Write-Log "Virtual environment already exists. Use -Force to recreate." "WARNING"
            return $venvDir
        }
    }
    
    & $PythonCmd -m venv $venvDir
    
    if (-not (Test-Path "$venvDir\Scripts\python.exe")) {
        Write-Log "Failed to create virtual environment" "ERROR"
        exit 1
    }
    
    Write-Log "Virtual environment created: $venvDir" "SUCCESS"
    return $venvDir
}

# ============ INSTALL DEPENDENCIES ============
function Install-PythonDependencies {
    param([string]$VenvDir)
    
    if ($SkipDependencies) {
        Write-Log "Skipping dependency installation" "WARNING"
        return
    }
    
    Write-Log "Installing Python dependencies..." "INFO"
    
    $pip = Join-Path $VenvDir "Scripts\pip.exe"
    $python = Join-Path $VenvDir "Scripts\python.exe"
    
    # Upgrade pip
    & $python -m pip install --upgrade pip setuptools wheel --quiet
    
    # Install requirements
    $requirements = Join-Path $InstallDir "requirements.txt"
    if (Test-Path $requirements) {
        & $pip install -r $requirements --quiet
    } else {
        # Core dependencies
        $coreDeps = @(
            "requests", "scapy", "dnspython", "paramiko", 
            "psutil", "colorama", "flask", "flask-socketio",
            "pynput", "cryptography", "beautifulsoup4"
        )
        & $pip install $coreDeps --quiet
    }
    
    Write-Log "Python dependencies installed" "SUCCESS"
}

# ============ CREATE CONFIGURATION ============
function New-Configuration {
    Write-Log "Creating configuration..." "INFO"
    
    $configFile = Join-Path $InstallDir ".lynx_spider\config.json"
    
    if (-not (Test-Path $configFile)) {
        $config = @{
            version = "1.0.0"
            auto_start = $false
            auto_block_enabled = $false
            scan_timeout = 30
            report_format = "html"
            generate_graphics = $true
            web = @{
                enabled = $true
                port = 5000
                host = "0.0.0.0"
                require_auth = $true
            }
            monitoring = @{
                enabled = $true
            }
            keylogger = @{
                enabled = $false
                hotkey = "f10"
            }
        } | ConvertTo-Json -Depth 10
        
        Set-Content -Path $configFile -Value $config -Encoding UTF8
        Write-Log "Configuration created" "SUCCESS"
    } else {
        Write-Log "Configuration already exists" "INFO"
    }
}

# ============ CREATE LAUNCHER ============
function New-Launcher {
    Write-Log "Creating launcher scripts..." "INFO"
    
    $venvDir = Join-Path $InstallDir "venv"
    
    # Batch launcher
    $batchContent = @"
@echo off
call "$venvDir\Scripts\activate.bat"
cd /d "$InstallDir"
python lynx_spider.py %*
"@
    
    Set-Content -Path "$InstallDir\lynx-spider.bat" -Value $batchContent -Encoding ASCII
    
    # PowerShell launcher
    $psContent = @"
# LYNX-SPIDER-V1 Launcher
`$venvPath = "$venvDir\Scripts\Activate.ps1"
`$appPath = "$InstallDir"

if (Test-Path `$venvPath) {
    & `$venvPath
}

Set-Location `$appPath
python lynx_spider.py @args
"@
    
    Set-Content -Path "$InstallDir\lynx-spider.ps1" -Value $psContent -Encoding UTF8
    
    # Add to PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$InstallDir", "Machine")
        Write-Log "Added $InstallDir to system PATH" "SUCCESS"
    }
    
    Write-Log "Launcher scripts created" "SUCCESS"
}

# ============ CREATE SHORTCUTS ============
function New-Shortcuts {
    Write-Log "Creating shortcuts..." "INFO"
    
    $WScriptShell = New-Object -ComObject WScript.Shell
    $launcherPath = Join-Path $InstallDir "lynx-spider.bat"
    
    # Desktop shortcut
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $desktopShortcut = $WScriptShell.CreateShortcut("$desktopPath\Lynx Spider.lnk")
    $desktopShortcut.TargetPath = $launcherPath
    $desktopShortcut.WorkingDirectory = $InstallDir
    $desktopShortcut.Description = "LYNX-SPIDER-V1 Cybersecurity Platform"
    $desktopShortcut.IconLocation = "shell32.dll,77"
    $desktopShortcut.Save()
    
    # Start Menu shortcut
    $startMenuPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    $startMenuShortcut = $WScriptShell.CreateShortcut("$startMenuPath\Lynx Spider.lnk")
    $startMenuShortcut.TargetPath = $launcherPath
    $startMenuShortcut.WorkingDirectory = $InstallDir
    $startMenuShortcut.Description = "LYNX-SPIDER-V1 Cybersecurity Platform"
    $startMenuShortcut.IconLocation = "shell32.dll,77"
    $startMenuShortcut.Save()
    
    Write-Log "Shortcuts created" "SUCCESS"
}

# ============ CREATE WINDOWS SERVICE ============
function New-WindowsService {
    Write-Log "Creating Windows service..." "INFO"
    
    $venvDir = Join-Path $InstallDir "venv"
    $python = Join-Path $venvDir "Scripts\python.exe"
    $app = Join-Path $InstallDir "lynx_spider.py"
    
    # Check if service exists
    $service = Get-Service -Name "LynxSpider" -ErrorAction SilentlyContinue
    
    if ($service) {
        Write-Log "Service already exists" "WARNING"
        return
    }
    
    # Create service using sc.exe
    $serviceCmd = "`"$python`" `"$app`""
    sc.exe create LynSpider binPath= $serviceCmd start= auto DisplayName= "LYNX-SPIDER-V1 Cybersecurity Platform"
    sc.exe description LynSpider "LYNX-SPIDER-V1 - Ultimate Cybersecurity Command & Control Platform"
    
    Write-Log "Windows service created" "SUCCESS"
}

# ============ PRINT SUMMARY ============
function Write-Summary {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host " ✅ LYNX-SPIDER-V1 Installation Complete!" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Installation Directory: " -NoNewline -ForegroundColor Cyan
    Write-Host $InstallDir
    
    Write-Host "Virtual Environment: " -NoNewline -ForegroundColor Cyan
    Write-Host "$InstallDir\venv"
    
    Write-Host "Configuration: " -NoNewline -ForegroundColor Cyan
    Write-Host "$InstallDir\.lynx_spider\config.json"
    
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  lynx-spider                    # Run the application"
    Write-Host "  Start-Service LynxSpider       # Start as service"
    Write-Host "  Get-Service LynxSpider         # Check service status"
    Write-Host ""
    
    Write-Host "Web Dashboard: " -NoNewline -ForegroundColor Cyan
    Write-Host "http://localhost:5000"
    
    Write-Host ""
    Write-Host "⚠️  For authorized security testing only!" -ForegroundColor Red
    Write-Host ""
}

# ============ MAIN ============
function Main {
    Write-Banner
    
    try {
        Test-SystemRequirements
        
        $pythonCmd = Install-Python
        
        New-InstallDirectories
        
        Copy-ApplicationFiles -SourceDir $PSScriptRoot
        
        $venvDir = New-VirtualEnvironment -PythonCmd $pythonCmd
        
        Install-PythonDependencies -VenvDir $venvDir
        
        New-Configuration
        
        New-Launcher
        
        New-Shortcuts
        
        New-WindowsService
        
        Write-Summary
        
        Write-Log "Installation completed successfully" "SUCCESS"
    }
    catch {
        Write-Log "Installation failed: $_" "ERROR"
        exit 1
    }
}

# Run
Main
