import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/platform/database/supabase-server";
import { SupabaseAdminContextService } from "@/modules/organizations/infrastructure/supabase-admin-context-service";
import { selectContext } from "./actions";

export default async function SelectContext({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const db = await createSupabaseServerClient();
  const {
    data: { user },
  } = await db.auth.getUser();

  if (!user) redirect("/login");

  const contexts = await new SupabaseAdminContextService().listMine();
  const query = await searchParams;

  return (
    <main>
      <h1>Select context</h1>
      {query.error && (
        <p role="alert">That context is invalid or no longer available.</p>
      )}
      {contexts.length === 0 ? (
        <p role="alert">No active administrative context is available.</p>
      ) : (
        <form action={selectContext}>
          <label>
            Organization, school and campus
            <select name="context" required defaultValue="">
              <option value="" disabled>
                Select…
              </option>
              {contexts.map((context) => (
                <option
                  key={`${context.organizationId}:${context.schoolId}:${context.campusId}`}
                  value={JSON.stringify({
                    organizationId: context.organizationId,
                    schoolId: context.schoolId,
                    campusId: context.campusId,
                  })}
                >
                  {[context.organizationName, context.schoolName, context.campusName]
                    .filter(Boolean)
                    .join(" — ")}
                </option>
              ))}
            </select>
          </label>
          <button>Continue</button>
        </form>
      )}
    </main>
  );
}
