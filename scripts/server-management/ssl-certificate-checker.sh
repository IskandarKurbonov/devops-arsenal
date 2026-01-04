#!/bin/bash

################################################################################
# SSL Certificate Expiry Checker
# Author: Iskandar Kurbonov
# Description: Monitor SSL certificate expiry and send alerts
# Usage: ./ssl-certificate-checker.sh --domain example.com [--warning-days 30]
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
DOMAIN=""
WARNING_DAYS=30
CRITICAL_DAYS=7
PORT=443
EMAIL_TO=""
SLACK_WEBHOOK=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --warning-days)
            WARNING_DAYS="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --email)
            EMAIL_TO="$2"
            shift 2
            ;;
        --slack-webhook)
            SLACK_WEBHOOK="$2"
            shift 2
            ;;
        -h|--help)
            cat << EOF
SSL Certificate Expiry Checker

Usage: $0 --domain DOMAIN [OPTIONS]

Options:
    --domain DOMAIN       Domain to check (required)
    --warning-days DAYS   Warning threshold in days (default: 30)
    --port PORT          Port number (default: 443)
    --email EMAIL        Send alert to email
    --slack-webhook URL  Send alert to Slack
    -h, --help           Show this help message

Examples:
    $0 --domain example.com
    $0 --domain example.com --warning-days 14
    $0 --domain example.com --email admin@example.com

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: --domain is required${NC}"
    exit 1
fi

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_certificate_info() {
    local domain=$1
    local port=$2

    echo | openssl s_client -servername "$domain" -connect "$domain:$port" 2>/dev/null | \
        openssl x509 -noout -dates 2>/dev/null
}

check_certificate() {
    local domain=$1
    local port=$2

    log "Checking SSL certificate for ${domain}:${port}..."

    # Get certificate info
    local cert_info
    cert_info=$(get_certificate_info "$domain" "$port")

    if [ -z "$cert_info" ]; then
        log "${RED}✗ Failed to retrieve certificate${NC}"
        return 1
    fi

    # Extract expiry date
    local expiry_date
    local expiry_epoch
    local current_epoch
    local days_remaining
    local issue_date

    expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null)
    current_epoch=$(date +%s)
    days_remaining=$(( (expiry_epoch - current_epoch) / 86400 ))

    # Extract issue date
    issue_date=$(echo "$cert_info" | grep "notBefore" | cut -d= -f2)

    log "Certificate Information:"
    log "  Issued: $issue_date"
    log "  Expires: $expiry_date"
    log "  Days remaining: $days_remaining"

    # Check status
    if [ $days_remaining -lt 0 ]; then
        log "${RED}✗ CRITICAL: Certificate EXPIRED!${NC}"
        send_alert "CRITICAL" "$domain" "$days_remaining" "$expiry_date"
        return 2
    elif [ $days_remaining -lt $CRITICAL_DAYS ]; then
        log "${RED}✗ CRITICAL: Certificate expires in $days_remaining days${NC}"
        send_alert "CRITICAL" "$domain" "$days_remaining" "$expiry_date"
        return 2
    elif [ $days_remaining -lt $WARNING_DAYS ]; then
        log "${YELLOW}⚠ WARNING: Certificate expires in $days_remaining days${NC}"
        send_alert "WARNING" "$domain" "$days_remaining" "$expiry_date"
        return 1
    else
        log "${GREEN}✓ Certificate is valid ($days_remaining days remaining)${NC}"
        return 0
    fi
}

send_alert() {
    local severity=$1
    local domain=$2
    local days=$3
    local expiry=$4

    local message="SSL Certificate Alert: $severity
Domain: $domain
Days Remaining: $days
Expiry Date: $expiry"

    # Send email
    if [ -n "$EMAIL_TO" ]; then
        if command -v mail &> /dev/null; then
            echo "$message" | mail -s "[$severity] SSL Certificate Alert - $domain" "$EMAIL_TO"
            log "${GREEN}Email alert sent to $EMAIL_TO${NC}"
        fi
    fi

    # Send Slack notification
    if [ -n "$SLACK_WEBHOOK" ]; then
        local color="danger"
        [ "$severity" = "WARNING" ] && color="warning"

        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"SSL Certificate Alert\",\"attachments\":[{\"color\":\"$color\",\"text\":\"$message\"}]}" \
            "$SLACK_WEBHOOK" &> /dev/null

        log "${GREEN}Slack alert sent${NC}"
    fi
}

main() {
    log "========================================="
    log "SSL Certificate Checker"
    log "========================================="
    log "Domain: $DOMAIN"
    log "Port: $PORT"
    log "Warning threshold: $WARNING_DAYS days"
    log "========================================="

    check_certificate "$DOMAIN" "$PORT"
    exit $?
}

main
