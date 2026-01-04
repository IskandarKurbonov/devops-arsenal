#!/bin/bash

################################################################################
# Disk Cleanup Script
# Author: Iskandar Kurbonov
# Description: Automated disk space cleanup with safety checks
# Usage: ./disk-cleanup.sh [--aggressive] [--dry-run]
################################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

# Configuration
DRY_RUN=false
AGGRESSIVE=false
LOG_RETENTION_DAYS=30
TEMP_FILE_AGE=7

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --aggressive)
            AGGRESSIVE=true
            shift
            ;;
        -h|--help)
            cat << EOF
Disk Cleanup Script

Usage: $0 [OPTIONS]

Options:
    --dry-run       Show what would be cleaned without removing
    --aggressive    More aggressive cleanup (use with caution)
    -h, --help      Show this help message

Cleaned items:
    - Old log files (older than ${LOG_RETENTION_DAYS} days)
    - Temporary files
    - Package manager caches
    - Old kernels (keeps latest 2)
    - Trash/recycle bin

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}' | tr -d '%'
}

clean_old_logs() {
    log "${YELLOW}Cleaning old log files...${NC}"

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would delete:"
        find /var/log -type f -name "*.log" -mtime +$LOG_RETENTION_DAYS -ls
        find /var/log -type f -name "*.gz" -mtime +$LOG_RETENTION_DAYS -ls
    else
        local count
        count=$(find /var/log -type f \( -name "*.log" -o -name "*.gz" \) -mtime +$LOG_RETENTION_DAYS | wc -l)
        find /var/log -type f \( -name "*.log" -o -name "*.gz" \) -mtime +$LOG_RETENTION_DAYS -delete
        log "${GREEN}✓ Deleted $count old log files${NC}"
    fi
}

clean_temp_files() {
    log "${YELLOW}Cleaning temporary files...${NC}"

    local temp_dirs=("/tmp" "/var/tmp")

    for dir in "${temp_dirs[@]}"; do
        if [ "$DRY_RUN" = true ]; then
            log "[DRY RUN] Would delete from $dir:"
            find "$dir" -type f -atime +$TEMP_FILE_AGE -ls 2>/dev/null || true
        else
            local count
            count=$(find "$dir" -type f -atime +$TEMP_FILE_AGE 2>/dev/null | wc -l)
            find "$dir" -type f -atime +$TEMP_FILE_AGE -delete 2>/dev/null || true
            log "${GREEN}✓ Deleted $count temp files from $dir${NC}"
        fi
    done
}

clean_package_cache() {
    log "${YELLOW}Cleaning package manager cache...${NC}"

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would clean package cache"
        apt-get clean --dry-run 2>/dev/null || true
        apt-get autoclean --dry-run 2>/dev/null || true
    else
        if command -v apt-get &> /dev/null; then
            apt-get clean
            apt-get autoclean
            log "${GREEN}✓ Cleaned APT cache${NC}"
        fi

        if command -v yum &> /dev/null; then
            yum clean all
            log "${GREEN}✓ Cleaned YUM cache${NC}"
        fi
    fi
}

remove_old_kernels() {
    log "${YELLOW}Removing old kernels...${NC}"

    if ! command -v dpkg &> /dev/null; then
        log "${YELLOW}○ Not a Debian-based system, skipping kernel cleanup${NC}"
        return
    fi

    local current_kernel
    local kernels
    current_kernel=$(uname -r)
    kernels=$(dpkg -l | grep linux-image | awk '{print $2}' | grep -v "$current_kernel" | head -n -2)

    if [ -z "$kernels" ]; then
        log "${GREEN}✓ No old kernels to remove${NC}"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would remove kernels:"
        echo "$kernels"
    else
        echo "$kernels" | xargs apt-get -y purge
        log "${GREEN}✓ Removed old kernels${NC}"
    fi
}

clean_journal_logs() {
    log "${YELLOW}Cleaning systemd journal logs...${NC}"

    if ! command -v journalctl &> /dev/null; then
        log "${YELLOW}○ journalctl not found, skipping${NC}"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would vacuum journal logs older than ${LOG_RETENTION_DAYS} days"
    else
        journalctl --vacuum-time=${LOG_RETENTION_DAYS}d
        log "${GREEN}✓ Cleaned journal logs${NC}"
    fi
}

clean_docker() {
    log "${YELLOW}Cleaning Docker resources...${NC}"

    if ! command -v docker &> /dev/null; then
        log "${YELLOW}○ Docker not installed, skipping${NC}"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would clean Docker resources"
        docker system df
    else
        docker system prune -f
        log "${GREEN}✓ Cleaned Docker resources${NC}"
    fi
}

clean_user_cache() {
    log "${YELLOW}Cleaning user cache directories...${NC}"

    if [ "$AGGRESSIVE" = false ]; then
        log "${YELLOW}○ Skipped (use --aggressive to enable)${NC}"
        return
    fi

    local cache_dirs=(
        "$HOME/.cache"
        "$HOME/.thumbnails"
    )

    for dir in "${cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            if [ "$DRY_RUN" = true ]; then
                log "[DRY RUN] Would clean $dir"
                du -sh "$dir"
            else
                rm -rf "${dir:?}"/*
                log "${GREEN}✓ Cleaned $dir${NC}"
            fi
        fi
    done
}

main() {
    log "========================================="
    log "Disk Cleanup Script"
    log "========================================="
    log "Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "LIVE")"
    log "Aggressive: $([ "$AGGRESSIVE" = true ] && echo "Yes" || echo "No")"
    log "========================================="

    INITIAL_USAGE=$(get_disk_usage)
    log "Initial disk usage: ${INITIAL_USAGE}%"

    clean_old_logs
    clean_temp_files
    clean_package_cache
    remove_old_kernels
    clean_journal_logs
    clean_docker
    clean_user_cache

    FINAL_USAGE=$(get_disk_usage)
    log "========================================="
    log "Final disk usage: ${FINAL_USAGE}%"
    log "Space freed: $((INITIAL_USAGE - FINAL_USAGE))%"
    log "${GREEN}Cleanup completed!${NC}"
    log "========================================="
}

main
