import Link from "next/link";
import { redirect } from "next/navigation";
import { resolveSelectedContext } from "@/modules/organizations/application/context";
import { formatStaffName, parseStaffDirectoryQuery } from "@/modules/staff";
import { SupabaseStaffService } from "@/modules/staff/infrastructure/supabase-staff-service";

export default async function StaffDirectory({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const context = await resolveSelectedContext();
  if (!context) redirect("/select-context");
  if (!context.permissionCodes.some((code) => code === "staff_profiles.view" || code === "staff_profiles.manage")) redirect("/admin");

  const query = parseStaffDirectoryQuery(await searchParams);
  const page = await new SupabaseStaffService().search(context, query);
  const canonical = Object.fromEntries(Object.entries({ q: query.q, status: query.status }).filter((entry): entry is [string, string] => typeof entry[1] === "string"));

  return <>
    <div className="title-row"><div><p className="eyebrow">People</p><h1>Staff</h1></div></div>
    <form method="get" className="filters">
      <label>Search<input name="q" defaultValue={query.q} placeholder="Name, number, title, or department" /></label>
      <label>Status<select name="status" defaultValue={query.status}><option value="active">Active</option><option value="inactive">Inactive</option><option value="archived">Archived</option><option value="all">All</option></select></label>
      <button type="submit">Apply</button>
    </form>
    <p>{page.totalCount} staff profiles</p>
    {page.items.length === 0 ? <div className="empty-state"><h2>No staff found</h2><p>No staff profiles match these filters in the current context.</p></div> : <>
      <div className="table-wrap"><table><thead><tr><th>Name</th><th>Staff number</th><th>Role</th><th>Department</th><th>Home context</th><th>Status</th></tr></thead><tbody>
        {page.items.map((staff) => <tr key={staff.id}><td><Link href={`/admin/staff/${staff.id}`}>{formatStaffName(staff)}</Link></td><td>{staff.staffNumber}</td><td>{staff.jobTitle ?? staff.employmentType}</td><td>{staff.department ?? "—"}</td><td>{staff.campusName ?? staff.schoolName ?? "Organization"}</td><td><span className={`status ${staff.status}`}>{staff.status}</span></td></tr>)}
      </tbody></table></div>
      {page.nextCursor && <Link className="pagination-link" href={`?${new URLSearchParams({ ...canonical, after: page.nextCursor })}`}>Next page</Link>}
    </>}
  </>;
}
