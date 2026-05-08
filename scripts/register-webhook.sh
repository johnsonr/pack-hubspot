#!/usr/bin/env bash
#
# pack-hubspot: one-time webhook registration for a HubSpot Public App.
#
# Run this ONCE when first deploying your assistant against a HubSpot
# Public App. End users never touch this — they just click Authorize in
# Settings → Connected Services. Webhook subscriptions are app-scoped,
# not user-scoped, so a single registration covers every user who later
# authorizes the same app.
#
# Idempotent: lists existing subscriptions first and only adds what's
# missing. Re-running after a public-URL change updates the target URL
# without duplicating the subscription.
#
# Usage:
#   scripts/register-webhook.sh <app-id> <developer-hapikey> <public-base-url>
#
# Example:
#   scripts/register-webhook.sh 678910 hapi-xxx-xxx https://my-host.example.com
#
# Where to find these values (DEVELOPER ACCOUNT, not your CRM portal):
#
#   <app-id>            Numeric id in the dev portal URL:
#                       /developer/<accountId>/applications/<appId>
#                       (the digits after /applications/).
#
#   <developer-hapikey> ⚙ Settings (top nav) → Integrations → API key
#                       (left sidebar) in the Developer Account → Show
#                       key. Super Admin required. NOTE: three distinct
#                       credentials with similar names —
#                         - Developer API Key (THIS ONE) — manages apps
#                         - Standard API Key — deprecated 2022, not used
#                         - OAuth Client Secret — for OAuth flows, not
#                           webhook management
#                       Use the Developer API Key.
#
#   <public-base-url>   The public host your assistant accepts webhooks
#                       on, e.g. https://macbook-pro.tailbaa208.ts.net
#                       (no trailing slash; the script appends the
#                       /api/v1/webhooks/hubspot path).
#
# Requires: bash, curl, jq.

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <app-id> <developer-hapikey> <public-base-url>" >&2
  echo "Example: $0 678910 hapi-xxx https://my-host.example.com" >&2
  exit 64
fi

APP_ID="$1"
HAPIKEY="$2"
BASE_URL="${3%/}"   # strip trailing slash if present
TARGET_URL="${BASE_URL}/api/v1/webhooks/hubspot"
EVENT_TYPE="contact.creation"

command -v jq >/dev/null || { echo "jq required (brew install jq)" >&2; exit 69; }

echo "→ Configuring webhook for app $APP_ID"
echo "  target URL: $TARGET_URL"

# 1. Set / update the target URL on the app. PUT is idempotent — repeated
#    calls with the same URL are no-ops; with a different URL, overwrite.
echo "→ Setting webhook target URL …"
SETTINGS_RESPONSE=$(curl -sS -X PUT \
  "https://api.hubapi.com/webhooks/v3/${APP_ID}/settings?hapikey=${HAPIKEY}" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg url "$TARGET_URL" '{
    targetUrl: $url,
    throttling: { period: "SECONDLY", maxConcurrentRequests: 10 }
  }')")
if echo "$SETTINGS_RESPONSE" | jq -e '.status == "error"' >/dev/null 2>&1; then
  echo "✗ Settings update failed:" >&2
  echo "$SETTINGS_RESPONSE" | jq . >&2
  exit 1
fi
echo "  ✓ target URL set"

# 2. List current subscriptions to decide whether to POST a new one.
echo "→ Listing existing subscriptions …"
SUBS=$(curl -sS \
  "https://api.hubapi.com/webhooks/v3/${APP_ID}/subscriptions?hapikey=${HAPIKEY}")

EXISTING=$(echo "$SUBS" | jq --arg ev "$EVENT_TYPE" \
  '.results[]? | select(.eventType == $ev)' || true)

if [[ -n "$EXISTING" ]]; then
  SUB_ID=$(echo "$EXISTING" | jq -r '.id')
  ACTIVE=$(echo "$EXISTING" | jq -r '.active')
  echo "  ✓ subscription already exists (id=$SUB_ID, active=$ACTIVE)"
  if [[ "$ACTIVE" != "true" ]]; then
    echo "→ Subscription is inactive — activating …"
    curl -sS -X PATCH \
      "https://api.hubapi.com/webhooks/v3/${APP_ID}/subscriptions/${SUB_ID}?hapikey=${HAPIKEY}" \
      -H 'Content-Type: application/json' \
      -d '{ "active": true }' | jq .
    echo "  ✓ activated"
  fi
else
  echo "→ Creating $EVENT_TYPE subscription …"
  CREATE_RESPONSE=$(curl -sS -X POST \
    "https://api.hubapi.com/webhooks/v3/${APP_ID}/subscriptions?hapikey=${HAPIKEY}" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg ev "$EVENT_TYPE" '{ eventType: $ev, active: true }')")
  if echo "$CREATE_RESPONSE" | jq -e '.status == "error"' >/dev/null 2>&1; then
    echo "✗ Subscription create failed:" >&2
    echo "$CREATE_RESPONSE" | jq . >&2
    exit 1
  fi
  SUB_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
  echo "  ✓ created subscription id=$SUB_ID"
fi

echo
echo "Done. Verify at:"
echo "  https://app.hubspot.com/developer/<your-account>/applications/${APP_ID}"
echo
echo "Next: in HubSpot CRM, create a contact. The webhook will fire to"
echo "  $TARGET_URL"
echo "and your assistant should produce a 'New HubSpot contact' card."
