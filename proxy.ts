import type { NextRequest } from "next/server";
import { refreshSession } from "@/platform/database/supabase-middleware";
export function proxy(request: NextRequest) { return refreshSession(request); }
export const config = { matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"] };
