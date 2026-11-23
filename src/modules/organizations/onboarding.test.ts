import { describe,expect,it } from "vitest";
import { campusOnboardingInputSchema,organizationOnboardingInputSchema,schoolOnboardingInputSchema } from "./index";

const organizationId="10000000-0000-4000-8000-000000000001";
const schoolId="20000000-0000-4000-8000-000000000001";
describe("organization onboarding contracts",()=>{
 it("normalizes canonical slugs and codes",()=>{expect(organizationOnboardingInputSchema.parse({name:"  Alpha Group  ",slug:" Alpha   Group "})).toEqual({name:"Alpha Group",slug:"alpha-group"});expect(schoolOnboardingInputSchema.parse({organizationId,name:"Main School",code:" main school "}).code).toBe("MAIN-SCHOOL");expect(campusOnboardingInputSchema.parse({organizationId,schoolId,name:"Main Campus",code:" north_1 "}).code).toBe("NORTH-1");});
 it("rejects malformed and extra input",()=>{expect(organizationOnboardingInputSchema.safeParse({name:"X",slug:"---"}).success).toBe(false);expect(schoolOnboardingInputSchema.safeParse({organizationId,name:"School",code:"A",roleId:schoolId}).success).toBe(false);expect(campusOnboardingInputSchema.safeParse({organizationId,schoolId,name:"Campus",code:"***"}).success).toBe(false);});
});
