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
 * A HubSpot CRM company materialized on demand (see `types/hubspot.yml`), keyed
 * by `domain`. Pure verbs read its fields; `update` writes back, addressing the
 * company by `domain` via `idProperty` (no numeric-id lookup).
 */
export class HubSpotCompany extends Entity {
  // `id` (identity) is inherited from Entity and equals the domain.
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
