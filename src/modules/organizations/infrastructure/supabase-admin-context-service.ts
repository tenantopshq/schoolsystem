import { createSupabaseServerClient } from "@/platform/database/supabase-server";
import type { Database } from "@/platform/database/database.types";
import type { AdminContext, AdminContextService } from "../index";

type ContextRow = Database["public"]["Functions"]["get_my_admin_contexts"]["Returns"][number];
type ContextRpc = (
  name: "get_my_admin_contexts",
) => Promise<{ data: ContextRow[] | null; error: Error | null }>;

export class SupabaseAdminContextService implements AdminContextService {
  async listMine(): Promise<AdminContext[]> {
    const db = await createSupabaseServerClient();
    const rpc = db.rpc.bind(db) as unknown as ContextRpc;
    const { data, error } = await rpc("get_my_admin_contexts");

    if (error) throw error;

    return (data ?? []).map((row): AdminContext => ({
      membershipId: row.membership_id,
      organizationId: row.organization_id,
      organizationName: row.organization_name,
      organizationSlug: row.organization_slug,
      schoolId: row.school_id,
      schoolName: row.school_name,
      schoolCode: row.school_code,
      campusId: row.campus_id,
      campusName: row.campus_name,
      campusCode: row.campus_code,
      scopeLevel: row.scope_level as AdminContext["scopeLevel"],
      permissionCodes: row.permission_codes,
    }));
  }
}
