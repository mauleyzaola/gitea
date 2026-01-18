#!/usr/bin/env bash
set -e

CONTAINER_NAME=gitea
GITEA_URL=http://localhost:8888
ADMIN_USER=mau
ADMIN_PASSWORD=password
REPO_NAME=mau-local-repo

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

# Check if repository exists, create if not
echo "Checking if repository '${REPO_NAME}' exists..."
REPO_EXISTS=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" "${GITEA_URL}/api/v1/repos/${ADMIN_USER}/${REPO_NAME}" 2>/dev/null | grep -q '"id"' && echo "yes" || echo "no")

if [ "$REPO_EXISTS" = "yes" ]; then
  echo "✓ Repository '${REPO_NAME}' already exists"
  REPO_INFO=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" "${GITEA_URL}/api/v1/repos/${ADMIN_USER}/${REPO_NAME}" 2>/dev/null)
  echo "$REPO_INFO" | grep -E '"id"|"name"|"full_name"' | head -3 || true
else
  echo "Creating repository '${REPO_NAME}'..."
  REPO_RESPONSE=$(curl -s -X POST -u "${ADMIN_USER}:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    "${GITEA_URL}/api/v1/user/repos" \
    -d "{\"name\":\"${REPO_NAME}\",\"description\":\"Test repository\",\"private\":false,\"auto_init\":true}")
  
  if echo "$REPO_RESPONSE" | grep -q '"id"'; then
    echo "✓ Repository '${REPO_NAME}' created successfully"
    echo "$REPO_RESPONSE" | grep -E '"id"|"name"|"full_name"' | head -3 || true
  else
    echo "✗ Failed to create repository"
    echo "Response: $REPO_RESPONSE"
    exit 1
  fi
fi

echo ""
echo "Repository creation complete!"
echo "  - Repository: ${ADMIN_USER}/${REPO_NAME}"
echo "  - URL: ${GITEA_URL}/${ADMIN_USER}/${REPO_NAME}"
