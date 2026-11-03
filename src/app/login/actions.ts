"use server";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/platform/database/supabase-server";
export async function signIn(form:FormData){const db=await createSupabaseServerClient();const email=String(form.get("email")??"");const password=String(form.get("password")??"");const {error}=await db.auth.signInWithPassword({email,password});if(error)redirect("/login?error=invalid");redirect("/select-context");}
export async function signOut(){const db=await createSupabaseServerClient();await db.auth.signOut();redirect("/login");}
