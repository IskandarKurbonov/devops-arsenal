#!/bin/bash

################################################################################
# Docker Backup Script
# Author: Iskandar Kurbonov
# Description: Backup Docker volumes and configurations
# Usage: ./docker-backup.sh [--output /backup] [--s3-upload]
################################################################################

set -euo pipefail

GREEN='\033[0;32m'
NC='\033[0m'

BACKUP_DIR="${BACKUP_DIR:-/var/backups/docker}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

while [[ $# -gt 0 ]]; do
    case $1 in
        --output) BACKUP_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

mkdir -p "$BACKUP_DIR"

log "${GREEN}Starting Docker backup...${NC}"

# Backup volumes
for volume in $(docker volume ls -q); do
    log "Backing up volume: $volume"
    docker run --rm -v "$volume:/data" -v "$BACKUP_DIR:/backup" \
        alpine tar czf "/backup/${volume}_${TIMESTAMP}.tar.gz" -C /data .
done

# Backup configs
# shellcheck disable=SC2046
docker inspect $(docker ps -aq) > "$BACKUP_DIR/containers_${TIMESTAMP}.json"

log "${GREEN}✓ Backup completed: $BACKUP_DIR${NC}"
