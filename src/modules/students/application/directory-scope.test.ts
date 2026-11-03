import { describe,expect,it } from "vitest";
import type { AdminContext } from "@/modules/organizations";
import { constrainDirectoryQuery } from "./directory-scope";

const organizationId="10000000-0000-4000-8000-000000000001",schoolId="20000000-0000-4000-8000-000000000001",campusId="30000000-0000-4000-8000-000000000001",otherCampusId="30000000-0000-4000-8000-000000000002";
const context=(school:string|null,campus:string|null):AdminContext=>({organizationId,schoolId:school,campusId:campus,membershipId:"40000000-0000-4000-8000-000000000001",organizationName:"Org",organizationSlug:"org",schoolName:school?"School":null,schoolCode:school?"S":null,campusName:campus?"Campus":null,campusCode:campus?"C":null,scopeLevel:campus?"campus":school?"school":"organization",permissionCodes:["students.view"]});
const query={q:"",status:"active" as const,school:null,campus:null,sort:"name" as const,dir:"asc" as const,after:null};

describe("student directory selected scope",()=>{
  it("cannot broaden a campus context with directory filters",()=>{const selected=context(schoolId,campusId);expect(constrainDirectoryQuery(selected,[selected],{...query,school:"20000000-0000-4000-8000-000000000099",campus:otherCampusId})).toMatchObject({school:schoolId,campus:campusId});});
  it("cannot replace a school context with another school or unauthorized campus",()=>{const selected=context(schoolId,null);expect(constrainDirectoryQuery(selected,[selected],{...query,school:"20000000-0000-4000-8000-000000000099",campus:otherCampusId})).toMatchObject({school:schoolId,campus:null});});
  it("permits only authorized narrowing inside organization context",()=>{const selected=context(null,null),allowed=context(schoolId,campusId);expect(constrainDirectoryQuery(selected,[selected,allowed],{...query,school:schoolId,campus:campusId})).toMatchObject({school:schoolId,campus:campusId});expect(constrainDirectoryQuery(selected,[selected,allowed],{...query,school:schoolId,campus:otherCampusId})).toMatchObject({school:null,campus:null});});
});
