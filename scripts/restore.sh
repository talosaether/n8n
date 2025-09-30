#!/usr/bin/env bash

#######################################
# n8n Restore Script
# Restore n8n from backup
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

# Detect Docker Compose command
detect_compose_command() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        return 1
    fi
}

# Set Docker Compose command
COMPOSE_CMD=$(detect_compose_command)
if [ -z "$COMPOSE_CMD" ]; then
    echo "Error: Docker Compose is not installed"
    exit 1
fi

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

# List available backups
list_backups() {
    log_info "Available backups:"
    echo ""

    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "No backup directory found at $BACKUP_DIR"
        exit 1
    fi

    local backup_count=0
    local -a backup_array

    for backup in "$BACKUP_DIR"/backup_*; do
        if [ -d "$backup" ]; then
            ((backup_count++))
            backup_array+=("$backup")
            local backup_name=$(basename "$backup")
            local backup_date=$(echo "$backup_name" | sed 's/backup_//' | sed 's/_/ /')
            local backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)

            echo "  $backup_count. $backup_name"
            echo "     Date: $backup_date"
            echo "     Size: $backup_size"
            echo ""
        fi
    done

    if [ $backup_count -eq 0 ]; then
        log_error "No backups found"
        exit 1
    fi

    echo "${backup_array[@]}"
}

# Restore from backup
restore_backup() {
    local backup_path="$1"

    if [ ! -d "$backup_path" ]; then
        log_error "Backup directory not found: $backup_path"
        exit 1
    fi

    log_info "Restoring from: $backup_path"

    # Confirmation prompt
    echo ""
    log_warn "This will stop the current n8n instance and restore from backup."
    log_warn "Current data will be replaced. Continue? (yes/no)"
    read -r confirmation

    if [ "$confirmation" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi

    cd "$PROJECT_ROOT"

    # Stop current deployment
    log_info "Stopping current n8n deployment..."
    $COMPOSE_CMD down --timeout 30 || true

    # Restore configuration files
    if [ -f "${backup_path}/.env" ]; then
        log_info "Restoring .env file..."
        cp "${backup_path}/.env" "${PROJECT_ROOT}/.env"
    else
        log_warn ".env file not found in backup"
    fi

    if [ -f "${backup_path}/docker-compose.yml" ]; then
        log_info "Restoring docker-compose.yml..."
        cp "${backup_path}/docker-compose.yml" "${PROJECT_ROOT}/docker-compose.yml"
    else
        log_warn "docker-compose.yml not found in backup"
    fi

    if [ -f "${backup_path}/Dockerfile" ]; then
        log_info "Restoring Dockerfile..."
        cp "${backup_path}/Dockerfile" "${PROJECT_ROOT}/Dockerfile"
    fi

    # Restore data volume
    if [ -f "${backup_path}/n8n_data.tar.gz" ]; then
        log_info "Restoring n8n data volume... (this may take a while)"

        # Remove existing volume data
        docker volume rm n8n_data 2>/dev/null || true
        docker volume create n8n_data

        # Restore from backup
        docker run --rm \
            -v n8n_data:/data \
            -v "${backup_path}:/backup" \
            alpine \
            sh -c "tar xzf /backup/n8n_data.tar.gz -C /data"

        log_info "Data volume restored"
    else
        log_warn "n8n_data.tar.gz not found in backup"
    fi

    # Start n8n
    log_info "Starting n8n..."
    $COMPOSE_CMD up -d

    # Wait for startup
    log_info "Waiting for n8n to start..."
    sleep 15

    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
        log_info "Restore completed successfully!"
        log_info "n8n is now running"

        # Display access information
        local host_ip=$(grep "^HOST_IP=" "${PROJECT_ROOT}/.env" 2>/dev/null | cut -d'=' -f2 || echo "localhost")
        echo ""
        log_info "Access n8n at:"
        log_info "  - http://localhost:5678"
        log_info "  - http://${host_ip}:5678"
    else
        log_error "n8n container failed to start"
        log_error "Check logs with: $COMPOSE_CMD logs"
        exit 1
    fi
}

# Interactive restore
interactive_restore() {
    # Get list of backups
    local backup_list=$(list_backups)
    local -a backup_array=($backup_list)
    local backup_count=${#backup_array[@]}

    if [ $backup_count -eq 0 ]; then
        exit 1
    fi

    echo ""
    echo "Select backup to restore (1-$backup_count) or 'q' to quit:"
    read -r selection

    if [ "$selection" = "q" ]; then
        log_info "Restore cancelled"
        exit 0
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "$backup_count" ]; then
        log_error "Invalid selection"
        exit 1
    fi

    local selected_backup="${backup_array[$((selection-1))]}"
    restore_backup "$selected_backup"
}

# Display help
show_help() {
    cat <<EOF
n8n Restore Script

Usage: $0 [OPTIONS] [BACKUP_PATH]

Options:
  (no option)         Interactive restore - select from available backups
  /path/to/backup     Restore from specific backup path
  --latest            Restore from the most recent backup
  --help              Show this help message

Examples:
  $0                                          # Interactive mode
  $0 /path/to/backups/backup_20250101_120000 # Restore specific backup
  $0 --latest                                 # Restore latest backup

Backup Location: $BACKUP_DIR
EOF
}

# Main function
main() {
    case "${1:-interactive}" in
        --help)
            show_help
            exit 0
            ;;
        --latest)
            # Find most recent backup
            local latest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" 2>/dev/null | sort -r | head -1)

            if [ -z "$latest_backup" ]; then
                log_error "No backups found"
                exit 1
            fi

            log_info "Latest backup: $(basename "$latest_backup")"
            restore_backup "$latest_backup"
            ;;
        interactive)
            interactive_restore
            ;;
        *)
            # Restore from specified path
            if [ -d "$1" ]; then
                restore_backup "$1"
            else
                log_error "Invalid backup path: $1"
                exit 1
            fi
            ;;
    esac
}

# Run main function
main "$@"
