import { createBrowserClient } from "@supabase/ssr";
import { env } from "@/shared/config/env";
import type { Database } from "@/platform/database/database.types";

export function createSupabaseBrowserClient() {
  return createBrowserClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  );
}
