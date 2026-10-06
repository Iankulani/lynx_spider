#!/usr/bin/env bash
# ============================================
# LYNX-SPIDER-V1 - Linux/macOS Installer
# Author: Ian Carter Kulani
# ============================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
INSTALL_DIR="${INSTALL_DIR:-/opt/lynx-spider}"
VENV_DIR="${INSTALL_DIR}/venv"
PYTHON_VERSION="3.11"
LOG_FILE="/var/log/lynx-spider-install.log"

# Functions
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║        🕷️  LYNX-SPIDER-V1 - Installation Script                             ║
║        Author: Ian Carter Kulani                                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            OS="debian"
            PKG_MANAGER="apt-get"
        elif [ -f /etc/redhat-release ]; then
            OS="redhat"
            PKG_MANAGER="yum"
        elif [ -f /etc/arch-release ]; then
            OS="arch"
            PKG_MANAGER="pacman"
        else
            OS="linux"
            PKG_MANAGER="apt-get"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        PKG_MANAGER="brew"
    else
        error "Unsupported OS: $OSTYPE"
        exit 1
    fi
    info "Detected OS: $OS"
}

# Install system dependencies
install_system_deps() {
    info "Installing system dependencies..."
    
    case $OS in
        debian)
            apt-get update -qq
            apt-get install -y -qq \
                python3 python3-pip python3-venv python3-dev \
                build-essential gcc g++ make \
                libffi-dev libssl-dev libpcap-dev \
                iputils-ping traceroute nmap netcat-openbsd \
                curl wget dnsutils whois net-tools iproute2 tcpdump \
                git jq htop vim \
                nikto \
                openssh-client \
                hashcat \
                || warn "Some packages failed to install"
            ;;
        redhat)
            yum install -y \
                python3 python3-pip python3-devel \
                gcc gcc-c++ make \
                libffi-devel openssl-devel libpcap-devel \
                iputils traceroute nmap nc \
                curl wget bind-utils whois net-tools iproute tcpdump \
                git jq htop vim \
                openssh-clients \
                || warn "Some packages failed to install"
            ;;
        arch)
            pacman -Sy --noconfirm \
                python python-pip \
                base-devel \
                libffi openssl libpcap \
                iputils traceroute nmap gnu-netcat \
                curl wget bind-tools whois net-tools iproute2 tcpdump \
                git jq htop vim \
                nikto \
                openssh \
                hashcat \
                || warn "Some packages failed to install"
            ;;
        macos)
            if ! command -v brew &> /dev/null; then
                error "Homebrew not found. Please install Homebrew first."
                exit 1
            fi
            brew install python@3.11 \
                nmap netcat curl wget \
                git jq htop \
                || warn "Some packages failed to install"
            ;;
    esac
    
    log "System dependencies installed"
}

# Install Python 3.11+ if needed
install_python() {
    info "Checking Python version..."
    
    if command -v python3.11 &> /dev/null; then
        PYTHON_CMD="python3.11"
    elif command -v python3 &> /dev/null; then
        PY_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        if (( $(echo "$PY_VERSION >= 3.7" | bc -l) )); then
            PYTHON_CMD="python3"
        else
            error "Python 3.7+ required. Found: $PY_VERSION"
            exit 1
        fi
    else
        error "Python 3 not found"
        exit 1
    fi
    
    log "Using Python: $PYTHON_CMD ($($PYTHON_CMD --version))"
}

# Create installation directory
create_install_dir() {
    info "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/.lynx_spider"
    mkdir -p "$INSTALL_DIR/lynx_spider_reports"
    mkdir -p /var/log/lynx-spider
    
    log "Directories created"
}

# Copy application files
copy_files() {
    info "Copying application files..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [ -f "$SCRIPT_DIR/lynx_spider.py" ]; then
        cp "$SCRIPT_DIR/lynx_spider.py" "$INSTALL_DIR/"
    else
        error "lynx_spider.py not found in $SCRIPT_DIR"
        exit 1
    fi
    
    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"
    fi
    
    if [ -d "$SCRIPT_DIR/config" ]; then
        cp -r "$SCRIPT_DIR/config" "$INSTALL_DIR/"
    fi
    
    log "Application files copied"
}

# Create virtual environment
create_venv() {
    info "Creating virtual environment..."
    $PYTHON_CMD -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip setuptools wheel
    log "Virtual environment created"
}

# Install Python dependencies
install_python_deps() {
    info "Installing Python dependencies..."
    source "$VENV_DIR/bin/activate"
    
    if [ -f "$INSTALL_DIR/requirements.txt" ]; then
        pip install -r "$INSTALL_DIR/requirements.txt" || warn "Some dependencies failed to install"
    else
        warn "requirements.txt not found, installing core dependencies..."
        pip install requests scapy dnspython paramiko psutil colorama flask flask-socketio
    fi
    
    log "Python dependencies installed"
}

# Create configuration
create_config() {
    info "Creating configuration..."
    
    CONFIG_FILE="$INSTALL_DIR/.lynx_spider/config.json"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
{
    "version": "1.0.0",
    "auto_start": false,
    "auto_block_enabled": false,
    "scan_timeout": 30,
    "report_format": "html",
    "generate_graphics": true,
    "keylogger": {
        "enabled": false,
        "hotkey": "f10"
    },
    "web": {
        "enabled": true,
        "port": 5000,
        "host": "0.0.0.0"
    },
    "monitoring": {
        "enabled": true
    }
}
EOF
        log "Configuration created"
    else
        info "Configuration already exists, skipping"
    fi
}

# Create systemd service (Linux only)
create_systemd_service() {
    if [[ "$OS" == "linux" ]]; then
        info "Creating systemd service..."
        
        cat > /etc/systemd/system/lynx-spider.service << EOF
[Unit]
Description=LYNX-SPIDER-V1 Cybersecurity Platform
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$VENV_DIR/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$VENV_DIR/bin/python3 $INSTALL_DIR/lynx_spider.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        log "Systemd service created: lynx-spider.service"
        info "To enable: systemctl enable lynx-spider"
        info "To start: systemctl start lynx-spider"
    fi
}

# Create launcher script
create_launcher() {
    info "Creating launcher script..."
    
    cat > /usr/local/bin/lynx-spider << EOF
#!/usr/bin/env bash
source $VENV_DIR/bin/activate
cd $INSTALL_DIR
python3 lynx_spider.py "\$@"
EOF
    chmod +x /usr/local/bin/lynx-spider
    
    log "Launcher created: /usr/local/bin/lynx-spider"
}

# Print summary
print_summary() {
    echo -e "\n${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ LYNX-SPIDER-V1 Installation Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}Installation Directory:${NC} $INSTALL_DIR"
    echo -e "${CYAN}Virtual Environment:${NC} $VENV_DIR"
    echo -e "${CYAN}Configuration:${NC} $INSTALL_DIR/.lynx_spider/config.json"
    echo -e "${CYAN}Log File:${NC} $LOG_FILE"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  ${GREEN}lynx-spider${NC}                    # Run the application"
    echo -e "  ${GREEN}systemctl start lynx-spider${NC}    # Start as service"
    echo -e "  ${GREEN}systemctl status lynx-spider${NC}   # Check service status"
    echo ""
    echo -e "${YELLOW}Web Dashboard:${NC} http://localhost:5000"
    echo ""
    echo -e "${RED}⚠️  For authorized security testing only!${NC}"
    echo ""
}

# Main installation
main() {
    print_banner
    
    check_root
    detect_os
    install_system_deps
    install_python
    create_install_dir
    copy_files
    create_venv
    install_python_deps
    create_config
    create_systemd_service
    create_launcher
    print_summary
    
    log "Installation completed successfully"
}

# Run
main "$@"
