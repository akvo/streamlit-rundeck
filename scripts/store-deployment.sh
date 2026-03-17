#!/bin/bash

# Deployment Metadata Storage Script
# Stores deployment information in PostgreSQL database

set -euo pipefail

# Arguments
APP_NAME="$1"
GITHUB_URL="$2"
MAIN_FILE="$3"
TARGET_BRANCH="$4"
REGION="$5"
SERVICE_URL="$6"
SECRETS_CONTENT="${7:-}"
DOMAIN="${8:-}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STORE-DEPLOY: $*"
}

error() {
    log "ERROR: $*"
    exit 1
}

log "Storing deployment metadata for: $APP_NAME"

# Load database connection parameters
source "$(dirname "${BASH_SOURCE[0]}")/db-connection.sh"

# Get webhook ID if it exists
WEBHOOK_ID=""
if [[ -f "/tmp/webhook_id_$APP_NAME" ]]; then
    WEBHOOK_ID=$(cat "/tmp/webhook_id_$APP_NAME" || echo "")
fi

# Use a different approach: create a temporary file with the secrets content
# and use PostgreSQL's COPY or a properly escaped approach
SECRETS_FILE="/tmp/secrets_content_$$.txt"
echo -n "$SECRETS_CONTENT" > "$SECRETS_FILE"

# Create SQL file with dollar quoting for multiline content
SQL_FILE="/tmp/store_deployment_$$.sql"

# Use dollar-quoted strings to preserve multiline content
cat > "$SQL_FILE" << 'SQLEOF'
INSERT INTO deployments (
    app_name, 
    github_url, 
    main_file, 
    secrets_content, 
    region, 
    target_branch, 
    webhook_id,
    cloud_run_url,
    domain,
    created_at,
    updated_at
) VALUES (
SQLEOF

# Append the values with proper escaping
cat >> "$SQL_FILE" << EOF
    '$APP_NAME',
    '$GITHUB_URL',
    '$MAIN_FILE',
    \$SECRETS\$$(cat "$SECRETS_FILE")\$SECRETS\$,
    '$REGION',
    '$TARGET_BRANCH',
    '$WEBHOOK_ID',
    '$SERVICE_URL',
    '$DOMAIN',
    NOW(),
    NOW()
) ON CONFLICT (app_name) DO UPDATE SET
    github_url = EXCLUDED.github_url,
    main_file = EXCLUDED.main_file,
    secrets_content = EXCLUDED.secrets_content,
    region = EXCLUDED.region,
    target_branch = EXCLUDED.target_branch,
    webhook_id = EXCLUDED.webhook_id,
    cloud_run_url = EXCLUDED.cloud_run_url,
    domain = EXCLUDED.domain,
    updated_at = NOW();
EOF

# Execute SQL using psql with better error reporting
export PGPASSWORD="$DB_PASS"
if ! psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$SQL_FILE" 2>&1; then
    log "ERROR: SQL execution failed. SQL content:"
    cat "$SQL_FILE"
    rm -f "$SQL_FILE" "$SECRETS_FILE"
    error "Failed to store deployment metadata"
fi

# Clean up temporary files
rm -f "$SQL_FILE" "$SECRETS_FILE"

log "Deployment metadata stored successfully"

# Cleanup temporary files
rm -f "/tmp/webhook_id_$APP_NAME" || true