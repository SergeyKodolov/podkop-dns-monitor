#!/bin/sh

# Installation script for Podkop DNS Monitor
# This script downloads and installs the DNS monitoring script from GitHub

GITHUB_RAW_URL="https://raw.githubusercontent.com/SergeyKodolov/podkop-dns-monitor/refs/heads/main/podkop_dns_monitor.sh"
SCRIPT_NAME="podkop_dns_monitor.sh"
INSTALL_PATH="/usr/bin/podkop_dns_monitor"
CRON_ENTRY="* * * * * $INSTALL_PATH"
LOG_TAG="podkop-dns-monitor"
LOG_TAG_INSTALL="$LOG_TAG-install"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}$message${NC}"
}

# Function to log messages
log_message() {
    local message="$1"
    local level="$2"
    print_message "$GREEN" "[$level] $message"
    logger -t "$LOG_TAG_INSTALL" -p "daemon.$level" "$message"
}

# Check if running on OpenWrt
check_openwrt() {
    if ! grep -q -e "OpenWrt" -e "immortalwrt" /etc/os-release; then
        print_message "$RED" "Error: This script is designed for OpenWrt or ImmortalWrt. Exiting."
        exit 1
    fi
    log_message "Running on supported OS" "info"
}

# Function to check if script is run as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_message "$RED" "Error: This script must be run as root"
        exit 1
    fi
}

# Function to check if required commands are available
check_dependencies() {
    local missing_deps=""
    
    for cmd in uci nslookup curl crontab logger podkop; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            missing_deps="$missing_deps $cmd"
        fi
    done
    
    if [ -n "$missing_deps" ]; then
        print_message "$RED" "Error: Missing required commands:$missing_deps"
        print_message "$YELLOW" "Please install missing packages and try again"
        exit 1
    fi
    
    log_message "All dependencies are available" "info"
}

# Function to collect user configuration
collect_config() {
    print_message "$BLUE" "╔══════════════════════════════════════════════════════════════╗"
    print_message "$BLUE" "║                 Podkop DNS Monitor Setup                     ║"
    print_message "$BLUE" "╚══════════════════════════════════════════════════════════════╝"
    print_message "$YELLOW" ""
    
    # Telegram Bot Token
    while [ -z "$TELEGRAM_BOT_TOKEN" ]; do
        print_message "$YELLOW" "Enter your Telegram Bot Token (from @BotFather):"
        printf "> "
        read TELEGRAM_BOT_TOKEN
        if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
            print_message "$RED" "Bot Token cannot be empty!"
        fi
    done
    
    # Telegram Chat ID
    while [ -z "$TELEGRAM_CHAT_ID" ]; do
        print_message "$YELLOW" "Enter your Telegram Chat ID (from @userinfobot):"
        printf "> "
        read TELEGRAM_CHAT_ID
        if [ -z "$TELEGRAM_CHAT_ID" ]; then
            print_message "$RED" "Chat ID cannot be empty!"
        fi
    done
    
    # Primary DNS Server
    while [ -z "$PRIMARY_DNS_SERVER" ]; do
        print_message "$YELLOW" "Enter Primary DNS Server IP:"
        printf "> "
        read PRIMARY_DNS_SERVER
        if [ -z "$PRIMARY_DNS_SERVER" ]; then
            print_message "$RED" "Primary DNS Server cannot be empty!"
        fi
    done
    
    # DNS Interface
    while [ -z "$DNS_INTERFACE" ]; do
        print_message "$YELLOW" "Enter DNS Interface name:"
        printf "> "
        read DNS_INTERFACE
        if [ -z "$DNS_INTERFACE" ]; then
            print_message "$RED" "DNS Interface name cannot be empty!"
        fi
    done
    
    # Test Domain
    print_message "$YELLOW" "Enter test domain for DNS checks [default: google.com]:"
    printf "> "
    read user_test_domain
    TEST_DOMAIN=${user_test_domain:-"google.com"}
    
    # Backup DNS Server
    print_message "$YELLOW" "Enter Backup DNS Server [default: dns.adguard-dns.com]:"
    printf "> "
    read user_backup_dns
    BACKUP_DNS_SERVER=${user_backup_dns:-"dns.adguard-dns.com"}
    
    print_message "$GREEN" ""
    print_message "$GREEN" "Configuration Summary:"
    print_message "$GREEN" "- Primary DNS: $PRIMARY_DNS_SERVER"
    print_message "$GREEN" "- Backup DNS: $BACKUP_DNS_SERVER"
    print_message "$GREEN" "- DNS Interface: $DNS_INTERFACE"
    print_message "$GREEN" "- Test Domain: $TEST_DOMAIN"
    print_message "$GREEN" "- Telegram Bot Token: ${TELEGRAM_BOT_TOKEN:0:10}..."
    print_message "$GREEN" "- Telegram Chat ID: $TELEGRAM_CHAT_ID"
    print_message "$YELLOW" ""
    
    print_message "$YELLOW" "Continue with installation? [y/N]"
    printf "> "
    read confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_message "$RED" "Installation cancelled"
        exit 1
    fi
}

# Function to download script from GitHub
download_script() {
    print_message "$YELLOW" "Downloading DNS monitor script from GitHub..."
    
    local download_url="$GITHUB_RAW_URL"
    
    if curl -s -f "$download_url" -o "$SCRIPT_NAME"; then
        log_message "Script downloaded successfully from GitHub" "info"
    else
        print_message "$RED" "Error: Failed to download script from GitHub"
        print_message "$RED" "Please check the URL: $download_url"
        exit 1
    fi
    
    # Verify downloaded file
    if [ ! -f "$SCRIPT_NAME" ] || [ ! -s "$SCRIPT_NAME" ]; then
        print_message "$RED" "Error: Downloaded script is empty or missing"
        exit 1
    fi
}

# Function to configure downloaded script
configure_script() {
    print_message "$YELLOW" "Configuring script with your settings..."
    
    # Replace configuration variables in the script
    sed -i "s/PRIMARY_DNS_SERVER=\".*\"/PRIMARY_DNS_SERVER=\"$PRIMARY_DNS_SERVER\"/" "$SCRIPT_NAME"
    sed -i "s/BACKUP_DNS_SERVER=\".*\"/BACKUP_DNS_SERVER=\"$BACKUP_DNS_SERVER\"/" "$SCRIPT_NAME"
    sed -i "s/DNS_INTERFACE=\".*\"/DNS_INTERFACE=\"$DNS_INTERFACE\"/" "$SCRIPT_NAME"
    sed -i "s/TEST_DOMAIN=\".*\"/TEST_DOMAIN=\"$TEST_DOMAIN\"/" "$SCRIPT_NAME"
    sed -i "s/TELEGRAM_BOT_TOKEN=\".*\"/TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\"/" "$SCRIPT_NAME"
    sed -i "s/TELEGRAM_CHAT_ID=\".*\"/TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\"/" "$SCRIPT_NAME"
    sed -i "s/LOG_TAG=\".*\"/LOG_TAG=\"$LOG_TAG\"/" "$SCRIPT_NAME"
    
    log_message "Script configured with user settings" "info"
}

# Function to backup existing script if it exists
backup_existing() {
    if [ -f "$INSTALL_PATH" ]; then
        local backup_path="${INSTALL_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$INSTALL_PATH" "$backup_path"
        log_message "Existing script backed up to: $backup_path" "info"
    fi
}

# Function to install the script
install_script() {
    # Copy script to install path
    cp "$SCRIPT_NAME" "$INSTALL_PATH"
    
    # Make it executable
    chmod +x "$INSTALL_PATH"
    
    # Clean up downloaded file
    rm -f "$SCRIPT_NAME"
    
    # Verify installation
    if [ -x "$INSTALL_PATH" ]; then
        log_message "Script installed successfully to: $INSTALL_PATH" "info"
    else
        print_message "$RED" "Error: Failed to install script"
        exit 1
    fi
}

# Function to setup cron job
setup_cron() {
    # Check if cron entry already exists
    if crontab -l 2>/dev/null | grep -q "$INSTALL_PATH"; then
        log_message "Cron job already exists, removing old entry" "info"
        crontab -l 2>/dev/null | grep -v "$INSTALL_PATH" | crontab -
    fi
    
    # Add new cron entry
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    
    # Verify cron job was added
    if crontab -l 2>/dev/null | grep -q "$INSTALL_PATH"; then
        log_message "Cron job added successfully: $CRON_ENTRY" "info"
    else
        print_message "$RED" "Error: Failed to add cron job"
        exit 1
    fi
}

# Function to test installation
test_installation() {
    print_message "$YELLOW" "Testing installation..."
    
    # Test script execution
    if "$INSTALL_PATH" > /dev/null 2>&1; then
        log_message "Script executes without errors" "info"
    else
        print_message "$RED" "Warning: Script execution test failed"
    fi
    
    # Test podkop command
    if podkop check_dns_available > /dev/null 2>&1; then
        log_message "podkop command works" "info"
    else
        print_message "$YELLOW" "Warning: podkop command not available"
    fi
    
    # Check cron service
    if pgrep crond > /dev/null 2>&1; then
        log_message "Cron daemon is running" "info"
    else
        print_message "$YELLOW" "Warning: Cron daemon is not running. Start it with: /etc/init.d/cron start"
    fi
}

# Function to display status and next steps
show_status() {
    print_message "$GREEN" "╔═══════════════════════════════════════════════════════════════╗"
    print_message "$GREEN" "║                    INSTALLATION COMPLETE                      ║"
    print_message "$GREEN" "╚═══════════════════════════════════════════════════════════════╝"
    print_message "$GREEN" ""
    print_message "$GREEN" "✅ Podkop DNS Monitor script downloaded and configured"
    print_message "$GREEN" "✅ Script installed to: $INSTALL_PATH"
    print_message "$GREEN" "✅ Cron job configured to run every 5 minutes"
    print_message "$GREEN" "✅ Telegram notifications configured"
    print_message "$GREEN" "✅ Logging enabled (check with: logread -f | grep $LOG_TAG)"
    print_message "$YELLOW" ""
    print_message "$YELLOW" "📋 Management commands:"
    print_message "$YELLOW" "• Test manually: $INSTALL_PATH"
    print_message "$YELLOW" "• Monitor logs: logread -f | grep $LOG_TAG"
    print_message "$YELLOW" "• Check cron: crontab -l"
    print_message "$YELLOW" "• Remove cron: crontab -l | grep -v $INSTALL_PATH | crontab -"
    print_message "$GREEN" ""
    print_message "$GREEN" "The script will start monitoring DNS automatically!"
    print_message "$GREEN" "First check will run within 5 minutes."
}

# Main installation process
main() {
    print_message "$GREEN" "Starting DNS Monitor installation from GitHub..."
    
    check_openwrt
    check_root
    check_dependencies
    collect_config
    download_script
    configure_script
    backup_existing
    install_script
    setup_cron
    test_installation
    show_status
    
    log_message "DNS Monitor installation completed successfully" "info"
}

# Handle script interruption
trap 'print_message "$RED" "Installation interrupted"; rm -f "$SCRIPT_NAME"; exit 1' INT TERM

# Run main function
main