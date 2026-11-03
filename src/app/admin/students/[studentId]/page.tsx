import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound } from "next/navigation";
import { resolveSelectedContextAuthorization } from "@/modules/organizations/application/context";
import { targetHasPermission } from "@/modules/organizations/application/scope";
import type { StudentDocumentMetadata, StudentEnrollment, StudentGuardianLink } from "@/modules/students";
import { SupabaseStudentService } from "@/modules/students/infrastructure/supabase-student-service";
import { ArchiveDialog } from "../archive-dialog";

export default async function StudentDetail({ params }: { params: Promise<{ studentId: string }> }) {
  const { studentId } = await params;
  const [student, authorization] = await Promise.all([new SupabaseStudentService().get(studentId), resolveSelectedContextAuthorization()]);
  if (!student || !authorization) notFound();
  const target = { organizationId: authorization.selected.organizationId, schoolId: student.schoolId, campusId: student.campusId };
  if (!targetHasPermission(authorization.selected, authorization.contexts, target, "students.view")) notFound();
  const canEdit = targetHasPermission(authorization.selected, authorization.contexts, target, "students.edit");
  const canArchive = targetHasPermission(authorization.selected, authorization.contexts, target, "students.archive");
  const displayName = `${student.preferredName || student.firstName} ${student.lastName}`;
  return <><div className="title-row"><div><p><Link href="/admin/students">Students</Link></p><h1>{displayName}</h1></div>{canEdit && <Link className="button" href={`/admin/students/${student.id}/edit`}>Edit</Link>}</div><dl><dt>Student number</dt><dd>{student.studentNumber}</dd><dt>Status</dt><dd>{student.status}</dd><dt>Date of birth</dt><dd>{student.dateOfBirth}</dd><dt>School</dt><dd>{student.schoolName}</dd><dt>Campus</dt><dd>{student.campusName ?? "—"}</dd></dl><h2>Enrollment history</h2><EnrollmentList items={student.enrollments}/><h2>Guardian links</h2><GuardianList items={student.guardianLinks}/><h2>Documents</h2><DocumentList items={student.documents}/>{canArchive && student.status !== "archived" && <ArchiveDialog studentId={student.id} studentName={displayName} requestId={randomUUID()}/>}</>;
}

function EnrollmentList({items}:{items:StudentEnrollment[]}){return items.length?<ul>{items.map(item=><li key={item.id}><strong>{item.academic_year_name} — {item.grade_level_name}</strong><div>{item.enrolled_on} to {item.ended_on??item.scheduled_end_on} · {item.status}</div>{item.placements.length>0&&<ul>{item.placements.map(p=><li key={p.id}>{p.section_name} · {p.campus_name} · {p.starts_on} to {p.ends_on??"present"} · {p.status}</li>)}</ul>}</li>)}</ul>:<p>None.</p>}
function GuardianList({items}:{items:StudentGuardianLink[]}){return items.length?<ul>{items.map(item=><li key={item.link_id}>{item.first_name} {item.middle_name?`${item.middle_name} `:""}{item.last_name} · {item.relationship_type} · {item.status}{item.is_primary?" · primary":""}</li>)}</ul>:<p>None.</p>}
function DocumentList({items}:{items:StudentDocumentMetadata[]}){return items.length?<ul>{items.map(item=><li key={item.id}>{item.title} · {item.document_type} · {item.status}{item.issued_at?` · issued ${item.issued_at}`:""}</li>)}</ul>:<p>None.</p>}
