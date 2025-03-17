#!/bin/bash
set -euo pipefail

envsubst < rclone.conf > rclone-out.conf

# Configuration
SOURCE_DIRS=(
    "/mnt/postgres-data"
    "/mnt/vaultwarden-data"
)
BUCKET_NAME=${BUCKET_NAME}
RCLONE_CONFIG="./rclone-out.conf"  
REMOTE_NAME="backup"  
REMOTE_PATH="${REMOTE_NAME}:${BUCKET_NAME}"  
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)

if [ -z "${BUCKET_NAME}" ]; then
  echo "Error: BUCKET_NAME is not set."
  exit 1
fi

# Check requirements
if ! command -v rclone &> /dev/null; then
  echo "Error: rclone is not installed. Please install rclone first."
  exit 1
fi

if [ ! -f "${RCLONE_CONFIG}" ]; then
  echo "Error: Rclone config file not found at ${RCLONE_CONFIG}"
  exit 1
fi

# Backup loop
for source_dir in "${SOURCE_DIRS[@]}"; do
  # Validate directory
  if [ ! -d "$source_dir" ]; then
    echo "Error: Directory '$source_dir' does not exist."
    exit 1
  fi

  # Create filename
  dir_name=$(basename "$source_dir")
  BACKUP_FILE="/tmp/${dir_name}-${BACKUP_DATE}.tar.gz"

  # Create archive
  echo "Backing up $source_dir..."
  tar -czf "${BACKUP_FILE}" -C "$(dirname "$source_dir")" "$dir_name"
  echo "Created: ${BACKUP_FILE}"

  # Upload with rclone config
  echo "Uploading to ${REMOTE_PATH}..."
  rclone --config "${RCLONE_CONFIG}" copy "${BACKUP_FILE}" "${REMOTE_PATH}/${BACKUP_FILE}" --progress

  # Cleanup
  rm "${BACKUP_FILE}"
  echo "Removed local file: ${BACKUP_FILE}"
  echo "--------------------------------------------------"
done

echo "All backups completed successfully"
