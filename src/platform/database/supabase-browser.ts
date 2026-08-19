import { createBrowserClient } from "@supabase/ssr";
import { env } from "@/shared/config/env";

export function createSupabaseBrowserClient() {
  return createBrowserClient(env.NEXT_PUBLIC_SUPABASE_URL, env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
}

