import Link from "next/link";
import { redirect } from "next/navigation";
import { AdminNavigation } from "@/components/admin/admin-navigation";
import { resolveSelectedContext } from "@/modules/organizations/application/context";
import { createSupabaseServerClient } from "@/platform/database/supabase-server";
import { signOut } from "../login/actions";

export default async function AdminLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const db = await createSupabaseServerClient();
  const {
    data: { user },
  } = await db.auth.getUser();

  if (!user) redirect("/login");

  const context = await resolveSelectedContext();
  if (!context) redirect("/select-context");

  const scopeLabel = context.campusName ? "Campus context" : context.schoolName ? "School context" : "Organization context";

  return (
    <div className="admin-shell">
      <a className="skip" href="#content">
        Skip to content
      </a>
      <header className="admin-header">
        <Link className="brand" href="/admin" aria-label="School Platform overview">
          <span className="brand-mark" aria-hidden="true">S</span>
          <span>School Platform</span>
        </Link>
        <div className="context-summary" aria-label="Active administrative context">
          <span className="context-label">{scopeLabel}</span>
          <strong>{context.campusName ?? context.schoolName ?? context.organizationName}</strong>
          {(context.schoolName || context.campusName) && <span>{[context.organizationName, context.schoolName].filter(Boolean).join(" · ")}</span>}
        </div>
        <div className="header-actions">
          <Link className="text-button" href="/select-context">Switch context</Link>
          <form action={signOut}>
            <button className="secondary-button" type="submit">Sign out</button>
          </form>
        </div>
      </header>
      <AdminNavigation />
      <main id="content" className="admin-content">{children}</main>
    </div>
  );
}
