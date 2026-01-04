#!/bin/bash

################################################################################
# Docker Cleanup Script
# Author: Iskandar Kurbonov
# Description: Clean up unused Docker resources (containers, images, volumes)
# Usage: ./docker-cleanup.sh [--dry-run] [--force] [--all]
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DRY_RUN=false
FORCE=false
CLEAN_ALL=false
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_DIR="${LOG_DIR:-/var/log}"
LOG_FILE="${LOG_DIR}/docker-cleanup-${TIMESTAMP}.log"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --all)
            CLEAN_ALL=true
            shift
            ;;
        -h|--help)
            cat << EOF
Docker Cleanup Script

Usage: $0 [OPTIONS]

Options:
    --dry-run       Show what would be removed without removing
    --force         Skip confirmation prompts
    --all           Remove all unused resources (aggressive)
    -h, --help      Show this help message

Examples:
    $0 --dry-run          # See what would be removed
    $0 --force            # Clean without prompts
    $0 --all --force      # Aggressive cleanup without prompts

EOF
            exit 0
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
}

log_header() {
    log "\n${BLUE}=========================================${NC}"
    log "${BLUE}$1${NC}"
    log "${BLUE}=========================================${NC}"
}

confirm() {
    if [ "$FORCE" = true ]; then
        return 0
    fi

    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
    return 0
}

get_size() {
    docker system df --format "{{.Size}}" | head -1
}

cleanup_stopped_containers() {
    log_header "Cleaning Stopped Containers"

    STOPPED_CONTAINERS=$(docker ps -aq -f status=exited)

    if [ -z "$STOPPED_CONTAINERS" ]; then
        log "${GREEN}✓ No stopped containers found${NC}"
        return
    fi

    CONTAINER_COUNT=$(echo "$STOPPED_CONTAINERS" | wc -l)
    log "Found $CONTAINER_COUNT stopped container(s)"

    if [ "$DRY_RUN" = true ]; then
        log "${YELLOW}[DRY RUN] Would remove:${NC}"
        docker ps -a -f status=exited --format "table {{.Names}}\t{{.Status}}\t{{.Size}}"
        return
    fi

    if confirm "Remove $CONTAINER_COUNT stopped container(s)?"; then
        docker rm $STOPPED_CONTAINERS
        log "${GREEN}✓ Removed $CONTAINER_COUNT stopped container(s)${NC}"
    else
        log "${YELLOW}○ Skipped${NC}"
    fi
}

cleanup_dangling_images() {
    log_header "Cleaning Dangling Images"

    DANGLING_IMAGES=$(docker images -qf "dangling=true")

    if [ -z "$DANGLING_IMAGES" ]; then
        log "${GREEN}✓ No dangling images found${NC}"
        return
    fi

    IMAGE_COUNT=$(echo "$DANGLING_IMAGES" | wc -l)
    log "Found $IMAGE_COUNT dangling image(s)"

    if [ "$DRY_RUN" = true ]; then
        log "${YELLOW}[DRY RUN] Would remove:${NC}"
        docker images -f "dangling=true" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
        return
    fi

    if confirm "Remove $IMAGE_COUNT dangling image(s)?"; then
        docker rmi $DANGLING_IMAGES
        log "${GREEN}✓ Removed $IMAGE_COUNT dangling image(s)${NC}"
    else
        log "${YELLOW}○ Skipped${NC}"
    fi
}

cleanup_unused_images() {
    log_header "Cleaning Unused Images"

    if [ "$CLEAN_ALL" = false ]; then
        log "${YELLOW}○ Skipped (use --all to clean unused images)${NC}"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        log "${YELLOW}[DRY RUN] Would remove unused images${NC}"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -v "REPOSITORY"
        return
    fi

    if confirm "Remove all unused images?"; then
        docker image prune -a -f
        log "${GREEN}✓ Removed unused images${NC}"
    else
        log "${YELLOW}○ Skipped${NC}"
    fi
}

cleanup_unused_volumes() {
    log_header "Cleaning Unused Volumes"

    UNUSED_VOLUMES=$(docker volume ls -qf dangling=true)

    if [ -z "$UNUSED_VOLUMES" ]; then
        log "${GREEN}✓ No unused volumes found${NC}"
        return
    fi

    VOLUME_COUNT=$(echo "$UNUSED_VOLUMES" | wc -l)
    log "Found $VOLUME_COUNT unused volume(s)"

    if [ "$DRY_RUN" = true ]; then
        log "${YELLOW}[DRY RUN] Would remove:${NC}"
        docker volume ls -f dangling=true --format "table {{.Name}}\t{{.Driver}}"
        return
    fi

    log "${RED}WARNING: This will permanently delete data in these volumes!${NC}"
    if confirm "Remove $VOLUME_COUNT unused volume(s)?"; then
        docker volume rm $UNUSED_VOLUMES
        log "${GREEN}✓ Removed $VOLUME_COUNT unused volume(s)${NC}"
    else
        log "${YELLOW}○ Skipped${NC}"
    fi
}

cleanup_networks() {
    log_header "Cleaning Unused Networks"

    if [ "$DRY_RUN" = true ]; then
        log "${YELLOW}[DRY RUN] Would remove unused networks${NC}"
        docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
        return
    fi

    REMOVED=$(docker network prune -f 2>&1 | grep "Deleted Networks" || true)

    if [ -n "$REMOVED" ]; then
        log "${GREEN}✓ $REMOVED${NC}"
    else
        log "${GREEN}✓ No unused networks found${NC}"
    fi
}

cleanup_build_cache() {
    log_header "Cleaning Build Cache"

    # Get build cache info
    local cache_info
    cache_info=$(docker system df 2>/dev/null | grep -i "build cache" || echo "")

    if [ -z "$cache_info" ]; then
        log "${GREEN}✓ No build cache found${NC}"
        return
    fi

    local cache_size
    cache_size=$(echo "$cache_info" | awk '{print $4}')

    if [ "$cache_size" = "0B" ] || [ -z "$cache_size" ]; then
        log "${GREEN}✓ No build cache to clean${NC}"
        return
    fi

    log "Build cache size: $cache_size"

    if [ "$DRY_RUN" = true ]; then
        log "${YELLOW}[DRY RUN] Would remove build cache ($cache_size)${NC}"
        return
    fi

    if confirm "Remove build cache ($cache_size)?"; then
        docker builder prune -a -f 2>/dev/null || docker buildx prune -a -f 2>/dev/null || true
        log "${GREEN}✓ Removed build cache${NC}"
    else
        log "${YELLOW}○ Skipped${NC}"
    fi
}

show_summary() {
    log_header "Storage Summary"

    docker system df

    log "\n${GREEN}Cleanup completed!${NC}"
    log "Log file: $LOG_FILE"
}

################################################################################
# Main Execution
################################################################################

main() {
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log "${RED}✗ Error: Docker is not running${NC}"
        exit 1
    fi

    log_header "Docker Cleanup Script"
    log "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    log "Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "LIVE")"
    log "Force: $([ "$FORCE" = true ] && echo "Yes" || echo "No")"
    log "Clean All: $([ "$CLEAN_ALL" = true ] && echo "Yes" || echo "No")"

    # Show initial disk usage
    log_header "Initial Storage Status"
    docker system df

    # Run cleanup operations
    cleanup_stopped_containers
    cleanup_dangling_images
    cleanup_unused_images
    cleanup_unused_volumes
    cleanup_networks
    cleanup_build_cache

    # Show final summary
    if [ "$DRY_RUN" = false ]; then
        show_summary
    else
        log "\n${YELLOW}This was a dry run. No changes were made.${NC}"
        log "Run without --dry-run to actually remove resources."
    fi
}

# Run main function
main
