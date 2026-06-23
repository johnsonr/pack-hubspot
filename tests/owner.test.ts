import { describe, it, expect } from "vitest";
import { entityForTest, mockGateway } from "@embabel/runtime-types";
import type { GenericGatewayContext } from "@embabel/runtime-types";
import { HubSpotOwner } from "../src/api/owner";

function owner(fields: Partial<HubSpotOwner>) {
  return entityForTest(HubSpotOwner, { id: "77", ...fields }, mockGateway<GenericGatewayContext>({}));
}

describe("HubSpotOwner", () => {
  it("displayName from first/last, then email, then id", () => {
    expect(owner({ firstName: "Jasper", lastName: "Blue" }).displayName()).toBe("Jasper Blue");
    expect(owner({ email: "jasper@acme.com" }).displayName()).toBe("jasper@acme.com");
    expect(owner({}).displayName()).toBe("77");
  });
});
