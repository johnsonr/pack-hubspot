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

## Auth — OAuth2

End users **never** paste API tokens, never know about client IDs, and
never set environment variables. They click **Authorize** in
Settings → Connected Services. That's it.

This works because the assistant deployment has ONE registered HubSpot
Public App. Every end user connects their own HubSpot account against
that single app — same as how "Login with Google" works on every
website you've ever used.

### For end users

1. Open **Settings → Connected Services**.
2. Click **Authorize** on the `hubspot` row.
3. Consent on HubSpot's page. Done — `gateway.hubspot.*` is live in chat.

If the row shows **"Not configured"**, the deployment operator hasn't
registered the HubSpot app yet — show them the next section.

### For operators (one-time deployment setup)

You only do this once per deployment, no matter how many end users join.

1. **Create a HubSpot Public App** at
   `app.hubspot.com/developer/<your-hubid>/applications`.
2. **Scopes** — enable at least:
   ```
   crm.objects.contacts.read   crm.objects.contacts.write
   crm.objects.companies.read  crm.objects.companies.write
   crm.objects.deals.read      crm.objects.deals.write
   crm.objects.owners.read     tickets
   ```
   Pare back to read-only if the deployment should only browse, never
   write.
3. **Redirect URI** — set to your assistant's public callback URL:
   `https://your-host/api/v1/auth/oauth2/callback`
   (or `http://localhost:8042/api/v1/auth/oauth2/callback` for local dev).
4. **Copy** the app's client ID and client secret.
5. **Add them to the deployment's `application.yml`** (or env vars —
   Spring relaxed binding):

   ```yaml
   assistant:
     oauth:
       apps:
         hubspot:
           client-id: 12345-abcdef-...
           client-secret: secret-blah
   ```

   Or:
   ```bash
   ASSISTANT_OAUTH_APPS_HUBSPOT_CLIENT_ID=...
   ASSISTANT_OAUTH_APPS_HUBSPOT_CLIENT_SECRET=...
   ```
6. Restart the deployment. Every end user can now click Authorize.

Token refresh is automatic. End users can disconnect from the same
Settings panel any time.

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
