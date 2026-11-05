import { randomUUID } from "node:crypto";
import { notFound,redirect } from "next/navigation";
import { resolveSelectedContext } from "@/modules/organizations/application/context";
import { staffProfileIdSchema } from "@/modules/staff";
import { SupabaseStaffService } from "@/modules/staff/infrastructure/supabase-staff-service";
import { StaffForm } from "../../staff-form";

export default async function EditStaffProfile({params}:{params:Promise<{staffId:string}>}){const context=await resolveSelectedContext();if(!context)redirect("/select-context");if(!context.permissionCodes.includes("staff_profiles.manage"))notFound();const parsed=staffProfileIdSchema.safeParse((await params).staffId);if(!parsed.success)notFound();const staff=await new SupabaseStaffService().get(context,parsed.data);if(!staff||staff.status==="archived")notFound();return <><h1>Edit staff profile</h1><StaffForm mode="update" requestId={randomUUID()} scope={{id:staff.id}} initial={{staffNumber:staff.staffNumber,employmentType:staff.employmentType,jobTitle:staff.jobTitle??"",department:staff.department??"",hireDate:staff.hireDate??"",terminationDate:staff.terminationDate??"",status:staff.status}}/></>}
