#!/usr/bin/env bash

#######################################
# n8n Deployment Script
# Idempotent deployment with rollback support
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
COMPOSE_FILE="${PROJECT_ROOT}/docker-compose.yml"
ENV_FILE="${PROJECT_ROOT}/.env"
BACKUP_DIR="${PROJECT_ROOT}/backups"
DEPLOY_LOG="${PROJECT_ROOT}/deploy.log"
HEALTHCHECK_TIMEOUT=60
HEALTHCHECK_INTERVAL=5

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$DEPLOY_LOG"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$DEPLOY_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$DEPLOY_LOG"
}

# Timestamp for deployment
DEPLOY_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

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
    log_error "Docker Compose is not installed"
    exit 1
fi

# Pre-flight checks
preflight_checks() {
    log_info "Running pre-flight checks..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    # Check if Docker Compose is installed
    if [ -z "$COMPOSE_CMD" ]; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    # Check if docker-compose.yml exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "docker-compose.yml not found at $COMPOSE_FILE"
        exit 1
    fi

    # Check if .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        log_warn ".env file not found. Creating from .env.example..."
        if [ -f "${PROJECT_ROOT}/.env.example" ]; then
            cp "${PROJECT_ROOT}/.env.example" "$ENV_FILE"
            log_warn "Please update $ENV_FILE with your configuration"
            exit 1
        else
            log_error ".env.example not found"
            exit 1
        fi
    fi

    # Validate .env file has required variables
    local required_vars=("HOST_IP" "N8N_BASIC_AUTH_USER" "N8N_BASIC_AUTH_PASSWORD")
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$ENV_FILE"; then
            log_error "Required variable $var not found in .env file"
            exit 1
        fi
    done

    # Check for default passwords
    if grep -q "N8N_BASIC_AUTH_PASSWORD=changeme123" "$ENV_FILE"; then
        log_error "Default password detected in .env file. Please change it before deploying."
        exit 1
    fi

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    log_info "Pre-flight checks passed"
}

# Backup current deployment
backup_deployment() {
    log_info "Creating backup..."

    local backup_path="${BACKUP_DIR}/backup_${DEPLOY_TIMESTAMP}"
    mkdir -p "$backup_path"

    # Backup .env file
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "${backup_path}/.env"
    fi

    # Backup docker-compose.yml
    if [ -f "$COMPOSE_FILE" ]; then
        cp "$COMPOSE_FILE" "${backup_path}/docker-compose.yml"
    fi

    # Export n8n data volume if container is running
    if docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
        log_info "Exporting n8n data volume..."
        docker run --rm \
            -v n8n_data:/data \
            -v "${backup_path}:/backup" \
            alpine \
            tar czf /backup/n8n_data.tar.gz -C /data . 2>/dev/null || true
    fi

    # Save current container image ID for rollback
    if docker ps -a --format '{{.Names}}' | grep -q "^n8n$"; then
        docker inspect n8n --format='{{.Image}}' > "${backup_path}/image_id.txt" 2>/dev/null || true
    fi

    log_info "Backup created at $backup_path"
    echo "$backup_path" > "${PROJECT_ROOT}/.last_backup"
}

# Deploy n8n
deploy() {
    log_info "Starting deployment..."

    cd "$PROJECT_ROOT"

    # Pull latest images
    log_info "Pulling latest Docker images..."
    $COMPOSE_CMD pull

    # Stop existing containers gracefully
    if docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
        log_info "Stopping existing n8n container..."
        $COMPOSE_CMD down --timeout 30
    fi

    # Start containers
    log_info "Starting n8n containers..."
    $COMPOSE_CMD up -d

    log_info "Deployment completed"
}

# Health check
health_check() {
    log_info "Running health checks..."

    local elapsed=0
    local healthy=false

    while [ $elapsed -lt $HEALTHCHECK_TIMEOUT ]; do
        # Check if container is running
        if ! docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
            log_error "n8n container is not running"
            return 1
        fi

        # Check container health status
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' n8n 2>/dev/null || echo "unknown")

        if [ "$health_status" = "healthy" ]; then
            healthy=true
            break
        fi

        log_info "Waiting for n8n to become healthy... ($elapsed/${HEALTHCHECK_TIMEOUT}s)"
        sleep $HEALTHCHECK_INTERVAL
        elapsed=$((elapsed + HEALTHCHECK_INTERVAL))
    done

    if [ "$healthy" = false ]; then
        log_error "Health check failed after ${HEALTHCHECK_TIMEOUT}s"
        log_error "Container logs:"
        docker-compose logs --tail=50 n8n
        return 1
    fi

    log_info "Health check passed"
    return 0
}

# Rollback to previous deployment
rollback() {
    log_warn "Rolling back deployment..."

    if [ ! -f "${PROJECT_ROOT}/.last_backup" ]; then
        log_error "No backup found for rollback"
        exit 1
    fi

    local backup_path=$(cat "${PROJECT_ROOT}/.last_backup")

    if [ ! -d "$backup_path" ]; then
        log_error "Backup directory not found: $backup_path"
        exit 1
    fi

    cd "$PROJECT_ROOT"

    # Stop current deployment
    log_info "Stopping current deployment..."
    $COMPOSE_CMD down --timeout 30

    # Restore configuration files
    if [ -f "${backup_path}/.env" ]; then
        cp "${backup_path}/.env" "$ENV_FILE"
        log_info "Restored .env file"
    fi

    if [ -f "${backup_path}/docker-compose.yml" ]; then
        cp "${backup_path}/docker-compose.yml" "$COMPOSE_FILE"
        log_info "Restored docker-compose.yml"
    fi

    # Restore data volume if backup exists
    if [ -f "${backup_path}/n8n_data.tar.gz" ]; then
        log_info "Restoring n8n data volume..."
        docker run --rm \
            -v n8n_data:/data \
            -v "${backup_path}:/backup" \
            alpine \
            sh -c "rm -rf /data/* && tar xzf /backup/n8n_data.tar.gz -C /data"
        log_info "Data volume restored"
    fi

    # Start containers with restored configuration
    log_info "Starting containers with restored configuration..."
    $COMPOSE_CMD up -d

    # Wait for health check
    sleep 10
    if health_check; then
        log_info "Rollback completed successfully"
    else
        log_error "Rollback health check failed"
        exit 1
    fi
}

# Cleanup old backups (keep last 10)
cleanup_backups() {
    log_info "Cleaning up old backups..."

    local backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" | wc -l)

    if [ "$backup_count" -gt 10 ]; then
        find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" | sort | head -n -10 | xargs rm -rf
        log_info "Cleaned up old backups (kept last 10)"
    fi
}

# Display deployment information
display_info() {
    log_info "Deployment Information:"
    log_info "======================="

    # Get host IP from .env
    local host_ip=$(grep "^HOST_IP=" "$ENV_FILE" | cut -d'=' -f2)

    echo ""
    log_info "n8n is accessible at:"
    log_info "  - http://localhost:5678"
    log_info "  - http://${host_ip}:5678"
    echo ""
    log_info "Container status:"
    $COMPOSE_CMD ps
    echo ""
    log_info "To view logs: $COMPOSE_CMD logs -f"
    log_info "To stop: $COMPOSE_CMD down"
    log_info "To rollback: $0 --rollback"
}

# Main function
main() {
    log_info "n8n Deployment Script - Started at $(date)"
    log_info "========================================"

    # Parse arguments
    case "${1:-deploy}" in
        --rollback)
            rollback
            exit 0
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (no option)   Deploy n8n (default)"
            echo "  --rollback    Rollback to previous deployment"
            echo "  --help        Show this help message"
            exit 0
            ;;
        deploy|*)
            # Run deployment
            preflight_checks
            backup_deployment

            # Deploy and handle failures
            if ! deploy; then
                log_error "Deployment failed"
                rollback
                exit 1
            fi

            # Health check and rollback if failed
            if ! health_check; then
                log_error "Health check failed, rolling back..."
                rollback
                exit 1
            fi

            cleanup_backups
            display_info

            log_info "Deployment completed successfully at $(date)"
            ;;
    esac
}

# Run main function
main "$@"
