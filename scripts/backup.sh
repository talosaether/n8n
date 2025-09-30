#!/usr/bin/env bash

#######################################
# n8n Backup Script
# Automated backup of n8n data and configuration
#######################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="${PROJECT_ROOT}/backups"
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/backup_${BACKUP_TIMESTAMP}"
RETENTION_DAYS=30

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup
create_backup() {
    log_info "Starting backup process..."

    # Create backup directory
    mkdir -p "$BACKUP_PATH"

    # Backup .env file
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        log_info "Backing up .env file..."
        cp "${PROJECT_ROOT}/.env" "${BACKUP_PATH}/.env"
    else
        log_warn ".env file not found"
    fi

    # Backup docker-compose.yml
    if [ -f "${PROJECT_ROOT}/docker-compose.yml" ]; then
        log_info "Backing up docker-compose.yml..."
        cp "${PROJECT_ROOT}/docker-compose.yml" "${BACKUP_PATH}/docker-compose.yml"
    fi

    # Backup Dockerfile
    if [ -f "${PROJECT_ROOT}/Dockerfile" ]; then
        log_info "Backing up Dockerfile..."
        cp "${PROJECT_ROOT}/Dockerfile" "${BACKUP_PATH}/Dockerfile"
    fi

    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
        # Save container image ID
        log_info "Saving container image information..."
        docker inspect n8n --format='{{.Image}}' > "${BACKUP_PATH}/image_id.txt"

        # Export n8n data volume
        log_info "Exporting n8n data volume... (this may take a while)"
        docker run --rm \
            -v n8n_data:/data \
            -v "${BACKUP_PATH}:/backup" \
            alpine \
            tar czf /backup/n8n_data.tar.gz -C /data .

        # Get database file if accessible
        if docker exec n8n test -f /home/node/.n8n/database.sqlite 2>/dev/null; then
            log_info "Backing up SQLite database..."
            docker exec n8n cat /home/node/.n8n/database.sqlite > "${BACKUP_PATH}/database.sqlite" 2>/dev/null || log_warn "Could not backup database directly"
        fi

        # Export workflows
        log_info "Exporting workflows..."
        docker exec n8n ls /home/node/.n8n/workflows 2>/dev/null | wc -l > "${BACKUP_PATH}/workflow_count.txt" || echo "0" > "${BACKUP_PATH}/workflow_count.txt"

    else
        log_warn "n8n container is not running, only backing up configuration files"
    fi

    # Create backup metadata
    log_info "Creating backup metadata..."
    cat > "${BACKUP_PATH}/backup_info.txt" <<EOF
Backup Information
==================
Timestamp: $(date)
Backup Path: $BACKUP_PATH
Container Status: $(docker ps -a --format '{{.Status}}' --filter "name=^n8n$" 2>/dev/null || echo "Not found")
Docker Version: $(docker --version)
Docker Compose Version: $(docker-compose --version 2>/dev/null || docker compose version 2>/dev/null || echo "Not available")
EOF

    # Calculate backup size
    local backup_size=$(du -sh "$BACKUP_PATH" | cut -f1)

    log_info "Backup completed successfully!"
    log_info "Backup location: $BACKUP_PATH"
    log_info "Backup size: $backup_size"

    # Save backup path for quick reference
    echo "$BACKUP_PATH" > "${PROJECT_ROOT}/.last_backup"
}

# Cleanup old backups
cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."

    local deleted_count=0

    # Find and delete old backups
    while IFS= read -r -d '' backup; do
        rm -rf "$backup"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" -mtime +$RETENTION_DAYS -print0 2>/dev/null)

    if [ $deleted_count -gt 0 ]; then
        log_info "Deleted $deleted_count old backup(s)"
    else
        log_info "No old backups to clean up"
    fi
}

# List backups
list_backups() {
    log_info "Available backups:"
    echo ""

    if [ ! -d "$BACKUP_DIR" ]; then
        log_warn "No backup directory found"
        return
    fi

    local backup_count=0

    for backup in "$BACKUP_DIR"/backup_*; do
        if [ -d "$backup" ]; then
            ((backup_count++))
            local backup_name=$(basename "$backup")
            local backup_date=$(echo "$backup_name" | sed 's/backup_//' | sed 's/_/ /')
            local backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)

            echo "  $backup_count. $backup_name"
            echo "     Date: $backup_date"
            echo "     Size: $backup_size"
            echo "     Path: $backup"
            echo ""
        fi
    done

    if [ $backup_count -eq 0 ]; then
        log_warn "No backups found"
    else
        log_info "Total backups: $backup_count"
    fi
}

# Display help
show_help() {
    cat <<EOF
n8n Backup Script

Usage: $0 [OPTIONS]

Options:
  create       Create a new backup (default)
  list         List all available backups
  cleanup      Remove backups older than $RETENTION_DAYS days
  --help       Show this help message

Examples:
  $0                    # Create a new backup
  $0 create             # Create a new backup
  $0 list               # List all backups
  $0 cleanup            # Clean up old backups

Backup Location: $BACKUP_DIR
Retention Period: $RETENTION_DAYS days
EOF
}

# Main function
main() {
    # Parse arguments
    case "${1:-create}" in
        create)
            create_backup
            cleanup_old_backups
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_old_backups
            ;;
        --help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
