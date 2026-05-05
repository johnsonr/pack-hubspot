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

## Auth

HubSpot Private Apps are the easiest path. In your HubSpot account:

1. Settings → Integrations → Private Apps → Create a private app.
2. Under **Scopes**, enable: `crm.objects.contacts.read/write`,
   `crm.objects.companies.read/write`, `crm.objects.deals.read/write`,
   `crm.objects.owners.read`, plus tickets / pipelines as needed.
3. Copy the access token.
4. Set it in the credential store or env: `HUBSPOT_PRIVATE_APP_TOKEN=pat-na1-...`

The token is sent as `Authorization: Bearer <token>`.

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
