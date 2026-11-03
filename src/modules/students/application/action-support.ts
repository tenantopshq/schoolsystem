import type { ZodError } from "zod";

export type SafeActionState = {status:"idle"|"error"|"success";message?:string;fieldErrors:Record<string,string[]>;values:Record<string,string>;resultId?:string};

export function validationState(error: ZodError, submitted: Record<string,string>): SafeActionState {
  const errors:Record<string,string[]>={};
  for(const issue of error.issues){const key=String(issue.path[0]??"form");(errors[key]??=[]).push(issue.message);}
  return {status:"error",message:"Check the highlighted fields.",fieldErrors:errors,values:submitted};
}

export function errorCode(error:unknown){return typeof error==="object"&&error!==null&&"code" in error&&typeof error.code==="string"?error.code:null;}

export function safeFailure(error:unknown,submitted:Record<string,string>):SafeActionState {
  const code=errorCode(error);
  const message=code==="42501"?"You no longer have permission for this action.":code==="23505"?"A student with that number already exists.":code==="23503"?"This student cannot be archived while active related records remain.":code==="P0002"?"This record is no longer available.":code==="22023"?"The requested change is not valid for the current record state.":"The action could not be completed. Try again or contact support.";
  return {status:"error",message,fieldErrors:{},values:submitted};
}

export async function runReplaySafe<T>(requestId:string,operation:(stableRequestId:string)=>Promise<T>,wait:()=>Promise<void>=()=>new Promise(resolve=>setTimeout(resolve,40))){for(let attempt=0;;attempt++){try{return await operation(requestId);}catch(error){if(!["40001","40P01"].includes(errorCode(error)??"")||attempt>=1)throw error;await wait();}}}
