#!/bin/bash

################################################################################
# Database Backup Script
# Author: Iskandar Kurbonov
# Description: Automated database backup with compression and encryption
# Usage: ./database-backup.sh --database myapp [--encrypt] [--s3-upload]
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/databases}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
DB_TYPE="mysql"  # mysql, postgresql, mongodb
RETENTION_DAYS=30
ENCRYPT=false
S3_UPLOAD=false
S3_BUCKET=""

# Database credentials
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-}"
DB_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --database)
            DB_NAME="$2"
            shift 2
            ;;
        --type)
            DB_TYPE="$2"
            shift 2
            ;;
        --encrypt)
            ENCRYPT=true
            shift
            ;;
        --s3-upload)
            S3_UPLOAD=true
            S3_BUCKET="$2"
            shift 2
            ;;
        --retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -h|--help)
            cat << EOF
Database Backup Script

Usage: $0 --database DB_NAME [OPTIONS]

Options:
    --database NAME     Database name to backup (required)
    --type TYPE         Database type: mysql, postgresql, mongodb (default: mysql)
    --encrypt           Encrypt backup with GPG
    --s3-upload BUCKET  Upload to S3 bucket
    --retention DAYS    Retention period in days (default: 30)
    -h, --help          Show this help message

Environment Variables:
    DB_HOST             Database host (default: localhost)
    DB_PORT             Database port (default: 3306)
    DB_USER             Database username (default: root)
    DB_PASS             Database password
    BACKUP_DIR          Backup directory (default: /var/backups/databases)

Examples:
    $0 --database myapp
    $0 --database myapp --encrypt
    $0 --database myapp --encrypt --s3-upload my-backup-bucket
    $0 --database myapp --type postgresql

EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$DB_NAME" ]; then
    echo -e "${RED}Error: --database parameter is required${NC}"
    exit 1
fi

################################################################################
# Functions
################################################################################

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log "${YELLOW}Creating backup directory: $BACKUP_DIR${NC}"
        mkdir -p "$BACKUP_DIR"
    fi
}

backup_mysql() {
    local backup_file="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql"

    log "${GREEN}Starting MySQL backup for database: $DB_NAME${NC}"

    mysqldump \
        --host="$DB_HOST" \
        --port="$DB_PORT" \
        --user="$DB_USER" \
        --password="$DB_PASS" \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --routines \
        --triggers \
        "$DB_NAME" > "$backup_file"

    if [ $? -eq 0 ]; then
        log "${GREEN}✓ MySQL backup created: $backup_file${NC}"
        echo "$backup_file"
    else
        log "${RED}✗ MySQL backup failed${NC}"
        exit 1
    fi
}

backup_postgresql() {
    local backup_file="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql"

    log "${GREEN}Starting PostgreSQL backup for database: $DB_NAME${NC}"

    PGPASSWORD="$DB_PASS" pg_dump \
        --host="$DB_HOST" \
        --port="${DB_PORT:-5432}" \
        --username="$DB_USER" \
        --format=plain \
        --no-owner \
        --no-acl \
        "$DB_NAME" > "$backup_file"

    if [ $? -eq 0 ]; then
        log "${GREEN}✓ PostgreSQL backup created: $backup_file${NC}"
        echo "$backup_file"
    else
        log "${RED}✗ PostgreSQL backup failed${NC}"
        exit 1
    fi
}

backup_mongodb() {
    local backup_dir="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}"

    log "${GREEN}Starting MongoDB backup for database: $DB_NAME${NC}"

    mongodump \
        --host="$DB_HOST" \
        --port="${DB_PORT:-27017}" \
        --username="$DB_USER" \
        --password="$DB_PASS" \
        --db="$DB_NAME" \
        --out="$backup_dir"

    if [ $? -eq 0 ]; then
        # Archive the dump
        local archive_file="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.tar"
        tar -cf "$archive_file" -C "$BACKUP_DIR" "${DB_NAME}_${TIMESTAMP}"
        rm -rf "$backup_dir"

        log "${GREEN}✓ MongoDB backup created: $archive_file${NC}"
        echo "$archive_file"
    else
        log "${RED}✗ MongoDB backup failed${NC}"
        exit 1
    fi
}

compress_backup() {
    local backup_file="$1"
    local compressed_file="${backup_file}.gz"

    log "Compressing backup..."

    gzip -9 "$backup_file"

    if [ $? -eq 0 ]; then
        log "${GREEN}✓ Backup compressed: $compressed_file${NC}"
        echo "$compressed_file"
    else
        log "${RED}✗ Compression failed${NC}"
        exit 1
    fi
}

encrypt_backup() {
    local backup_file="$1"
    local encrypted_file="${backup_file}.gpg"

    log "Encrypting backup with GPG..."

    # Check if GPG key exists
    if ! gpg --list-keys "backup@localhost" &> /dev/null; then
        log "${YELLOW}Warning: GPG key 'backup@localhost' not found. Using symmetric encryption.${NC}"
        gpg --symmetric --cipher-algo AES256 --output "$encrypted_file" "$backup_file"
    else
        gpg --encrypt --recipient "backup@localhost" --output "$encrypted_file" "$backup_file"
    fi

    if [ $? -eq 0 ]; then
        log "${GREEN}✓ Backup encrypted: $encrypted_file${NC}"
        # Remove unencrypted file
        rm -f "$backup_file"
        echo "$encrypted_file"
    else
        log "${RED}✗ Encryption failed${NC}"
        exit 1
    fi
}

upload_to_s3() {
    local backup_file="$1"
    local s3_path
    s3_path="s3://$S3_BUCKET/databases/$(basename "$backup_file")"

    log "Uploading backup to S3: $s3_path"

    aws s3 cp "$backup_file" "$s3_path" --storage-class STANDARD_IA

    if [ $? -eq 0 ]; then
        log "${GREEN}✓ Backup uploaded to S3${NC}"
    else
        log "${RED}✗ S3 upload failed${NC}"
        exit 1
    fi
}

verify_backup() {
    local backup_file="$1"

    log "Verifying backup integrity..."

    # Check file size
    local file_size
    file_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file")
    if [ "$file_size" -lt 1024 ]; then
        log "${RED}✗ Warning: Backup file is suspiciously small (${file_size} bytes)${NC}"
        return 1
    fi

    # Verify compressed file integrity
    if [[ "$backup_file" == *.gz ]]; then
        gzip -t "$backup_file"
        if [ $? -ne 0 ]; then
            log "${RED}✗ Compressed backup is corrupted${NC}"
            return 1
        fi
    fi

    log "${GREEN}✓ Backup verification passed${NC}"
    return 0
}

cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."

    find "$BACKUP_DIR" -name "${DB_NAME}_*.sql*" -type f -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR" -name "${DB_NAME}_*.tar*" -type f -mtime +$RETENTION_DAYS -delete

    log "${GREEN}✓ Old backups cleaned up${NC}"
}

################################################################################
# Main Execution
################################################################################

main() {
    log "========================================="
    log "Database Backup Script"
    log "========================================="
    log "Database: $DB_NAME"
    log "Type: $DB_TYPE"
    log "Timestamp: $TIMESTAMP"
    log "========================================="

    # Create backup directory
    create_backup_dir

    # Perform backup based on database type
    case "$DB_TYPE" in
        mysql)
            BACKUP_FILE=$(backup_mysql)
            ;;
        postgresql)
            BACKUP_FILE=$(backup_postgresql)
            ;;
        mongodb)
            BACKUP_FILE=$(backup_mongodb)
            ;;
        *)
            log "${RED}Error: Unsupported database type: $DB_TYPE${NC}"
            exit 1
            ;;
    esac

    # Compress backup
    BACKUP_FILE=$(compress_backup "$BACKUP_FILE")

    # Encrypt if requested
    if [ "$ENCRYPT" = true ]; then
        BACKUP_FILE=$(encrypt_backup "$BACKUP_FILE")
    fi

    # Verify backup
    verify_backup "$BACKUP_FILE"

    # Upload to S3 if requested
    if [ "$S3_UPLOAD" = true ]; then
        upload_to_s3 "$BACKUP_FILE"
    fi

    # Cleanup old backups
    cleanup_old_backups

    # Summary
    log "========================================="
    log "${GREEN}Backup completed successfully!${NC}"
    log "Final backup file: $BACKUP_FILE"
    log "File size: $(du -h "$BACKUP_FILE" | cut -f1)"
    log "========================================="
}

# Run main function
main
