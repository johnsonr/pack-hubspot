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
#   scripts/register-webhook.sh <public-base-url>
#   scripts/register-webhook.sh <public-base-url> <app-id> <developer-hapikey>
#
# Short form (RECOMMENDED): pass only the public URL. The script reads
#   `app-id` and `developer-key` from the deployment's
#   admin/oauth-apps.yml under apps.hubspot.* — the same file that
#   already holds your client-id and client-secret. Falls back to
#   <workspace>/config/oauth-apps.yml when the admin file isn't present.
#
# Long form (override): pass all three positional args. Useful if you
#   want to register against a different app without editing the YAML.
#
# Where to find the values (DEVELOPER ACCOUNT, not your CRM portal):
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

usage() {
  cat <<EOF >&2
Usage:
  $0 <public-base-url>                                  # reads app-id + dev key from oauth-apps.yml
  $0 <public-base-url> <app-id> <developer-hapikey>     # explicit override

Example:
  $0 https://my-host.example.com
  $0 https://my-host.example.com 678910 hapi-xxx
EOF
}

if [[ $# -lt 1 || $# -gt 3 || $# -eq 2 ]]; then
  usage
  exit 64
fi

command -v jq >/dev/null || { echo "jq required (brew install jq)" >&2; exit 69; }

BASE_URL="${1%/}"   # strip trailing slash if present
TARGET_URL="${BASE_URL}/api/v1/webhooks/hubspot"
EVENT_TYPE="contact.creation"

# --- Resolve app-id + developer key from oauth-apps.yml --------------
read_yaml_field() {
  # $1: file path, $2: dotted key under apps.hubspot.*
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 1
  if command -v python3 >/dev/null && python3 -c 'import yaml' 2>/dev/null; then
    python3 -c "
import sys, yaml
d = yaml.safe_load(open('$file')) or {}
v = d.get('apps', {}).get('hubspot', {}).get('$key', '') or ''
sys.stdout.write(str(v))
" 2>/dev/null
  else
    # Fallback: simple grep+awk for two-space-indented keys under
    # apps.hubspot. Good enough for the conventional shape; falls back
    # to "ask the operator to install python3-yaml or pass args
    # explicitly" if the YAML is heavily structured.
    awk -v target="$key" '
      /^apps:/ { in_apps=1; next }
      /^[^[:space:]]/ { in_apps=0 }
      in_apps && /^[[:space:]]+hubspot:[[:space:]]*$/ { in_hub=1; next }
      in_apps && /^[[:space:]]+[a-zA-Z][^:]*:[[:space:]]*$/ && !/hubspot:/ { in_hub=0 }
      in_hub {
        n = split($0, parts, ":")
        if (n >= 2) {
          field = parts[1]
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
          if (field == target) {
            value = substr($0, index($0, ":") + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
          }
        }
      }
    ' "$file"
  fi
}

resolve_creds() {
  local admin="${WORKSPACE_BASE:-$HOME/embabel/assistant}/admin/oauth-apps.yml"
  for path in "$admin" "$PWD/admin/oauth-apps.yml"; do
    if [[ -f "$path" ]]; then
      RESOLVED_APP_ID=$(read_yaml_field "$path" "app-id")
      RESOLVED_KEY=$(read_yaml_field "$path" "developer-key")
      if [[ -n "$RESOLVED_APP_ID" && -n "$RESOLVED_KEY" ]]; then
        SOURCE="$path"
        return 0
      fi
    fi
  done
  return 1
}

if [[ $# -eq 3 ]]; then
  APP_ID="$2"
  HAPIKEY="$3"
  echo "→ Using app-id and developer-key from positional args"
else
  if ! resolve_creds; then
    cat >&2 <<EOF
✗ Could not resolve app-id + developer-key from oauth-apps.yml.
  Looked in:
    \$WORKSPACE_BASE/admin/oauth-apps.yml (default)
    ./admin/oauth-apps.yml (cwd fallback)

  Either add to apps.hubspot.* in that file:
    apps:
      hubspot:
        client-id:    "..."
        client-secret: "..."
        app-id:       "678910"        # ← add this
        developer-key: "hapi-xxx"     # ← and this

  …or pass them explicitly:
    $0 $BASE_URL <app-id> <developer-hapikey>
EOF
    exit 78
  fi
  APP_ID="$RESOLVED_APP_ID"
  HAPIKEY="$RESOLVED_KEY"
  echo "→ Using app-id and developer-key from $SOURCE"
fi

echo "→ Configuring webhook for app $APP_ID"
echo "  target URL: $TARGET_URL"

# --- 1. Set / update the target URL on the app -----------------------
# PUT is idempotent — repeated calls with the same URL are no-ops; with
# a different URL, overwrite.
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

# --- 2. List current subscriptions, decide POST vs PATCH vs no-op ----
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
