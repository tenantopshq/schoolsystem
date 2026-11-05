import { randomUUID } from "node:crypto";
import { notFound,redirect } from "next/navigation";
import { resolveSelectedContext } from "@/modules/organizations/application/context";
import { SupabaseStaffService } from "@/modules/staff/infrastructure/supabase-staff-service";
import { StaffForm } from "../staff-form";

export default async function NewStaffProfile(){const context=await resolveSelectedContext();if(!context)redirect("/select-context");if(!context.permissionCodes.includes("staff_profiles.manage"))notFound();const members=await new SupabaseStaffService().eligibleMembers(context);return <><h1>New staff profile</h1><p>Create the employment record now. Platform access can be linked now or later.</p><StaffForm mode="create" requestId={randomUUID()} scope={{schoolId:context.schoolId,campusId:context.campusId}} members={members}/></>}
