#!/usr/bin/env bash
set -e

CONTAINER_NAME=gitea
GITEA_URL=http://localhost:8888

# Read USERNAME and PASSWORD from environment variables (required)
if [ -z "$USERNAME" ]; then
  echo "Error: USERNAME environment variable is required"
  echo "Usage: USERNAME=username PASSWORD=password make create-token"
  exit 1
fi

if [ -z "$PASSWORD" ]; then
  echo "Error: PASSWORD environment variable is required"
  echo "Usage: USERNAME=username PASSWORD=password make create-token"
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
echo "Checking if user exists..."
USER_RESPONSE=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" "${GITEA_URL}/api/v1/user" 2>/dev/null)
USER_EXISTS=$(echo "$USER_RESPONSE" | grep -q '"id"' && echo "yes" || echo "no")

if [ "$USER_EXISTS" != "yes" ]; then
  echo "Error: User does not exist. Please run 'make create-user' first."
  exit 1
fi

# Generate a token name with timestamp
TOKEN_NAME="token-$(date +%Y%m%d-%H%M%S)"

# Create access token that never expires (set expiration to year 2099)
echo "Creating access token '${TOKEN_NAME}'..."
TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -u "${ADMIN_USER}:${ADMIN_PASSWORD}" \
  -H "Content-Type: application/json" \
  "${GITEA_URL}/api/v1/users/${ADMIN_USER}/tokens" \
  -d "{\"name\":\"${TOKEN_NAME}\",\"scopes\":[\"write:repository\",\"read:repository\",\"write:user\",\"read:user\",\"write:organization\",\"read:organization\",\"write:issue\",\"read:issue\",\"write:notification\",\"read:notification\",\"write:package\",\"read:package\"],\"expires_at\":\"2099-12-31T23:59:59Z\"}" 2>/dev/null)

HTTP_CODE=$(echo "$TOKEN_RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$TOKEN_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
  # Extract token from response (Gitea API returns token in "sha1" field)
  TOKEN=$(echo "$RESPONSE_BODY" | grep -o '"sha1":"[^"]*"' | cut -d'"' -f4)
  
  if [ -z "$TOKEN" ]; then
    # Try alternative field names
    TOKEN=$(echo "$RESPONSE_BODY" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
  fi
  
  if [ -z "$TOKEN" ]; then
    # Try using jq if available, or extract any quoted value after "sha1"
    if command -v jq >/dev/null 2>&1; then
      TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.sha1 // .token // empty' 2>/dev/null)
    fi
  fi
  
  if [ -z "$TOKEN" ]; then
    echo "✗ Failed to extract token from response"
    echo "Response: $RESPONSE_BODY"
    exit 1
  fi
  
  echo ""
  echo "✓ Access token created successfully!"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Token Name: ${TOKEN_NAME}"
  echo "  Token: ${TOKEN}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "⚠️  IMPORTANT: Save this token now - it will not be shown again!"
  echo ""
  echo "You can use this token for API authentication:"
  echo "  curl -H \"Authorization: token ${TOKEN}\" ${GITEA_URL}/api/v1/user"
  echo ""
else
  echo "✗ Failed to create access token"
  echo "HTTP Code: $HTTP_CODE"
  echo "Response: $RESPONSE_BODY"
  exit 1
fi
