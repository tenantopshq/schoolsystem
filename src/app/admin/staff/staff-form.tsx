"use client";

import Link from "next/link";
import { useActionState } from "react";
import { formatEligibleMemberName,type EligibleStaffMember } from "@/modules/staff";
import { createStaffProfile,initialStaffActionState,updateStaffProfile,type StaffActionState } from "./actions";

type Values=Record<string,string>;
export function StaffForm({mode,requestId,scope,members=[],initial={}}:{mode:"create"|"update";requestId:string;scope:{id?:string;schoolId?:string|null;campusId?:string|null};members?:EligibleStaffMember[];initial?:Values}){
  const action=mode==="create"?createStaffProfile:updateStaffProfile;
  const [state,formAction,pending]=useActionState<StaffActionState,FormData>(action,initialStaffActionState);
  const value=(name:string)=>state.values[name]??initial[name]??"";
  const field=(name:string,label:string,type="text")=><label>{label}<input name={name} type={type} defaultValue={value(name)} aria-invalid={Boolean(state.fieldErrors[name])}/>{state.fieldErrors[name]?.map(message=><span className="field-error" key={message}>{message}</span>)}</label>;
  return <form action={formAction}><input type="hidden" name="requestId" value={requestId}/>{scope.id&&<input type="hidden" name="id" value={scope.id}/>}<input type="hidden" name="schoolId" value={scope.schoolId??""}/><input type="hidden" name="campusId" value={scope.campusId??""}/>{state.message&&<p role={state.status==="error"?"alert":"status"}>{state.message}</p>}{state.status==="success"&&state.resultId&&<p><Link href={`/admin/staff/${state.resultId}`}>Open staff profile</Link></p>}<div className="form-grid">{mode==="create"&&<label>Organization member<select name="membershipId" defaultValue={value("membershipId")} required><option value="">Select a member</option>{members.map(member=><option key={member.membershipId} value={member.membershipId}>{formatEligibleMemberName(member)}</option>)}</select>{state.fieldErrors.membershipId?.map(message=><span className="field-error" key={message}>{message}</span>)}</label>}{field("staffNumber","Staff number")}{field("employmentType","Employment type")}{field("jobTitle","Job title")}{field("department","Department")}{field("hireDate","Hire date","date")}{mode==="update"&&field("terminationDate","Termination date","date")}{mode==="update"&&<label>Status<select name="status" defaultValue={value("status")||"active"}><option value="active">Active</option><option value="inactive">Inactive</option></select></label>}</div><button disabled={pending}>{pending?"Saving…":mode==="create"?"Create staff profile":"Save changes"}</button></form>;
}
