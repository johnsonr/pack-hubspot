# pack-hubspot

HubSpot CRM v3 via a curated, vendored OpenAPI 3 spec — gives the LLM
full request **and** response types for the high-traffic CRM surface
without depending on HubSpot's now-defunct public spec catalog.

## Why

HubSpot used to publish per-API OpenAPI specs at
`api.hubspot.com/api-catalog-public/v1/apis/...`. Those URLs all 404 as
of 2026 — HubSpot's docs site is now SPA-rendered with no spec download
links, and apis.guru's `crm` mirror only contains the Cards extension.
Community-maintained unified specs exist but drift.

This pack vendors a hand-written mini-spec (`apis/hubspot-crm.json`)
that covers ~12 ops parameterised by object type, handling 95% of
chat-driven CRM workflows. Same data the LLM would read from a
3,000-op upstream dump, in a tenth of the prompt.

## Namespace

Methods land under `gateway.hubspot`. E.g.:

- `gateway.hubspot.objectsList({ objectType: "contacts", limit: 100 })`
- `gateway.hubspot.objectsGet({ objectType: "deals", objectId: "12345" })`
- `gateway.hubspot.objectsCreate({ objectType: "contacts", properties: { email, firstname, lastname } })`
- `gateway.hubspot.objectsSearch({ objectType: "deals", filterGroups: [...] })`
- `gateway.hubspot.ownersList({})`
- `gateway.hubspot.pipelinesList({ objectType: "deals" })`
- `gateway.hubspot.associationsGet({ fromObjectType: "contacts", fromObjectId, toObjectType: "deals" })`

See `prompts/examples.md` for usage patterns.

## Auth — OAuth2 (no token paste)

This pack uses HubSpot's OAuth2 Public App flow. The user clicks
**Authorize** in Settings → Connected Services and gets bounced through
HubSpot's consent screen — no copy/paste of API tokens.

One-time setup per assistant installation:

1. **Create a HubSpot Public App** at
   `app.hubspot.com/developer/<hubid>/applications`.
2. **Scopes** — enable at least:
   `crm.objects.contacts.read crm.objects.contacts.write`
   `crm.objects.companies.read crm.objects.companies.write`
   `crm.objects.deals.read crm.objects.deals.write`
   `crm.objects.owners.read tickets`
   (Pare back to read-only if the assistant should only browse.)
3. **Redirect URI** — set to your assistant's callback:
   `http://localhost:8042/api/v1/auth/oauth2/callback`
   (or your deployed host's URL).
4. **Copy** the app's client ID and client secret.
5. **Tell the assistant** by typing in chat (intercepted, never sent to
   the LLM):
   ```
   set HUBSPOT_CLIENT_ID = <your-client-id>
   set HUBSPOT_CLIENT_SECRET = <your-client-secret>
   ```
6. Open **Settings → Connected Services** in the assistant and click
   **Authorize** on the `hubspot` row. After consent the row shows
   "Connected `<your-hub-domain>`" and `gateway.hubspot.*` is live.

Token refresh is automatic. Disconnect any time from the same Settings
panel.

## Object types covered

`contacts`, `companies`, `deals`, `tickets`. All share the same
`SimplePublicObject` request/response shape — `properties` is a
`Map<String, String>`, IDs are strings, timestamps are ISO 8601.

For non-default objects (line items, products, custom objects) the same
endpoints apply — pass the object's API name as `objectType`.

## What's NOT in this pack

To keep the spec small, these are out of scope:

- **Marketing emails / forms / CTAs** — different API surface, add a
  separate spec if needed
- **CMS / blog / hubdb** — content APIs, different shapes
- **Webhooks subscriptions** — out-of-band; configure in HubSpot UI
- **Files API** — separate; can be added later
- **Properties metadata** — listing custom properties; rarely needed in
  chat (just pass the property names you know)
- **Engagements (notes/tasks/calls/emails/meetings)** — these are
  separate object types under `/crm/v3/objects/{type}` and work via the
  same generic endpoints; pass `objectType: "notes"` etc.

## Sample data

Spin up a free HubSpot developer test account at
`app.hubspot.com/signup-hubspot/developers` — enables sample contacts,
companies, and deals on first login. Good enough to verify the pack.
