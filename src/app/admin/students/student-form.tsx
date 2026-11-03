"use client";
import Link from "next/link";
import { useActionState } from "react";
import { createStudent,initialStudentActionState,updateStudent,type StudentActionState } from "./actions";

type Values=Record<string,string>;
export function StudentForm({mode,requestId,scope,initial={}}:{mode:"create"|"update";requestId:string;scope:{id?:string;schoolId?:string;campusId?:string};initial?:Values}){
  const action=mode==="create"?createStudent:updateStudent;
  const [state,formAction,pending]=useActionState<StudentActionState,FormData>(action,initialStudentActionState);
  const value=(name:string)=>state.values[name]??initial[name]??"";
  const field=(name:string,label:string,type="text")=><label>{label}<input name={name} type={type} defaultValue={value(name)} aria-invalid={Boolean(state.fieldErrors[name])} aria-describedby={state.fieldErrors[name]?`${name}-error`:undefined}/>{state.fieldErrors[name]?.map(message=><span className="field-error" id={`${name}-error`} key={message}>{message}</span>)}</label>;
  return <form action={formAction}><input type="hidden" name="requestId" value={requestId}/>{scope.id&&<input type="hidden" name="id" value={scope.id}/>}<input type="hidden" name="schoolId" value={scope.schoolId??""}/><input type="hidden" name="campusId" value={scope.campusId??""}/>{state.message&&<p role={state.status==="error"?"alert":"status"}>{state.message}</p>}{state.status==="success"&&state.resultId&&<p><Link href={`/admin/students/${state.resultId}`}>Open student record</Link></p>}<div className="form-grid">{field("studentNumber","Student number")}{field("firstName","First name")}{field("middleName","Middle name")}{field("lastName","Last name")}{field("preferredName","Preferred name")}{field("dateOfBirth","Date of birth","date")}{field("gender","Gender")}{field("nationalityCode","Nationality code")}{field("primaryLanguage","Primary language")}{field("admissionDate","Admission date","date")}{mode==="update"&&field("exitDate","Exit date","date")}{mode==="update"&&<label>Status<select name="status" defaultValue={value("status")||"active"}><option value="active">Active</option><option value="inactive">Inactive</option></select></label>}</div><button disabled={pending}>{pending?"Saving…":mode==="create"?"Create student":"Save changes"}</button></form>;
}
