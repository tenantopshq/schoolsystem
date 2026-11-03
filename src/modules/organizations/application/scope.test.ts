import { describe,expect,it } from "vitest";
import type { AdminContext } from "../index";
import { selectedContextContains,targetHasPermission } from "./scope";
import { decodeContextCookie,encodeContextCookie,reauthorizeContext } from "./context-cookie";

const org="10000000-0000-4000-8000-000000000001",school="20000000-0000-4000-8000-000000000001",campus="30000000-0000-4000-8000-000000000001",otherCampus="30000000-0000-4000-8000-000000000002";
const context=(schoolId:string|null,campusId:string|null,permissions=["students.view"]):AdminContext=>({organizationId:org,schoolId,campusId,membershipId:"40000000-0000-4000-8000-000000000001",organizationName:"Org",organizationSlug:"org",schoolName:schoolId?"School":null,schoolCode:schoolId?"S":null,campusName:campusId?"Campus":null,campusCode:campusId?"C":null,scopeLevel:campusId?"campus":schoolId?"school":"organization",permissionCodes:permissions});

describe("selected administrative scope",()=>{
  it("denies direct detail and edit targets outside selected context",()=>{const selected=context(school,campus,["students.view","students.edit"]),target={organizationId:org,schoolId:school,campusId:otherCampus};expect(selectedContextContains(selected,target)).toBe(false);expect(targetHasPermission(selected,[selected],target,"students.edit")).toBe(false);});
  it("does not authorize management workflows for a view-only context",()=>{const selected=context(school,campus);const target={organizationId:org,schoolId:school,campusId:campus};for(const permission of ["students.create","students.edit","students.archive"])expect(targetHasPermission(selected,[selected],target,permission)).toBe(false);});
});

describe("selected context cookie",()=>{
  it("rejects tampering",()=>{const value=encodeContextCookie({organizationId:org,schoolId:school,campusId:campus},"a sufficiently strong test secret value");expect(decodeContextCookie(`${value}x`,"a sufficiently strong test secret value")).toBeNull();});
  it("requires current-context reauthorization",()=>{const selection={organizationId:org,schoolId:school,campusId:campus};expect(reauthorizeContext(selection,[context(school,campus)])).not.toBeNull();expect(reauthorizeContext(selection,[context(school,otherCampus)])).toBeNull();});
});
