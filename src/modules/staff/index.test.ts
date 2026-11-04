import { describe, expect, it } from "vitest";
import { formatStaffName, parseStaffDirectoryQuery, staffProfileIdSchema } from "./index";

describe("staff public boundary", () => {
  it("normalizes unsafe directory query values", () => {
    expect(parseStaffDirectoryQuery({ q: "  Ada  ", status: "unknown", after: undefined })).toEqual({ q: "Ada", status: "active", after: null });
  });

  it("prefers display name and falls back without exposing identity data", () => {
    expect(formatStaffName({ displayName: "Dr Ada", firstName: "Ada", middleName: null, lastName: "Lovelace", staffNumber: "S1" })).toBe("Dr Ada");
    expect(formatStaffName({ displayName: null, firstName: "Ada", middleName: null, lastName: "Lovelace", staffNumber: "S1" })).toBe("Ada Lovelace");
  });

  it("rejects malformed route identifiers before an RPC call", () => {
    expect(staffProfileIdSchema.safeParse("not-a-uuid").success).toBe(false);
  });

});
