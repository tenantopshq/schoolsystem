import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { resolveSelectedContext } from "@/modules/organizations/application/context";
import { StudentForm } from "../student-form";

export default async function NewStudent() {
  const context = await resolveSelectedContext();
  if (!context) redirect("/select-context");
  if (!context.schoolId || !context.permissionCodes.includes("students.create")) notFound();
  return <><h1>New student</h1><StudentForm mode="create" requestId={randomUUID()} scope={{ schoolId: context.schoolId, campusId: context.campusId ?? "" }}/></>;
}
