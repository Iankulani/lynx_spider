@echo off
REM ============================================
REM LYNX-SPIDER-V1 - Windows Installer
REM Author: Ian Carter Kulani
REM ============================================

setlocal EnableDelayedExpansion

REM Configuration
set "INSTALL_DIR=%ProgramFiles%\LynxSpider"
set "VENV_DIR=%INSTALL_DIR%\venv"
set "PYTHON_VERSION=3.11"
set "LOG_FILE=%TEMP%\lynx-spider-install.log"

REM Colors (using Windows 10+ ANSI support)
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "CYAN=[96m"
set "MAGENTA=[95m"
set "NC=[0m"

REM Check for admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%NC% This script must be run as Administrator
    pause
    exit /b 1
)

echo %CYAN%
echo ================================================================================
echo         LYNX-SPIDER-V1 - Windows Installation Script
echo         Author: Ian Carter Kulani
echo ================================================================================
echo %NC%

REM Check Python
echo %BLUE%[INFO]%NC% Checking Python installation...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% Python not found. Attempting to install...
    
    REM Try to download and install Python
    set "PYTHON_URL=https://www.python.org/ftp/python/3.11.7/python-3.11.7-amd64.exe"
    set "PYTHON_INSTALLER=%TEMP%\python-installer.exe"
    
    echo %BLUE%[INFO]%NC% Downloading Python...
    powershell -Command "Invoke-WebRequest -Uri '%PYTHON_URL%' -OutFile '%PYTHON_INSTALLER%'"
    
    if exist "%PYTHON_INSTALLER%" (
        echo %BLUE%[INFO]%NC% Installing Python...
        "%PYTHON_INSTALLER%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
        
        timeout /t 30 /nobreak >nul
        del "%PYTHON_INSTALLER%"
        
        REM Refresh PATH
        call :RefreshPath
    ) else (
        echo %RED%[ERROR]%NC% Failed to download Python
        echo Please install Python 3.7+ manually from https://python.org
        pause
        exit /b 1
    )
)

REM Verify Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%NC% Python installation failed
    pause
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version 2^>^&1') do set "PY_VERSION=%%i"
echo %GREEN%[OK]%NC% Python %PY_VERSION% found

REM Create installation directory
echo %BLUE%[INFO]%NC% Creating installation directory: %INSTALL_DIR%
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
if not exist "%INSTALL_DIR%\.lynx_spider" mkdir "%INSTALL_DIR%\.lynx_spider"
if not exist "%INSTALL_DIR%\lynx_spider_reports" mkdir "%INSTALL_DIR%\lynx_spider_reports"

REM Copy application files
echo %BLUE%[INFO]%NC% Copying application files...
set "SCRIPT_DIR=%~dp0"

if exist "%SCRIPT_DIR%lynx_spider.py" (
    copy /Y "%SCRIPT_DIR%lynx_spider.py" "%INSTALL_DIR%\" >nul
) else (
    echo %RED%[ERROR]%NC% lynx_spider.py not found in %SCRIPT_DIR%
    pause
    exit /b 1
)

if exist "%SCRIPT_DIR%requirements.txt" (
    copy /Y "%SCRIPT_DIR%requirements.txt" "%INSTALL_DIR%\" >nul
)

REM Create virtual environment
echo %BLUE%[INFO]%NC% Creating virtual environment...
python -m venv "%VENV_DIR%"

if not exist "%VENV_DIR%\Scripts\activate.bat" (
    echo %RED%[ERROR]%NC% Failed to create virtual environment
    pause
    exit /b 1
)

REM Activate and install dependencies
echo %BLUE%[INFO]%NC% Installing Python dependencies...
call "%VENV_DIR%\Scripts\activate.bat"

python -m pip install --upgrade pip setuptools wheel

if exist "%INSTALL_DIR%\requirements.txt" (
    pip install -r "%INSTALL_DIR%\requirements.txt"
) else (
    pip install requests scapy dnspython paramiko psutil colorama flask flask-socketio
)

REM Create configuration
echo %BLUE%[INFO]%NC% Creating configuration...
if not exist "%INSTALL_DIR%\.lynx_spider\config.json" (
    (
        echo {
        echo     "version": "1.0.0",
        echo     "auto_start": false,
        echo     "web": {
        echo         "enabled": true,
        echo         "port": 5000,
        echo         "host": "0.0.0.0"
        echo     }
        echo }
    ) > "%INSTALL_DIR%\.lynx_spider\config.json"
)

REM Create launcher batch file
echo %BLUE%[INFO]%NC% Creating launcher script...
(
    echo @echo off
    echo call "%VENV_DIR%\Scripts\activate.bat"
    echo cd /d "%INSTALL_DIR%"
    echo python lynx_spider.py %%*
) > "%INSTALL_DIR%\lynx-spider.bat"

REM Add to PATH
echo %BLUE%[INFO]%NC% Adding to system PATH...
setx /M PATH "%PATH%;%INSTALL_DIR%" >nul 2>&1

REM Create Start Menu shortcut
echo %BLUE%[INFO]%NC% Creating Start Menu shortcut...
powershell -Command "$WS = New-Object -ComObject WScript.Shell; $SC = $WS.CreateShortcut('%ProgramData%\Microsoft\Windows\Start Menu\Programs\Lynx Spider.lnk'); $SC.TargetPath = '%INSTALL_DIR%\lynx-spider.bat'; $SC.WorkingDirectory = '%INSTALL_DIR%'; $SC.Description = 'LYNX-SPIDER-V1 Cybersecurity Platform'; $SC.Save()"

REM Create Desktop shortcut
powershell -Command "$WS = New-Object -ComObject WScript.Shell; $SC = $WS.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Lynx Spider.lnk'); $SC.TargetPath = '%INSTALL_DIR%\lynx-spider.bat'; $SC.WorkingDirectory = '%INSTALL_DIR%'; $SC.Description = 'LYNX-SPIDER-V1 Cybersecurity Platform'; $SC.Save()"

REM Print summary
echo.
echo %GREEN%================================================================%NC%
echo %GREEN% LYNX-SPIDER-V1 Installation Complete!%NC%
echo %GREEN%================================================================%NC%
echo.
echo %CYAN%Installation Directory:%NC% %INSTALL_DIR%
echo %CYAN%Virtual Environment:%NC% %VENV_DIR%
echo %CYAN%Configuration:%NC% %INSTALL_DIR%\.lynx_spider\config.json
echo.
echo %YELLOW%Usage:%NC%
echo   lynx-spider                    # Run the application
echo   %INSTALL_DIR%\lynx-spider.bat  # Direct execution
echo.
echo %YELLOW%Web Dashboard:%NC% http://localhost:5000
echo.
echo %RED%For authorized security testing only!%NC%
echo.

pause
exit /b 0

:RefreshPath
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USR_PATH=%%b"
set "PATH=%SYS_PATH%;%USR_PATH%"
exit /b 0
