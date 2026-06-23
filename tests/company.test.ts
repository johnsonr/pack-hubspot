import { describe, it, expect, vi } from "vitest";
import { entityForTest, mockGateway } from "@embabel/runtime-types";
import type { GenericGatewayContext } from "@embabel/runtime-types";
import { HubSpotCompany } from "../src/api/company";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function company(fields: Partial<HubSpotCompany>, hubspot: Record<string, (args: any) => any> = {}) {
  return entityForTest(
    HubSpotCompany,
    { domain: "acme.com", ...fields },
    mockGateway<GenericGatewayContext>({ hubspot }),
  );
}

describe("HubSpotCompany", () => {
  it("hasDomain reflects the identity key", () => {
    expect(company({}).hasDomain()).toBe(true);
    expect(company({ domain: "" }).hasDomain()).toBe(false);
  });

  it("update addresses the company by domain via idProperty", async () => {
    const objectsUpdate = vi.fn(async () => ({ id: "9001" }));
    await company({}, { objectsUpdate }).update({ industry: "Software" });
    expect(objectsUpdate).toHaveBeenCalledWith({
      objectType: "companies", objectId: "acme.com", idProperty: "domain", properties: { industry: "Software" },
    });
  });

  it("update throws when there is no domain", async () => {
    await expect(company({ domain: "" }).update({ industry: "x" })).rejects.toThrow(/no domain/);
  });
});
