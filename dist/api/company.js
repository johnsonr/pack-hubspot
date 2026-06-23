"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.HubSpotCompany = void 0;
const runtime_types_1 = require("@embabel/runtime-types");
/**
 * A HubSpot CRM company materialized on demand (see `types/hubspot.yml`), keyed
 * by `domain`. Pure verbs read its fields; `update` writes back, addressing the
 * company by `domain` via `idProperty` (no numeric-id lookup).
 */
class HubSpotCompany extends runtime_types_1.Entity {
    // `id` (identity) is inherited from Entity and equals the domain.
    domain;
    name;
    industry;
    website;
    get api() {
        return this.gateway;
    }
    /** Whether the company has a usable web domain (its identity / update key). */
    hasDomain() {
        return !!this.domain && this.domain.trim().length > 0;
    }
    /** Update company properties (addressed by domain). */
    async update(properties) {
        if (!this.hasDomain())
            throw new Error("cannot update a HubSpot company with no domain");
        return this.api.hubspot.objectsUpdate({ objectType: "companies", objectId: this.domain, idProperty: "domain", properties });
    }
}
exports.HubSpotCompany = HubSpotCompany;
