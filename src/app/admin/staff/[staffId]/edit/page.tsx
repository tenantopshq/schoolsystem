import { randomUUID } from "node:crypto";
import { notFound,redirect } from "next/navigation";
import { resolveSelectedContext } from "@/modules/organizations/application/context";
import { staffProfileIdSchema } from "@/modules/staff";
import { SupabaseStaffService } from "@/modules/staff/infrastructure/supabase-staff-service";
import { StaffForm } from "../../staff-form";

export default async function EditStaffProfile({params}:{params:Promise<{staffId:string}>}){const context=await resolveSelectedContext();if(!context)redirect("/select-context");if(!context.permissionCodes.includes("staff_profiles.manage"))notFound();const parsed=staffProfileIdSchema.safeParse((await params).staffId);if(!parsed.success)notFound();const service=new SupabaseStaffService();const staff=await service.get(context,parsed.data);if(!staff||staff.status==="archived")notFound();const members=staff.organizationMembershipId?[]:await service.eligibleMembers(context);return <><h1>Edit staff profile</h1><StaffForm mode="update" requestId={randomUUID()} scope={{id:staff.id,membershipId:staff.organizationMembershipId}} members={members} initial={{firstName:staff.firstName??"",middleName:staff.middleName??"",lastName:staff.lastName??"",displayName:staff.displayName??"",workEmail:staff.workEmail??"",phone:staff.phone??"",staffNumber:staff.staffNumber,employmentType:staff.employmentType,jobTitle:staff.jobTitle??"",department:staff.department??"",hireDate:staff.hireDate??"",terminationDate:staff.terminationDate??"",status:staff.status}}/></>}
