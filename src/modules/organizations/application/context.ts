import { cookies } from "next/headers";
import { adminContextSchema, type AdminContextSelection } from "../index";
import { SupabaseAdminContextService } from "../infrastructure/supabase-admin-context-service";
import { decodeContextCookie,encodeContextCookie,reauthorizeContext } from "./context-cookie";
const name="school-context";
const secret=()=>{const value=process.env.CONTEXT_COOKIE_SECRET;if(value&&Buffer.byteLength(value,"utf8")>=32)return value;if(process.env.NODE_ENV==="production")throw new Error("CONTEXT_COOKIE_SECRET must contain at least 32 bytes");return "local-development-context-secret-change-me";};
export async function setSelectedContext(value:AdminContextSelection){const parsed=adminContextSchema.parse(value);const contexts=await new SupabaseAdminContextService().listMine();if(!reauthorizeContext(parsed,contexts))throw new Error("CONTEXT_NOT_ALLOWED");(await cookies()).set(name,encodeContextCookie(parsed,secret()),{httpOnly:true,sameSite:"lax",secure:process.env.NODE_ENV==="production",path:"/"});}
export async function resolveSelectedContextAuthorization(){const raw=(await cookies()).get(name)?.value;if(!raw)return null;const selection=decodeContextCookie(raw,secret());if(!selection)return null;const contexts=await new SupabaseAdminContextService().listMine();const selected=reauthorizeContext(selection,contexts);return selected?{selected,contexts}:null;}
export async function resolveSelectedContext(){return (await resolveSelectedContextAuthorization())?.selected??null;}
