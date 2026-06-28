#!/usr/bin/env bash
# Deploy the CloudKit SpeechRequest schema to the relay container.
#
# Prereq (one-time): create a CloudKit *management* token in the CloudKit Console
#   (https://icloud.developer.apple.com → container iCloud.com.malpern.voxclaw →
#    Settings → Tokens), then save it:
#       xcrun cktool save-token --type management
#
# Usage: Scripts/cloudkit/deploy-schema.sh [development|production]   (default: production)
set -euo pipefail

TEAM_ID="${APPLE_TEAM_ID:-X2RKZ5TG99}"
CONTAINER="iCloud.com.malpern.voxclaw"
ENV="${1:-production}"
SCHEMA="$(cd "$(dirname "$0")" && pwd)/SpeechRequest.ckdb"

echo "Validating $SCHEMA against $CONTAINER ($ENV)…"
xcrun cktool validate-schema \
  --team-id "$TEAM_ID" --container-id "$CONTAINER" --environment "$ENV" \
  --file "$SCHEMA"

echo "Importing schema to $ENV…"
xcrun cktool import-schema \
  --team-id "$TEAM_ID" --container-id "$CONTAINER" --environment "$ENV" \
  --validate --file "$SCHEMA"

echo "Done. SpeechRequest record type deployed to $ENV."
