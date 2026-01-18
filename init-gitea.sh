#!/usr/bin/env bash
set -e

CONTAINER_NAME=gitea
CONFIG_PATH=/data/gitea/conf/app.ini
GITEA_URL=http://localhost:8888
ADMIN_USER=mau
ADMIN_PASSWORD=password
ADMIN_EMAIL=admin@local
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

# Check if Gitea is already installed by checking the install page
echo "Checking if Gitea is installed..."
INSTALL_PAGE=$(curl -s "${GITEA_URL}/" | grep -q "Installation" && echo "yes" || echo "no")

if [ "$INSTALL_PAGE" = "yes" ]; then
  echo "Gitea needs to be installed. Attempting automated installation..."
  
  # Save install page HTML for parsing (install page is at root, not /install)
  TEMP_HTML=$(mktemp)
  COOKIE_JAR=$(mktemp)
  curl -s -c "$COOKIE_JAR" -L "${GITEA_URL}/" > "$TEMP_HTML"
  
  # Try to extract CSRF token using awk (more reliable than sed for complex patterns)
  CSRF_TOKEN=$(awk 'BEGIN{RS="<input"; FS="\""} /name="_csrf"/{for(i=1;i<=NF;i++){if($(i-1)~/value=/){print $i; exit}}}' "$TEMP_HTML" | head -1)
  
  # Alternative extraction method
  if [ -z "$CSRF_TOKEN" ] || [ "$CSRF_TOKEN" = "" ]; then
    CSRF_TOKEN=$(grep -o 'name="_csrf"[^>]*' "$TEMP_HTML" | sed 's/.*value="\([^"]*\)".*/\1/' | head -1)
  fi
  
  # Another alternative: look for hidden input with csrf
  if [ -z "$CSRF_TOKEN" ] || [ "$CSRF_TOKEN" = "" ]; then
    CSRF_LINE=$(grep -i 'csrf' "$TEMP_HTML" | grep -i 'input' | head -1)
    CSRF_TOKEN=$(echo "$CSRF_LINE" | sed 's/.*value="\([^"]*\)".*/\1/' | sed 's/.*value='\''\([^'\'']*\)'\''.*/\1/')
  fi
  
  rm -f "$TEMP_HTML"
  
  if [ -z "$CSRF_TOKEN" ] || [ "$CSRF_TOKEN" = "" ]; then
    echo "Could not extract CSRF token. Trying installation without it..."
    CSRF_PARAM=""
  else
    echo "Found CSRF token"
    CSRF_PARAM="_csrf=${CSRF_TOKEN}&"
  fi
  
  # Prepare installation data (use lowercase sqlite3 for database type)
  INSTALL_DATA="${CSRF_PARAM}db_type=sqlite3&db_path=%2Fdata%2Fgitea.db&app_name=Gitea&repo_root_path=%2Fdata%2Fgit%2Frepositories&lfs_root_path=%2Fdata%2Fgit%2Flfs&run_user=git&domain=localhost&ssh_port=2222&http_port=8888&app_url=http%3A%2F%2Flocalhost%3A8888%2F&log_root_path=%2Fdata%2Fgitea%2Flog&smtp_addr=&smtp_port=&smtp_from=&smtp_user=&smtp_passwd=&enable_federated_avatar=on&enable_open_id_sign_in=on&enable_open_id_sign_up=on&default_allow_create_organization=on&default_enable_timetracking=on&no_reply_address=noreply.localhost&admin_name=${ADMIN_USER}&admin_passwd=${ADMIN_PASSWORD}&admin_confirm_passwd=${ADMIN_PASSWORD}&admin_email=${ADMIN_EMAIL}"
  
  echo "Submitting installation form..."
  INSTALL_RESPONSE=$(curl -s -L -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST "${GITEA_URL}/" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Referer: ${GITEA_URL}/" \
    -d "$INSTALL_DATA" \
    -w "\n%{http_code}" -o /tmp/gitea_install_response.html)
  
  HTTP_CODE=$(echo "$INSTALL_RESPONSE" | tail -1)
  rm -f "$COOKIE_JAR"
  
  echo "Installation HTTP response code: $HTTP_CODE"
  
  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "303" ]; then
    echo "Installation submitted successfully. Waiting for Gitea to process..."
    sleep 10
    
    # Wait for Gitea to be ready
    wait_for_gitea
    
    # Verify installation completed
    INSTALL_CHECK=$(curl -s "${GITEA_URL}/" | grep -q "Installation" && echo "yes" || echo "no")
    if [ "$INSTALL_CHECK" = "yes" ]; then
      echo "Warning: Installation page still present. Installation may need to be completed manually."
      echo "Please visit ${GITEA_URL}/ to complete setup, then run this script again."
      exit 1
    else
      echo "Installation completed successfully."
    fi
  else
    echo "Installation submission failed with HTTP code: $HTTP_CODE"
    echo "Response saved to /tmp/gitea_install_response.html"
    echo "You may need to complete installation manually at ${GITEA_URL}/"
    exit 1
  fi
else
  echo "Gitea is already installed."
fi

# Check if admin user exists (wait a bit for installation to complete)
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

# Check if repository exists, create if not
echo "Checking if repository '${REPO_NAME}' exists..."
REPO_EXISTS=$(curl -s -u "${ADMIN_USER}:${ADMIN_PASSWORD}" "${GITEA_URL}/api/v1/repos/${ADMIN_USER}/${REPO_NAME}" 2>/dev/null | grep -q '"id"' && echo "yes" || echo "no")

if [ "$REPO_EXISTS" = "yes" ]; then
  echo "✓ Repository '${REPO_NAME}' already exists"
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
echo "Gitea initialized successfully!"
HEALTH_STATUS=$(curl -s ${GITEA_URL}/api/healthz 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "  - Health: ${HEALTH_STATUS:-pass}"
echo "  - Admin user: ${ADMIN_USER}"
echo "  - Repository: ${ADMIN_USER}/${REPO_NAME}"
echo "  - URL: ${GITEA_URL}"
