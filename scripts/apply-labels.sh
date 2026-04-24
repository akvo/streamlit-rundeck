#!/bin/bash

# Retroactive Label Application Script
# Reads all deployments from the database and applies cost-tracking labels
# to their Cloud Run services. Intended as a one-time catch-up operation
# for services deployed before labels were introduced.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] APPLY-LABELS: $*"
}

error() {
    log "ERROR: $*"
    exit 1
}

: "${GCP_PROJECT_ID:?GCP_PROJECT_ID is required}"
: "${DEFAULT_REGION:?DEFAULT_REGION is required}"

sanitize_label() {
    echo "$1" | tr '[:upper:]' '[:lower:]' \
        | sed -E 's|^https?://github\.com/||; s|\.git$||' \
        | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+|-+$//g' \
        | cut -c1-63
}

source "$SCRIPT_DIR/db-connection.sh"

export PGPASSWORD="$DB_PASS"

SQL="SELECT app_name, github_url, target_branch, region FROM deployments ORDER BY app_name;"
ROWS=$(echo "$SQL" | psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -F "|" 2>/dev/null)

if [[ -z "$ROWS" ]]; then
    error "No deployments found in database"
fi

SUCCESS=()
FAILED=()

while IFS="|" read -r APP_NAME GITHUB_URL TARGET_BRANCH REGION; do
    [[ -z "$APP_NAME" ]] && continue

    if [[ "$APP_NAME" == *-prod ]]; then
        ENVIRONMENT="prod"
    else
        ENVIRONMENT="test"
    fi

    LABEL_APP=$(sanitize_label "$APP_NAME")
    LABEL_REPO=$(sanitize_label "$GITHUB_URL")
    LABEL_BRANCH=$(sanitize_label "$TARGET_BRANCH")
    LABELS="app=${LABEL_APP},environment=${ENVIRONMENT},managed-by=streamlit-rundeck,repo=${LABEL_REPO},branch=${LABEL_BRANCH}"

    log "Applying labels to $APP_NAME: $LABELS"

    if gcloud run services update "$APP_NAME" \
        --region="$REGION" \
        --project="$GCP_PROJECT_ID" \
        --update-labels="$LABELS" \
        --quiet 2>&1; then
        SUCCESS+=("$APP_NAME")
    else
        log "Failed to label $APP_NAME"
        FAILED+=("$APP_NAME")
    fi
done <<< "$ROWS"

log "Summary: ${#SUCCESS[@]} succeeded, ${#FAILED[@]} failed"
[[ ${#SUCCESS[@]} -gt 0 ]] && log "Succeeded: ${SUCCESS[*]}"
[[ ${#FAILED[@]} -gt 0 ]] && log "Failed: ${FAILED[*]}"

exit $([[ ${#FAILED[@]} -eq 0 ]] && echo 0 || echo 1)
