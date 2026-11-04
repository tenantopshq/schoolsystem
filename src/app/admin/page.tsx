import Link from "next/link";
import { redirect } from "next/navigation";
import { resolveSelectedContext } from "@/modules/organizations/application/context";

export default async function AdminOverview() {
  const context = await resolveSelectedContext();
  if (!context) redirect("/select-context");

  const canViewStudents = context.permissionCodes.includes("students.view");
  const canViewStaff = context.permissionCodes.some((code) => code === "staff_profiles.view" || code === "staff_profiles.manage");

  return (
    <>
      <section className="page-heading">
        <p className="eyebrow">Administration</p>
        <h1>Welcome to {context.schoolName ?? context.organizationName}</h1>
        <p>Use this workspace to manage the records available in your current context.</p>
      </section>
      <section aria-labelledby="workspace-heading">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Workspace</p>
            <h2 id="workspace-heading">Available modules</h2>
          </div>
        </div>
        <div className="module-grid">
          {canViewStudents ? (
            <Link className="module-card" href="/admin/students">
              <span className="module-icon" aria-hidden="true">ST</span>
              <span>
                <strong>Students</strong>
                <small>Find, review, and maintain student records.</small>
              </span>
              <span className="module-arrow" aria-hidden="true">→</span>
            </Link>
          ) : null}
          {canViewStaff ? (
            <Link className="module-card" href="/admin/staff">
              <span className="module-icon" aria-hidden="true">SF</span>
              <span>
                <strong>Staff</strong>
                <small>Browse staff employment profiles in this context.</small>
              </span>
              <span className="module-arrow" aria-hidden="true">→</span>
            </Link>
          ) : null}
          {!canViewStudents && !canViewStaff ? (
            <div className="empty-state">
              <h3>No modules available</h3>
              <p>Your current permissions do not provide access to an administrative module.</p>
            </div>
          ) : null}
        </div>
      </section>
    </>
  );
}
