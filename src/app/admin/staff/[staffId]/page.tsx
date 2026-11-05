import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { resolveSelectedContext } from "@/modules/organizations/application/context";
import { formatStaffName, staffProfileIdSchema } from "@/modules/staff";
import { SupabaseStaffService } from "@/modules/staff/infrastructure/supabase-staff-service";
import { ArchiveStaffDialog } from "../archive-dialog";

export default async function StaffDetail({ params }: { params: Promise<{ staffId: string }> }) {
  const context = await resolveSelectedContext();
  if (!context) redirect("/select-context");
  if (!context.permissionCodes.some((code) => code === "staff_profiles.view" || code === "staff_profiles.manage")) notFound();

  const { staffId } = await params;
  const parsedId = staffProfileIdSchema.safeParse(staffId);
  if (!parsedId.success) notFound();
  const staff = await new SupabaseStaffService().get(context, parsedId.data);
  if (!staff) notFound();

  return <>
    <Link className="back-link" href="/admin/staff">← Back to staff</Link>
    <div className="title-row"><div><p className="eyebrow">Staff profile</p><h1>{formatStaffName(staff)}</h1><p>{staff.staffNumber}</p></div><div>{context.permissionCodes.includes("staff_profiles.manage")&&staff.status!=="archived"&&<Link className="button" href={`/admin/staff/${staff.id}/edit`}>Edit</Link>} <span className={`status ${staff.status}`}>{staff.status}</span></div></div>
    <section aria-labelledby="employment-heading"><h2 id="employment-heading">Employment details</h2><dl>
      <dt>Job title</dt><dd>{staff.jobTitle ?? "—"}</dd>
      <dt>Department</dt><dd>{staff.department ?? "—"}</dd>
      <dt>Employment type</dt><dd>{staff.employmentType}</dd>
      <dt>School</dt><dd>{staff.schoolName ?? "Organization-wide"}</dd>
      <dt>Campus</dt><dd>{staff.campusName ?? "—"}</dd>
      <dt>Hire date</dt><dd>{staff.hireDate ?? "—"}</dd>
      <dt>Termination date</dt><dd>{staff.terminationDate ?? "—"}</dd>
    </dl></section>
    {context.permissionCodes.includes("staff_profiles.manage") && staff.status !== "archived" && (
      <ArchiveStaffDialog staffId={staff.id} staffName={formatStaffName(staff)} requestId={randomUUID()} />
    )}
  </>;
}
