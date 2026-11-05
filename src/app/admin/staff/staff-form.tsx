"use client";

import Link from "next/link";
import { useActionState } from "react";
import { formatEligibleMemberName,type EligibleStaffMember } from "@/modules/staff";
import { createStaffProfile,updateStaffProfile,type StaffActionState } from "./actions";

type Values=Record<string,string>;
const initialStaffActionState:StaffActionState={status:"idle",fieldErrors:{},values:{}};
export function StaffForm({mode,requestId,scope,members=[],initial={}}:{mode:"create"|"update";requestId:string;scope:{id?:string;schoolId?:string|null;campusId?:string|null;membershipId?:string|null};members?:EligibleStaffMember[];initial?:Values}){
  const action=mode==="create"?createStaffProfile:updateStaffProfile;
  const [state,formAction,pending]=useActionState<StaffActionState,FormData>(action,initialStaffActionState);
  const current={...initialStaffActionState,...state,fieldErrors:state?.fieldErrors??{},values:state?.values??{}};
  const value=(name:string)=>current.values[name]??initial[name]??"";
  const field=(name:string,label:string,type="text")=><label>{label}<input name={name} type={type} defaultValue={value(name)} required={["firstName","lastName","staffNumber","employmentType"].includes(name)} aria-invalid={Boolean(current.fieldErrors[name])}/>{current.fieldErrors[name]?.map(message=><span className="field-error" key={message}>{message}</span>)}</label>;
  const linked=Boolean(scope.membershipId);
  return <form action={formAction}><input type="hidden" name="requestId" value={requestId}/>{scope.id&&<input type="hidden" name="id" value={scope.id}/>}<input type="hidden" name="schoolId" value={scope.schoolId??""}/><input type="hidden" name="campusId" value={scope.campusId??""}/><input type="hidden" name="existingMembershipId" value={scope.membershipId??""}/>{linked&&<input type="hidden" name="membershipId" value={scope.membershipId??""}/>} {current.message&&<p role={current.status==="error"?"alert":"status"}>{current.message}</p>}{current.status==="success"&&current.resultId&&<p><Link href={`/admin/staff/${current.resultId}`}>Open staff profile</Link></p>}<div className="form-grid">
    {!linked&&<label>Platform access (optional)<select name="membershipId" defaultValue={value("membershipId")}><option value="">No platform access</option>{members.map(member=><option key={member.membershipId} value={member.membershipId}>{formatEligibleMemberName(member)}</option>)}</select>{current.fieldErrors.membershipId?.map(message=><span className="field-error" key={message}>{message}</span>)}</label>}
    {field("firstName","First name")}{field("middleName","Middle name")}{field("lastName","Last name")}{field("displayName","Display name")}{field("workEmail","Work email","email")}{field("phone","Phone","tel")}{field("staffNumber","Staff number")}{field("employmentType","Employment type")}{field("jobTitle","Job title")}{field("department","Department")}{field("hireDate","Hire date","date")}{mode==="update"&&field("terminationDate","Termination date","date")}{mode==="update"&&<label>Status<select name="status" defaultValue={value("status")||"active"}><option value="active">Active</option><option value="inactive">Inactive</option></select></label>}</div><button disabled={pending}>{pending?"Saving…":mode==="create"?"Create staff profile":"Save changes"}</button></form>;
}
