import Link from "next/link";
import { redirect } from "next/navigation";
import { resolveSelectedContextAuthorization } from "@/modules/organizations/application/context";
import { parseStudentDirectoryQuery } from "@/modules/students";
import { constrainDirectoryQuery } from "@/modules/students/application/directory-scope";
import { SupabaseStudentService } from "@/modules/students/infrastructure/supabase-student-service";

export default async function Students({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const authorization = await resolveSelectedContextAuthorization();
  if (!authorization) redirect("/select-context");
  const context = authorization.selected;
  const query = constrainDirectoryQuery(context, authorization.contexts, parseStudentDirectoryQuery(await searchParams));
  const page = await new SupabaseStudentService().search(context, query);
  const canonical = Object.fromEntries(Object.entries({ q: query.q, status: query.status, school: query.school ?? undefined, campus: query.campus ?? undefined, sort: query.sort, dir: query.dir }).filter((entry): entry is [string, string] => typeof entry[1] === "string"));
  return <><div className="title-row"><h1>Students</h1>{context.schoolId && context.permissionCodes.includes("students.create") && <Link className="button" href="/admin/students/new">New student</Link>}</div><form method="get" className="filters"><label>Search<input name="q" defaultValue={query.q}/></label><label>Status<select name="status" defaultValue={query.status}><option value="active">Active</option><option value="inactive">Inactive</option><option value="archived">Archived</option><option value="all">All</option></select></label><button>Apply</button></form><p>{page.totalCount} students</p>{page.items.length === 0 ? <p>No students match these filters.</p> : <><table><thead><tr><th>Name</th><th>Student number</th><th>School</th><th>Campus</th><th>Status</th></tr></thead><tbody>{page.items.map((student) => <tr key={student.id}><td><Link href={`/admin/students/${student.id}`}>{student.preferredName || student.firstName} {student.lastName}</Link></td><td>{student.studentNumber}</td><td>{student.schoolName}</td><td>{student.campusName ?? "—"}</td><td><span className={`status ${student.status}`}>{student.status}</span></td></tr>)}</tbody></table>{page.nextCursor && <Link href={`?${new URLSearchParams({ ...canonical, after: page.nextCursor })}`}>Next page</Link>}</>}</>;
}
