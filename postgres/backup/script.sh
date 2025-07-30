#!/bin/bash

set -euo pipefail

# Configuration variables
NAMESPACE="${NAMESPACE:-default}"
SERVICE_NAME="${SERVICE_NAME:-postgres}"
SERVICE_PORT="${SERVICE_PORT:-5432}"
LOCAL_PORT="${LOCAL_PORT:-5432}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
GPG_PASSWORD="${GPG_PASSWORD:-}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Check dependencies
check_dependencies() {
    local deps=("kubectl" "pg_dumpall" "gpg")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "$dep is required but not installed"
            exit 1
        fi
    done
}

# Check if GPG password is set or prompt for it
check_gpg_config() {
    if [[ -z "$GPG_PASSWORD" ]]; then
        echo -n "Enter GPG password for encryption: "
        read -s GPG_PASSWORD
        echo
        
        if [[ -z "$GPG_PASSWORD" ]]; then
            error "GPG password cannot be empty"
            exit 1
        fi
        
        # Confirm password
        echo -n "Confirm GPG password: "
        read -s GPG_PASSWORD_CONFIRM
        echo
        
        if [[ "$GPG_PASSWORD" != "$GPG_PASSWORD_CONFIRM" ]]; then
            error "Passwords do not match"
            exit 1
        fi
    fi
    
    log "GPG password configured"
}

# Create backup directory
create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log "Backup directory: $BACKUP_DIR"
}

# Start port forwarding
start_port_forward() {
    log "Starting port forwarding from localhost:$LOCAL_PORT to $SERVICE_NAME:$SERVICE_PORT in namespace $NAMESPACE"
    kubectl port-forward -n "$NAMESPACE" "service/$SERVICE_NAME" "$LOCAL_PORT:$SERVICE_PORT" &
    KUBECTL_PID=$!
    
    # Wait for port forwarding to be ready
    sleep 5
    
    if ! kill -0 $KUBECTL_PID 2>/dev/null; then
        error "Port forwarding failed to start"
        exit 1
    fi
    
    log "Port forwarding established (PID: $KUBECTL_PID)"
}

# Stop port forwarding
stop_port_forward() {
    if [[ -n "${KUBECTL_PID:-}" ]]; then
        log "Stopping port forwarding (PID: $KUBECTL_PID)"
        kill $KUBECTL_PID 2>/dev/null || true
        wait $KUBECTL_PID 2>/dev/null || true
    fi
}

# Cleanup on script exit
cleanup() {
    stop_port_forward
    # Clear GPG password from memory
    unset GPG_PASSWORD
    unset GPG_PASSWORD_CONFIRM
}

check_pg_user() {
    if [[ -z "$POSTGRES_USER" ]]; then
        error "POSTGRES_USER is not set. Please set it in the environment or script."
        exit 1
    fi

    # Prompt for PostgreSQL user if not set
    if [[ -z "$POSTGRES_PASSWORD" ]]; then
        echo -n "Enter PostgreSQL password for user '$POSTGRES_USER': "
        read -s POSTGRES_PASSWORD
        echo
        
        if [[ -z "$POSTGRES_PASSWORD" ]]; then
            error "Password cannot be empty"
            exit 1
        fi
        
        echo -n "Confirm PostgreSQL password: "
        read -s POSTGRES_PASSWORD_CONFIRM
        echo
        
        if [[ "$POSTGRES_PASSWORD" != "$POSTGRES_PASSWORD_CONFIRM" ]]; then
            error "Passwords do not match"
            exit 1
        fi
    fi
}

# Run pg_dumpall
run_backup() {
    local timestamp=$(date +'%Y%m%d_%H%M%S')
    local backup_file="$BACKUP_DIR/postgres_backup_$timestamp.sql"
    
    
    # Set PGPASSWORD if provided
    if [[ -n "$POSTGRES_PASSWORD" ]]; then
        export PGPASSWORD="$POSTGRES_PASSWORD"
    fi
    
    if pg_dumpall -h localhost -p "$LOCAL_PORT" -U "$POSTGRES_USER" > "$backup_file"; then
        echo "$backup_file"
    else
        error "Backup failed"
        rm -f "$backup_file"
        exit 1
    fi
}

# GPG encrypt the backup with password (symmetric encryption)
encrypt_backup() {
    local sql_file="$1"
    local gpg_file="${sql_file}.gpg"
    
    
    # Use symmetric encryption with password
    if echo "$GPG_PASSWORD" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 --compress-algo 2 --output "$gpg_file" "$sql_file" > $HOME/stuff/k0s/postgres/backup/p.log; then
        echo "$gpg_file"
    else
        error "Encryption failed"
        exit 1
    fi
}

# Clean old backups (keep last 5)
cleanup_old_backups() {
    log "Cleaning up old backups (keeping last 5)"
    
    # Clean .sql files
    local sql_files=($(ls -t "$BACKUP_DIR"/postgres_backup_*.sql 2>/dev/null | tail -n +6))
    for file in "${sql_files[@]}"; do
        log "Removing old backup: $file"
        rm -f "$file"
    done
    
    # Clean .gpg files
    local gpg_files=($(ls -t "$BACKUP_DIR"/postgres_backup_*.sql.gpg 2>/dev/null | tail -n +6))
    for file in "${gpg_files[@]}"; do
        log "Removing old encrypted backup: $file"
        rm -f "$file"
    done
}

# Main function
main() {
    log "Starting PostgreSQL backup process"
    
    check_dependencies
    check_gpg_config
    check_pg_user
    create_backup_dir
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    start_port_forward
    
    log "Creating database backup"
    local sql_file=$(run_backup)
    log "Backup completed successfully - saved to $sql_file"

    log "Encrypting backup with password"
    local gpg_file=$(encrypt_backup "$sql_file")
    log "Encryption completed successfully - saved to $gpg_file"

    
    cleanup_old_backups
    
    log "Backup process completed successfully"
    log "SQL backup: $sql_file"
    log "Encrypted backup: $gpg_file"
}

# Run main function
main "$@"

# To Decrypt the backup, you can use:
# gpg --decrypt file.sql.gpg > out.sql

