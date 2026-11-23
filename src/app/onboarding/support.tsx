import Link from "next/link";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/platform/database/supabase-server";
export async function requireOnboardingUser(){const db=await createSupabaseServerClient();const{data:{user}}=await db.auth.getUser();if(!user)redirect("/login");return user;}
export function OnboardingShell({title,children}:{title:string;children:React.ReactNode}){return <main className="auth-card"><Link href="/onboarding">Organization onboarding</Link><h1>{title}</h1>{children}</main>;}
export function OnboardingError({code}:{code?:string|undefined}){if(!code)return null;const message=code==="duplicate"?"That slug or code is already in use.":code==="unauthorized"?"That onboarding flow is unavailable.":code==="retry"?"The request is still processing. Try again.":"Check the form and try again.";return <p role="alert">{message}</p>;}
