import { z } from "zod";
export const adminContextSchema = z.object({ organizationId:z.string().uuid(), schoolId:z.string().uuid().nullable(), campusId:z.string().uuid().nullable() }).strict();
export type AdminContextSelection = z.infer<typeof adminContextSchema>;
export type AdminContext = AdminContextSelection & { membershipId:string; organizationName:string; organizationSlug:string; schoolName:string|null; schoolCode:string|null; campusName:string|null; campusCode:string|null; scopeLevel:"organization"|"school"|"campus"; permissionCodes:string[] };
export interface AdminContextService { listMine():Promise<AdminContext[]>; }
export const organizationsModule = { name: "organizations" } as const;
