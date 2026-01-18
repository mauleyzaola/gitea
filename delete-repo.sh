#!/usr/bin/env bash
set -e

CONTAINER_NAME=gitea
GITEA_URL=http://localhost:8888

# Get repository name from parameter (required)
if [ -z "${1}" ]; then
  echo "Error: Repository name is required"
  echo "Usage: USERNAME=username PASSWORD=password NAME=reponame make delete-repo"
  exit 1
fi

REPO_NAME="${1}"

# Read USERNAME and PASSWORD from environment variables (required)
if [ -z "$USERNAME" ]; then
  echo "Error: USERNAME environment variable is required"
  echo "Usage: USERNAME=username PASSWORD=password NAME=reponame make delete-repo"
  exit 1
fi

if [ -z "$PASSWORD" ]; then
  echo "Error: PASSWORD environment variable is required"
  echo "Usage: USERNAME=username PASSWORD=password NAME=reponame make delete-repo"
  exit 1
fi

ADMIN_USER="$USERNAME"
ADMIN_PASSWORD="$PASSWORD"

# Function to wait for Gitea to be ready
wait_for_gitea() {
  echo "Waiting for Gitea to be ready..."
  local max_attempts=30
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    if curl -s -f "${GITEA_URL}/api/healthz" >/dev/null 2>&1; then
      echo "Gitea is ready!"
      return 0
    fi
    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts: Gitea not ready yet, waiting..."
    sleep 2
  done
  
  echo "Error: Gitea did not become ready in time"
  return 1
}

# Ensure Gitea container is running
echo "Ensuring Gitea container is running..."
if ! docker ps | grep -q "$CONTAINER_NAME"; then
  echo "Starting Gitea container..."
  docker start "$CONTAINER_NAME" || docker compose up -d
fi

# Wait for Gitea to be ready
wait_for_gitea

# Check if Gitea is installed
echo "Checking if Gitea is installed..."
INSTALL_PAGE=$(curl -s "${GITEA_URL}/" | grep -q "Installation" && echo "yes" || echo "no")

if [ "$INSTALL_PAGE" = "yes" ]; then
  echo "Error: Gitea is not installed yet. Please run 'make init-gitea' first."
  exit 1
fi

# Check if admin user exists
echo "Checking if admin user exists..."
USER_RESPONSE=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" "${GITEA_URL}/api/v1/user" 2>/dev/null)
USER_EXISTS=$(echo "$USER_RESPONSE" | grep -q '"id"' && echo "yes" || echo "no")

if [ "$USER_EXISTS" != "yes" ]; then
  echo "Error: Admin user does not exist. Please run 'make create-user' first."
  exit 1
fi

# Check if repository exists
echo "Checking if repository '${REPO_NAME}' exists..."
REPO_EXISTS=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" "${GITEA_URL}/api/v1/repos/${ADMIN_USER}/${REPO_NAME}" 2>/dev/null | grep -q '"id"' && echo "yes" || echo "no")

if [ "$REPO_EXISTS" != "yes" ]; then
  echo "✗ Repository '${REPO_NAME}' does not exist"
  exit 1
fi

# Delete the repository
echo "Deleting repository '${REPO_NAME}'..."
DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE -u "${ADMIN_USER}:${ADMIN_PASSWORD}" \
  "${GITEA_URL}/api/v1/repos/${ADMIN_USER}/${REPO_NAME}" 2>/dev/null)

HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$DELETE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
  echo "✓ Repository '${REPO_NAME}' deleted successfully"
else
  echo "✗ Failed to delete repository"
  echo "HTTP Code: $HTTP_CODE"
  echo "Response: $RESPONSE_BODY"
  exit 1
fi

echo ""
echo "Repository deletion complete!"
echo "  - Deleted repository: ${ADMIN_USER}/${REPO_NAME}"
