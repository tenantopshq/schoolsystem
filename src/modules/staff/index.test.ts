import { describe, expect, it } from "vitest";
import { archiveStaffProfileSchema, createStaffProfileSchema, formatEligibleMemberName, formatStaffName, parseStaffDirectoryQuery, staffProfileIdSchema, updateStaffProfileSchema } from "./index";

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

  it("validates scoped staff creation and bounded employment fields", () => {
    expect(createStaffProfileSchema.safeParse({ membershipId:"10000000-0000-4000-8000-000000000001",schoolId:null,campusId:"20000000-0000-4000-8000-000000000001",staffNumber:"S1",employmentType:"employee",jobTitle:null,department:null,hireDate:null,status:"active" }).success).toBe(false);
    expect(createStaffProfileSchema.safeParse({ membershipId:"10000000-0000-4000-8000-000000000001",schoolId:"20000000-0000-4000-8000-000000000001",campusId:null,staffNumber:"S1",employmentType:"employee",jobTitle:"Teacher",department:null,hireDate:"2026-08-01",status:"active" }).success).toBe(true);
  });

  it("rejects invalid employment dates and unbounded archive reasons", () => {
    expect(updateStaffProfileSchema.safeParse({id:"10000000-0000-4000-8000-000000000001",staffNumber:"S1",employmentType:"employee",jobTitle:null,department:null,hireDate:"2026-08-02",terminationDate:"2026-08-01",status:"inactive"}).success).toBe(false);
    expect(archiveStaffProfileSchema.safeParse({targetStaffProfileId:"10000000-0000-4000-8000-000000000001",archiveReason:"x".repeat(501)}).success).toBe(false);
  });

  it("formats eligible members without requiring private identity fields", () => {
    expect(formatEligibleMemberName({membershipId:"10000000-0000-4000-8000-000000000001",firstName:"Ada",middleName:null,lastName:"Lovelace",displayName:null})).toBe("Ada Lovelace");
  });

});
