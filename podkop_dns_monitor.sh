#!/bin/sh

# Podkop DNS Monitor Script for OpenWRT
# Monitors DNS server availability and switches configuration accordingly

# Configuration (will be set by install script)
PRIMARY_DNS_SERVER="YOUR_PRIMARY_DNS_SERVER"
BACKUP_DNS_SERVER="dns.adguard-dns.com"
DNS_INTERFACE="YOUR_PRIMARY_DNS_INTERFACE"
TEST_DOMAIN="google.com"
LOG_TAG="podkop-dns-monitor"

# Telegram settings (will be set by install script)
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"

# Function to log messages
log_message() {
    local message="$1"
    local level="$2"
    echo "$(date): $message"
    logger -t "$LOG_TAG" -p "daemon.$level" "$message"
}

# Function to send Telegram notification
send_telegram() {
    local message="$1"
    local formatted_message=$(printf "🔄 Podkop DNS Monitor:\n%s\n🖥 Hostname: %s" "$message" "$(uci get system.@system[0].hostname)")
    if [ "$TELEGRAM_BOT_TOKEN" != "YOUR_BOT_TOKEN_HERE" ] && [ "$TELEGRAM_CHAT_ID" != "YOUR_CHAT_ID_HERE" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$formatted_message" \
            -d parse_mode="HTML" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_message "Telegram notification sent successfully" "info"
        else
            log_message "Failed to send Telegram notification" "warn"
        fi
    else
        log_message "Telegram not configured, skipping notification" "info"
    fi
}

# Function to check DNS server availability using nslookup
check_dns_server() {
    log_message "Checking DNS server $PRIMARY_DNS_SERVER availability with domain $TEST_DOMAIN" "debug"
    
    # Use nslookup without timeout
    if nslookup $TEST_DOMAIN $PRIMARY_DNS_SERVER > /dev/null 2>&1; then
        log_message "DNS server $PRIMARY_DNS_SERVER is available" "debug"
        return 0
    else
        log_message "DNS server $PRIMARY_DNS_SERVER is not available" "debug"
        return 1
    fi
}

# Function to get current configuration state
get_current_config() {
    local current_dns_server=$(uci get podkop.settings.dns_server 2>/dev/null)
    
    if [ "$current_dns_server" = "$PRIMARY_DNS_SERVER" ]; then
        echo "available"
    elif [ "$current_dns_server" = "$BACKUP_DNS_SERVER" ]; then
        echo "unavailable"
    else
        echo "unknown"
    fi
}

# Function to apply configuration for available DNS (primary server)
apply_available_config() {
    log_message "Applying configuration for available DNS server ($PRIMARY_DNS_SERVER)" "info"
    
    uci set podkop.settings.dns_type='udp'
    uci set podkop.settings.dns_server="$PRIMARY_DNS_SERVER"
    uci set podkop.settings.dns_bind_interface='1'
    uci set podkop.settings.dns_interface="$DNS_INTERFACE"
    
    if uci commit podkop; then
        log_message "Configuration committed successfully" "info"
        if podkop restart; then
            log_message "Service restarted successfully" "info"
            send_telegram "Switched to PRIMARY DNS server ($PRIMARY_DNS_SERVER) - Service restarted ✅"
            return 0
        else
            log_message "Failed to restart service" "err"
            send_telegram "⚠️ Configuration applied but service restart FAILED"
            return 1
        fi
    else
        log_message "Failed to commit configuration" "err"
        send_telegram "⚠️ Failed to apply PRIMARY DNS configuration"
        return 1
    fi
}

# Function to apply configuration for unavailable DNS (backup server)
apply_unavailable_config() {
    log_message "Applying configuration for unavailable DNS server ($BACKUP_DNS_SERVER)" "info"
    
    uci del podkop.settings.dns_interface 2>/dev/null
    uci set podkop.settings.dns_type='doh'
    uci set podkop.settings.dns_server="$BACKUP_DNS_SERVER"
    uci set podkop.settings.dns_bind_interface='0'
    
    if uci commit podkop; then
        log_message "Configuration committed successfully" "info"
        if podkop restart; then
            log_message "Service restarted successfully" "info"
            send_telegram "Switched to BACKUP DNS server ($BACKUP_DNS_SERVER) - Service restarted ✅"
            return 0
        else
            log_message "Failed to restart service" "err"
            send_telegram "⚠️ Configuration applied but service restart FAILED"
            return 1
        fi
    else
        log_message "Failed to commit configuration" "err"
        send_telegram "⚠️ Failed to apply BACKUP DNS configuration"
        return 1
    fi
}

# Main logic
main() {
    log_message "Starting DNS monitoring check" "info"
    
    current_config=$(get_current_config)
    log_message "Current configuration state: $current_config" "debug"
    
    if check_dns_server; then
        # DNS server is available
        if [ "$current_config" != "available" ]; then
            log_message "DNS server is available but configuration is not set for available state" "info"
            apply_available_config
        else
            log_message "DNS server is available and configuration is correct" "debug"
        fi
    else
        # DNS server is not available - switch immediately
        if [ "$current_config" != "unavailable" ]; then
            log_message "DNS server is unavailable, switching configuration immediately" "warn"
            apply_unavailable_config
        else
            log_message "DNS server is unavailable but configuration is already set for unavailable state" "debug"
        fi
    fi
    
    log_message "DNS monitoring check completed" "info"
}

# Run main function
main