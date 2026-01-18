#!/usr/bin/env bash
set -e

CONTAINER_NAME=gitea
CONFIG_PATH=/data/gitea/conf/app.ini
GITEA_URL=http://localhost:8888

# Read USERNAME and PASSWORD from environment variables (required)
if [ -z "$USERNAME" ]; then
  echo "Error: USERNAME environment variable is required"
  echo "Usage: USERNAME=username PASSWORD=password make create-user"
  exit 1
fi

if [ -z "$PASSWORD" ]; then
  echo "Error: PASSWORD environment variable is required"
  echo "Usage: USERNAME=username PASSWORD=password make create-user"
  exit 1
fi

ADMIN_USER="$USERNAME"
ADMIN_PASSWORD="$PASSWORD"
ADMIN_EMAIL=admin@local

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

# Wait a bit for Gitea to be fully ready
echo "Waiting for Gitea to be fully ready..."
sleep 3

echo "Checking if admin user exists..."
USER_RESPONSE=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" "${GITEA_URL}/api/v1/user" 2>/dev/null)
USER_EXISTS=$(echo "$USER_RESPONSE" | grep -q '"id"' && echo "yes" || echo "no")

if [ "$USER_EXISTS" = "yes" ]; then
  echo "✓ Admin user already exists"
  echo "$USER_RESPONSE" | grep -E '"id"|"login"|"email"' | head -3 || true
else
  echo "Admin user does not exist. Creating admin user..."
  
  # Find the config file path
  CONFIG_FILE=""
  if docker exec -u git "$CONTAINER_NAME" test -f "$CONFIG_PATH" 2>/dev/null; then
    CONFIG_FILE="$CONFIG_PATH"
  elif docker exec -u git "$CONTAINER_NAME" test -f /data/gitea/conf/app.ini 2>/dev/null; then
    CONFIG_FILE="/data/gitea/conf/app.ini"
  fi
  
  # Create admin user using Gitea CLI
  if [ -n "$CONFIG_FILE" ]; then
    echo "Using config file: $CONFIG_FILE"
    docker exec -u git "$CONTAINER_NAME" \
      gitea admin user create \
      --config "$CONFIG_FILE" \
      --username "$ADMIN_USER" \
      --password "$ADMIN_PASSWORD" \
      --email "$ADMIN_EMAIL" \
      --admin \
      --must-change-password=false || {
        echo "Warning: User creation with config failed, trying without config..."
        docker exec -u git "$CONTAINER_NAME" \
          gitea admin user create \
          --username "$ADMIN_USER" \
          --password "$ADMIN_PASSWORD" \
          --email "$ADMIN_EMAIL" \
          --admin \
          --must-change-password=false || true
      }
  else
    echo "No config file found, creating user without config..."
    docker exec -u git "$CONTAINER_NAME" \
      gitea admin user create \
      --username "$ADMIN_USER" \
      --password "$ADMIN_PASSWORD" \
      --email "$ADMIN_EMAIL" \
      --admin \
      --must-change-password=false || {
        echo "Error: Failed to create user via CLI"
        exit 1
      }
  fi
  
  # Verify user was created
  echo "Verifying user creation..."
  sleep 3
  USER_RESPONSE=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" "${GITEA_URL}/api/v1/user" 2>/dev/null)
  USER_EXISTS=$(echo "$USER_RESPONSE" | grep -q '"id"' && echo "yes" || echo "no")
  
  if [ "$USER_EXISTS" != "yes" ]; then
    echo "✗ Error: User creation failed - could not verify via API"
    echo "Response: $USER_RESPONSE"
    exit 1
  else
    echo "✓ Admin user created successfully"
    echo "$USER_RESPONSE" | grep -E '"id"|"login"|"email"' | head -3 || true
  fi
fi

echo ""
echo "User creation complete!"
echo "  - Admin user: ${ADMIN_USER}"
echo "  - Email: ${ADMIN_EMAIL}"
