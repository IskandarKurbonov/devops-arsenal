#!/bin/bash

################################################################################
# Zero Downtime Deployment Script
# Author: Iskandar Kurbonov
# Description: Blue-green deployment automation
# Usage: ./zero-downtime-deploy.sh --app myapp --version 1.2.3
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_NAME=""
APP_VERSION=""
HEALTH_CHECK_URL=""
TIMEOUT=300  # Used in wait_for_healthy function

while [[ $# -gt 0 ]]; do
    case $1 in
        --app) APP_NAME="$2"; shift 2 ;;
        --version) APP_VERSION="$2"; shift 2 ;;
        --health-check) HEALTH_CHECK_URL="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ -z "$APP_NAME" ] || [ -z "$APP_VERSION" ]; then
    echo "Error: --app and --version are required"
    exit 1
fi

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

wait_for_healthy() {
    local url=$1
    local start_time
    start_time=$(date +%s)

    while true; do
        if curl -f "$url" &> /dev/null; then
            return 0
        fi

        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ $elapsed -ge $TIMEOUT ]; then
            return 1
        fi

        sleep 5
    done
}

# Determine current and new environments
CURRENT_ENV=$(docker ps --filter "name=${APP_NAME}" --format "{{.Names}}" | grep -o 'blue\|green' | head -1)
if [ "$CURRENT_ENV" = "blue" ]; then
    NEW_ENV="green"
else
    NEW_ENV="blue"
fi

log "${YELLOW}Deploying $APP_NAME:$APP_VERSION to $NEW_ENV environment${NC}"

# Deploy to inactive environment
docker-compose -f docker-compose.${NEW_ENV}.yml up -d

# Health check
log "Waiting for health check..."

if [ -n "$HEALTH_CHECK_URL" ]; then
    if wait_for_healthy "$HEALTH_CHECK_URL"; then
        log "${GREEN}✓ Health check passed${NC}"
    else
        log "${RED}✗ Health check failed, rolling back${NC}"
        docker-compose -f docker-compose.${NEW_ENV}.yml down
        exit 1
    fi
fi

# Switch traffic
log "Switching traffic to $NEW_ENV..."
# Update load balancer/nginx config here

# Stop old environment
log "Stopping $CURRENT_ENV environment..."
docker-compose -f docker-compose.${CURRENT_ENV}.yml down

log "${GREEN}✓ Deployment completed successfully${NC}"
