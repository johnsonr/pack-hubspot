# pack-hubspot — usage examples

The vendored OpenAPI spec exposes namespace `hubspot`. All ops are
parameterised by `objectType` so the same `objectsSearch` works for
contacts, companies, deals, tickets, notes, tasks, calls, emails, and
custom objects.

## Why this pack exists

HubSpot stopped publishing public OpenAPI specs in 2025. Untyped HubSpot
tooling forces the LLM to guess wrapper shapes (`{ results, paging }` vs
`{ total, results, paging }`), property casing (`firstname` vs
`firstName`), and stage-vs-label confusion on deals. With this pack the
LLM reads the wrapper shape and required fields from `interfaces.ts`
before writing the script.

## Common patterns

Find a contact by email, then update lifecycle stage:

```javascript
const r = await gateway.hubspot.objectsSearch({
  objectType: "contacts",
  filterGroups: [{ filters: [{ propertyName: "email", operator: "EQ", value: "alice@acme.com" }] }],
  properties: ["email", "firstname", "lifecyclestage"],
  limit: 1,
});
const c = r.results[0];
if (!c) { console.log("No match"); return; }
await gateway.hubspot.objectsUpdate({
  objectType: "contacts",
  objectId: c.id,
  properties: { lifecyclestage: "customer" },
});
```

Top-N closed-won deal owners last 90 days:

```javascript
const since = new Date(Date.now() - 90 * 86400_000).toISOString();
let after, all = [];
for (let p = 0; p < 5; p++) {
  const r = await gateway.hubspot.objectsSearch({
    objectType: "deals",
    filterGroups: [{ filters: [
      { propertyName: "dealstage", operator: "EQ", value: "closedwon" },
      { propertyName: "closedate", operator: "GTE", value: since },
    ]}],
    properties: ["amount", "hubspot_owner_id"],
    limit: 100,
    after,
  });
  all.push(...r.results);
  after = r.paging?.next?.after;
  if (!after) break;
}
const byOwner = {};
for (const d of all) {
  const k = d.properties.hubspot_owner_id ?? "unassigned";
  byOwner[k] = (byOwner[k] || 0) + parseFloat(d.properties.amount || "0");
}
const top = Object.entries(byOwner).sort((a, b) => b[1] - a[1]).slice(0, 10);
console.log(JSON.stringify(top));
```

Create a contact and link to a company:

```javascript
const c = await gateway.hubspot.objectsCreate({
  objectType: "contacts",
  properties: { email: "bob@acme.com", firstname: "Bob", lastname: "Singh", company: "Acme" },
});
// Find Acme
const cos = await gateway.hubspot.objectsSearch({
  objectType: "companies",
  filterGroups: [{ filters: [{ propertyName: "name", operator: "EQ", value: "Acme" }] }],
  limit: 1,
});
if (cos.results[0]) {
  await gateway.hubspot.associationsCreateDefault({
    fromObjectType: "contacts",
    fromObjectId: c.id,
    toObjectType: "companies",
    toObjectId: cos.results[0].id,
  });
}
```

Create a deal in the right stage:

```javascript
const pipes = await gateway.hubspot.pipelinesList({ objectType: "deals" });
const sales = pipes.results.find(p => p.label === "Sales Pipeline");
const newStage = sales.stages.find(s => s.label.match(/new|appointment/i)).id;

await gateway.hubspot.objectsCreate({
  objectType: "deals",
  properties: {
    dealname: "Acme — Q2 expansion",
    amount: "25000",
    pipeline: sales.id,
    dealstage: newStage,
  },
});
```
