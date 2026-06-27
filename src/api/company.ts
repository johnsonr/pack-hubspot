import { Entity } from "@embabel/runtime-types";
import type { HubSpotObject } from "./contact";

interface HubSpotGateway {
  hubspot: {
    objectsUpdate(args: {
      objectType: string;
      objectId: string;
      idProperty?: string;
      properties: Record<string, string>;
    }): Promise<HubSpotObject>;
  };
}

/**
 * A HubSpot CRM company materialized on demand (see `types/hubspot.yml`). Its graph
 * identity is the HubSpot object id (`hs_object_id`), so it dedupes whether reached by
 * domain (from an Organization) or by object id (from a contact's primary company).
 * `update` still writes back addressing the company by `domain` via `idProperty` (a
 * convenient natural key — no numeric-id lookup); it requires a usable domain.
 */
export class HubSpotCompany extends Entity {
  // `id` (identity) is the HubSpot object id; `domain` is the natural key used for write-back.
  hs_object_id?: string;
  domain!: string;
  name?: string;
  industry?: string;
  website?: string;

  private get api(): HubSpotGateway {
    return this.gateway as unknown as HubSpotGateway;
  }

  /** Whether the company has a usable web domain (its identity / update key). */
  hasDomain(): boolean {
    return !!this.domain && this.domain.trim().length > 0;
  }

  /** Update company properties (addressed by domain). */
  async update(properties: Record<string, string>): Promise<HubSpotObject> {
    if (!this.hasDomain()) throw new Error("cannot update a HubSpot company with no domain");
    return this.api.hubspot.objectsUpdate({ objectType: "companies", objectId: this.domain, idProperty: "domain", properties });
  }
}
