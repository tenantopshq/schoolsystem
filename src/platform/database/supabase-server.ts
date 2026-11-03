import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import type { Database } from "./database.types";
import { env } from "@/shared/config/env";

export async function createSupabaseServerClient() {
  const jar = await cookies();
  return createServerClient<Database>(env.NEXT_PUBLIC_SUPABASE_URL, env.NEXT_PUBLIC_SUPABASE_ANON_KEY, {
    cookies: { getAll: () => jar.getAll(), setAll: (values: {name:string;value:string;options:any}[]) => { try { values.forEach(({ name, value, options }) => jar.set(name, value, options)); } catch {} } },
  });
}
