import { randomUUID } from "node:crypto";
import { notFound } from "next/navigation";
import { resolveSelectedContextAuthorization } from "@/modules/organizations/application/context";
import { targetHasPermission } from "@/modules/organizations/application/scope";
import { SupabaseStudentService } from "@/modules/students/infrastructure/supabase-student-service";
import { StudentForm } from "../../student-form";

export default async function Edit({ params }: { params: Promise<{ studentId: string }> }) {
  const { studentId } = await params;
  const [student, authorization] = await Promise.all([new SupabaseStudentService().get(studentId), resolveSelectedContextAuthorization()]);
  if (!student || !authorization) notFound();
  const target = { organizationId: authorization.selected.organizationId, schoolId: student.schoolId, campusId: student.campusId };
  if (!targetHasPermission(authorization.selected, authorization.contexts, target, "students.edit")) notFound();
  return <><h1>Edit student</h1><StudentForm mode="update" requestId={randomUUID()} scope={{ id: student.id }} initial={{ studentNumber: student.studentNumber, firstName: student.firstName, middleName: student.middleName ?? "", lastName: student.lastName, preferredName: student.preferredName ?? "", dateOfBirth: student.dateOfBirth, gender: student.gender ?? "", nationalityCode: student.nationalityCode ?? "", primaryLanguage: student.primaryLanguage ?? "", admissionDate: student.admissionDate ?? "", exitDate: student.exitDate ?? "", status: student.status }}/></>;
}
