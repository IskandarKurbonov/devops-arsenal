#!/bin/bash

################################################################################
# Server Health Check Script
# Author: Iskandar Kurbonov
# Description: Comprehensive server health monitoring with alerting
# Usage: ./server-health-check.sh [--email recipient@example.com] [--slack-webhook URL]
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/var/log/health-check.log"
REPORT=""

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
LOAD_THRESHOLD=4.0

# Parse command line arguments
EMAIL_TO=""
SLACK_WEBHOOK=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --email)
            EMAIL_TO="$2"
            shift 2
            ;;
        --slack-webhook)
            SLACK_WEBHOOK="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

################################################################################
# Functions
################################################################################

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
    REPORT+="$1\n"
}

log_header() {
    log "\n========================================="
    log "$1"
    log "========================================="
}

check_cpu() {
    log_header "CPU Check"

    # Get CPU usage (average over 1 minute)
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    CPU_USAGE_INT=${CPU_USAGE%.*}

    if (( $(echo "$CPU_USAGE_INT > $CPU_THRESHOLD" | bc -l) )); then
        log "${RED}✗ CPU Usage: ${CPU_USAGE}% (WARNING: Above ${CPU_THRESHOLD}%)${NC}"
        return 1
    else
        log "${GREEN}✓ CPU Usage: ${CPU_USAGE}% (OK)${NC}"
        return 0
    fi
}

check_memory() {
    log_header "Memory Check"

    # Get memory usage
    MEMORY_TOTAL=$(free -m | awk 'NR==2{print $2}')
    MEMORY_USED=$(free -m | awk 'NR==2{print $3}')
    MEMORY_USAGE=$(awk "BEGIN {printf \"%.2f\", ($MEMORY_USED/$MEMORY_TOTAL)*100}")
    MEMORY_USAGE_INT=${MEMORY_USAGE%.*}

    log "Total Memory: ${MEMORY_TOTAL}MB"
    log "Used Memory: ${MEMORY_USED}MB"

    if (( MEMORY_USAGE_INT > MEMORY_THRESHOLD )); then
        log "${RED}✗ Memory Usage: ${MEMORY_USAGE}% (WARNING: Above ${MEMORY_THRESHOLD}%)${NC}"
        return 1
    else
        log "${GREEN}✓ Memory Usage: ${MEMORY_USAGE}% (OK)${NC}"
        return 0
    fi
}

check_disk() {
    log_header "Disk Check"

    local has_warning=0

    # Check all mounted filesystems
    while IFS= read -r line; do
        local usage mount_point
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        mount_point=$(echo "$line" | awk '{print $6}')

        if (( usage > DISK_THRESHOLD )); then
            log "${RED}✗ ${mount_point}: ${usage}% (WARNING: Above ${DISK_THRESHOLD}%)${NC}"
            has_warning=1
        else
            log "${GREEN}✓ ${mount_point}: ${usage}% (OK)${NC}"
        fi
    done < <(df -h | grep -vE '^Filesystem|tmpfs|cdrom|loop')

    return $has_warning
}

check_load_average() {
    log_header "Load Average Check"

    LOAD_1MIN=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $1}' | xargs)
    LOAD_5MIN=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $2}' | xargs)
    LOAD_15MIN=$(uptime | awk -F'load average:' '{print $2}' | awk -F, '{print $3}' | xargs)

    log "Load Average: $LOAD_1MIN, $LOAD_5MIN, $LOAD_15MIN"

    if (( $(echo "$LOAD_1MIN > $LOAD_THRESHOLD" | bc -l) )); then
        log "${RED}✗ High load average (WARNING)${NC}"
        return 1
    else
        log "${GREEN}✓ Load average normal${NC}"
        return 0
    fi
}

check_network() {
    log_header "Network Check"

    # Check internet connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log "${GREEN}✓ Internet connectivity: OK${NC}"
    else
        log "${RED}✗ Internet connectivity: FAILED${NC}"
        return 1
    fi

    # Check DNS resolution
    if nslookup google.com &> /dev/null; then
        log "${GREEN}✓ DNS resolution: OK${NC}"
    else
        log "${RED}✗ DNS resolution: FAILED${NC}"
        return 1
    fi

    return 0
}

check_services() {
    log_header "Service Status Check"

    # Common services to check (customize as needed)
    SERVICES=("nginx" "mysql" "redis" "docker")

    local has_failure=0

    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log "${GREEN}✓ $service: running${NC}"
        else
            log "${YELLOW}○ $service: not running or not installed${NC}"
        fi
    done

    return $has_failure
}

check_ssl_certificates() {
    log_header "SSL Certificate Check"

    # Example: Check SSL certificate expiry (customize domain)
    DOMAIN="example.com"

    if command -v openssl &> /dev/null; then
        EXPIRY_DATE=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | \
                     openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)

        if [ -n "$EXPIRY_DATE" ]; then
            EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
            CURRENT_EPOCH=$(date +%s)
            DAYS_REMAINING=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))

            if (( DAYS_REMAINING < 30 )); then
                log "${RED}✗ SSL Certificate expires in $DAYS_REMAINING days (WARNING)${NC}"
                return 1
            else
                log "${GREEN}✓ SSL Certificate valid ($DAYS_REMAINING days remaining)${NC}"
            fi
        else
            log "${YELLOW}○ SSL Certificate check skipped (domain not configured)${NC}"
        fi
    else
        log "${YELLOW}○ OpenSSL not installed, skipping SSL check${NC}"
    fi

    return 0
}

check_docker() {
    log_header "Docker Health Check"

    if command -v docker &> /dev/null; then
        CONTAINER_COUNT=$(docker ps -q | wc -l)
        STOPPED_COUNT=$(docker ps -aq -f status=exited | wc -l)

        log "Running containers: $CONTAINER_COUNT"
        log "Stopped containers: $STOPPED_COUNT"

        # Check for unhealthy containers
        UNHEALTHY=$(docker ps --filter health=unhealthy -q | wc -l)
        if (( UNHEALTHY > 0 )); then
            log "${RED}✗ Unhealthy containers detected: $UNHEALTHY${NC}"
            docker ps --filter health=unhealthy --format "table {{.Names}}\t{{.Status}}" | tee -a "$LOG_FILE"
            return 1
        else
            log "${GREEN}✓ All containers healthy${NC}"
        fi
    else
        log "${YELLOW}○ Docker not installed${NC}"
    fi

    return 0
}

send_email_alert() {
    if [ -n "$EMAIL_TO" ] && command -v mail &> /dev/null; then
        echo -e "$REPORT" | mail -s "Server Health Check: $HOSTNAME" "$EMAIL_TO"
        log "${GREEN}Email alert sent to $EMAIL_TO${NC}"
    fi
}

send_slack_alert() {
    if [ -n "$SLACK_WEBHOOK" ]; then
        SLACK_MESSAGE=$(echo -e "$REPORT" | sed 's/\\033\[[0-9;]*m//g')  # Remove color codes

        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"Server Health Check: $HOSTNAME\n\`\`\`$SLACK_MESSAGE\`\`\`\"}" \
            "$SLACK_WEBHOOK" &> /dev/null

        log "${GREEN}Slack alert sent${NC}"
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    log_header "Server Health Check Report"
    log "Timestamp: $TIMESTAMP"
    log "Hostname: $HOSTNAME"

    OVERALL_STATUS=0

    # Run all checks
    check_cpu || OVERALL_STATUS=1
    check_memory || OVERALL_STATUS=1
    check_disk || OVERALL_STATUS=1
    check_load_average || OVERALL_STATUS=1
    check_network || OVERALL_STATUS=1
    check_services || OVERALL_STATUS=1
    check_ssl_certificates || OVERALL_STATUS=1
    check_docker || OVERALL_STATUS=1

    # Summary
    log_header "Summary"
    if (( OVERALL_STATUS == 0 )); then
        log "${GREEN}✓ All checks passed${NC}"
    else
        log "${RED}✗ Some checks failed - please review${NC}"

        # Send alerts if configured
        send_email_alert
        send_slack_alert
    fi

    exit $OVERALL_STATUS
}

# Run main function
main
