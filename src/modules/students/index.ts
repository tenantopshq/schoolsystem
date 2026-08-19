import { z } from "zod";

export const studentStatusSchema = z.enum(["active", "inactive", "archived"]);

export const createStudentSchema = z.object({
  organizationId: z.string().uuid(),
  schoolId: z.string().uuid(),
  campusId: z.string().uuid().nullable().optional(),
  studentNumber: z.string().trim().min(1).max(48),
  firstName: z.string().trim().min(1).max(100),
  middleName: z.string().trim().max(100).nullable().optional(),
  lastName: z.string().trim().min(1).max(100),
  preferredName: z.string().trim().max(100).nullable().optional(),
  dateOfBirth: z.string().date(),
  gender: z.string().trim().min(1).max(40).nullable().optional(),
  nationalityCode: z.string().length(2).toUpperCase().nullable().optional(),
  primaryLanguage: z.string().trim().max(40).nullable().optional(),
  admissionDate: z.string().date().nullable().optional(),
});

export type CreateStudentInput = z.infer<typeof createStudentSchema>;

/** Public boundary for SIS services. Persistence stays private to this module. */
export const studentsModule = { name: "students" } as const;
