import { z } from "zod";
export const adminContextSchema = z.object({ organizationId:z.string().uuid(), schoolId:z.string().uuid().nullable(), campusId:z.string().uuid().nullable() }).strict();
export type AdminContextSelection = z.infer<typeof adminContextSchema>;
export type AdminContext = AdminContextSelection & { membershipId:string; organizationName:string; organizationSlug:string; schoolName:string|null; schoolCode:string|null; campusName:string|null; campusCode:string|null; scopeLevel:"organization"|"school"|"campus"; permissionCodes:string[] };
export interface AdminContextService { listMine():Promise<AdminContext[]>; }

const normalizeSlug=(value:string)=>value.trim().toLowerCase().replace(/[^a-z0-9]+/g,"-").replace(/^-+|-+$/g,"");
const normalizeCode=(value:string)=>value.trim().toUpperCase().replace(/[^A-Z0-9]+/g,"-").replace(/^-+|-+$/g,"");
const name=z.string().trim().min(2).max(160).refine(value=>!/[\u0000-\u001f\u007f]/.test(value),"Control characters are not allowed.");
export const organizationOnboardingInputSchema=z.object({name,slug:z.string().transform(normalizeSlug).pipe(z.string().min(2).max(63).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/))}).strict();
export const schoolOnboardingInputSchema=z.object({organizationId:z.string().uuid(),name,code:z.string().transform(normalizeCode).pipe(z.string().min(1).max(32).regex(/^[A-Z0-9]+(?:-[A-Z0-9]+)*$/))}).strict();
export const campusOnboardingInputSchema=z.object({organizationId:z.string().uuid(),schoolId:z.string().uuid(),name,code:z.string().transform(normalizeCode).pipe(z.string().min(1).max(32).regex(/^[A-Z0-9]+(?:-[A-Z0-9]+)*$/))}).strict();
export const onboardingSelectionSchema=z.object({organizationId:z.string().uuid(),schoolId:z.string().uuid().nullable()}).strict();
export const ownedOnboardingOrganizationSchema=z.object({organizationId:z.string().uuid(),organizationName:z.string(),organizationSlug:z.string(),schoolCount:z.number().int().nonnegative(),campusCount:z.number().int().nonnegative(),isComplete:z.boolean(),updatedAt:z.iso.datetime()}).strict();
export const ownedOnboardingSchoolSchema=z.object({schoolId:z.string().uuid(),schoolName:z.string(),schoolCode:z.string(),campusCount:z.number().int().nonnegative(),updatedAt:z.iso.datetime()}).strict();
export const organizationOnboardingStateSchema=z.object({organizationId:z.string().uuid(),organizationName:z.string(),organizationSlug:z.string(),membershipId:z.string().uuid(),selectedSchoolId:z.string().uuid().nullable(),selectedSchoolName:z.string().nullable(),selectedSchoolCode:z.string().nullable(),selectedCampusId:z.string().uuid().nullable(),selectedCampusName:z.string().nullable(),selectedCampusCode:z.string().nullable(),stage:z.enum(["school","school_selection","campus","complete"])}).strict();
export type OrganizationOnboardingInput=z.infer<typeof organizationOnboardingInputSchema>;
export type SchoolOnboardingInput=z.infer<typeof schoolOnboardingInputSchema>;
export type CampusOnboardingInput=z.infer<typeof campusOnboardingInputSchema>;
export type OwnedOnboardingOrganization=z.infer<typeof ownedOnboardingOrganizationSchema>;
export type OwnedOnboardingSchool=z.infer<typeof ownedOnboardingSchoolSchema>;
export type OrganizationOnboardingState=z.infer<typeof organizationOnboardingStateSchema>;
export interface OrganizationOnboardingService{
 listOrganizations():Promise<OwnedOnboardingOrganization[]>;
 listSchools(organizationId:string):Promise<OwnedOnboardingSchool[]>;
 getState(organizationId:string,schoolId?:string|null):Promise<OrganizationOnboardingState|null>;
 bootstrap(requestId:string,input:OrganizationOnboardingInput):Promise<string>;
 createSchool(requestId:string,input:SchoolOnboardingInput):Promise<string>;
 createCampus(requestId:string,input:CampusOnboardingInput):Promise<string>;
}
export const organizationsModule = { name: "organizations" } as const;
