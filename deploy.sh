#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
APP_NAME="speech-to-text-demo"
IMAGE_TAG="latest"
LOCAL_TAR_FILE="${APP_NAME}.tar"
LOCAL_GZ_FILE="${APP_NAME}.tar.gz"
ENV_FILE=".env"


PEM_KEY_PATH="~/Downloads/kashissh.pem"

REMOTE_USER="ec2-user"
REMOTE_HOST="ec2-51-20-157-54.eu-north-1.compute.amazonaws.com"
REMOTE_DEST_DIR="/home/ec2-user"

# --- Logging Function ---
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] - $1"
}

# --- Main Script ---
log "Starting deployment script for ${APP_NAME}..."

if [ ! -f "${ENV_FILE}" ]; then
  log "ERROR: Environment file '${ENV_FILE}' not found."
  exit 1
fi

# 1. Build Docker Image
log "Building Docker image: ${APP_NAME}:${IMAGE_TAG} from current directory..."
if docker build -t "${APP_NAME}:${IMAGE_TAG}" .; then
  log "Docker image '${APP_NAME}:${IMAGE_TAG}' built successfully."
else
  log "ERROR: Docker image build FAILED."
  exit 1
fi

# 2. Save Docker Image to .tar
log "Saving Docker image '${APP_NAME}:${IMAGE_TAG}' to '${LOCAL_TAR_FILE}'..."
if docker save -o "${LOCAL_TAR_FILE}" "${APP_NAME}:${IMAGE_TAG}"; then
  log "Docker image saved to '${LOCAL_TAR_FILE}' successfully."
else
  log "ERROR: Docker image save FAILED."
  rm -f "${LOCAL_TAR_FILE}"
  exit 1
fi

# 3. Compress .tar to .tar.gz
log "Compressing '${LOCAL_TAR_FILE}' to '${LOCAL_GZ_FILE}'..."
if tar -czf "${LOCAL_GZ_FILE}" "${LOCAL_TAR_FILE}"; then
  log "File compressed to '${LOCAL_GZ_FILE}' successfully."
else
  log "ERROR: tar compression FAILED."
  rm -f "${LOCAL_GZ_FILE}"
  exit 1
fi

# 4. SCP to Remote Server
EXPANDED_PEM_KEY_PATH=$(eval echo "${PEM_KEY_PATH}")
log "Copying '${LOCAL_GZ_FILE}' to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DEST_DIR}/ ..."
if rsync -avz --progress -e "ssh -i '${EXPANDED_PEM_KEY_PATH}'" "./${LOCAL_GZ_FILE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DEST_DIR}/"; then
  log "File '${LOCAL_GZ_FILE}' copied to remote server successfully."
else
  log "ERROR: SCP file transfer FAILED."
  exit 1
fi

# 5. SSH into Remote Server and Deploy Docker Container
log "Connecting to remote server ${REMOTE_HOST} to deploy container..."

if ssh -i "${EXPANDED_PEM_KEY_PATH}" "${REMOTE_USER}@${REMOTE_HOST}" "
  set -e # Exit on error for remote commands

  echo '[REMOTE] Navigating to ${REMOTE_DEST_DIR}'
  cd \"${REMOTE_DEST_DIR}\"

  echo '[REMOTE] Extracting ${LOCAL_GZ_FILE}...'
  tar -xzvf \"${LOCAL_GZ_FILE}\"

  echo '[REMOTE] Loading Docker image from ${LOCAL_TAR_FILE}...'
  docker load -i \"${LOCAL_TAR_FILE}\"

  echo '[REMOTE] Stopping and removing existing container named ${APP_NAME} (if any)...'
  docker stop \"${APP_NAME}\" || echo '[REMOTE] Container ${APP_NAME} not running or does not exist.'
  docker rm \"${APP_NAME}\" || echo '[REMOTE] Container ${APP_NAME} not found or already removed.'

  echo '[REMOTE] Running new Docker container ${APP_NAME}:${IMAGE_TAG}...'
  # Ensure network 'backend' exists
  docker run \
    --restart always \
    -p 3001:3000 \
    -d \
    --name \"${APP_NAME}\" \
    --network projects_backend \
    \"${APP_NAME}:${IMAGE_TAG}\"

  echo '[REMOTE] Docker container started successfully.'

  echo '[REMOTE] Cleaning up remote files: ${LOCAL_GZ_FILE} and ${LOCAL_TAR_FILE}...'
  rm -f \"${LOCAL_GZ_FILE}\" \"${LOCAL_TAR_FILE}\"
  echo '[REMOTE] Remote cleanup complete.'
  echo '[REMOTE] Deployment steps on remote server finished.'
"; then
  log "Remote deployment steps completed successfully."
else
  log "ERROR: Remote deployment steps FAILED."
  # Note: Local cleanup will still run if this fails, which might be desired.
  # If you want to exit immediately without local cleanup on remote failure, add 'exit 1' here.
  exit 1 # Exit if SSH commands fail
fi

# 6. Optional: Clean up local files
log "Cleaning up local files: '${LOCAL_TAR_FILE}' and '${LOCAL_GZ_FILE}'..."
rm -f "${LOCAL_TAR_FILE}" "${LOCAL_GZ_FILE}"
log "Local cleanup complete."

log "Deployment script for ${APP_NAME} finished successfully!"
exit 0