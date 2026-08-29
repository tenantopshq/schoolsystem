import { z } from "zod";

import type { Database } from "../../platform/database/database.types";

export const studentStatusSchema = z.enum(["active", "inactive", "archived"]);
export const mutableStudentStatusSchema = z.enum(["active", "inactive"]);
export const studentDocumentVisibilitySchema = z.enum([
  "admin_only",
  "staff",
  "guardian",
  "student",
]);

const uuidSchema = z.string().uuid();
const dateSchema = z.string().date();
const nullableDateSchema = dateSchema.nullable();
const nullableTextSchema = (max: number) => z.string().trim().min(1).max(max).nullable();
const countryCodeSchema = z.string().length(2).toUpperCase();
const nullableCountryCodeSchema = countryCodeSchema.nullable();
const statusSchema = mutableStudentStatusSchema;
const archiveSchema = z.object({ id: uuidSchema, archiveReason: z.string().trim().min(1) }).strict();

export const createStudentSchema = z.object({
  schoolId: uuidSchema,
  campusId: uuidSchema.nullable(),
  studentNumber: z.string().trim().min(1).max(48),
  firstName: z.string().trim().min(1).max(100),
  middleName: nullableTextSchema(100),
  lastName: z.string().trim().min(1).max(100),
  preferredName: nullableTextSchema(100),
  dateOfBirth: dateSchema,
  gender: nullableTextSchema(40),
  nationalityCode: nullableCountryCodeSchema,
  primaryLanguage: nullableTextSchema(100),
  photoPath: nullableTextSchema(500),
  admissionDate: nullableDateSchema,
  exitDate: nullableDateSchema,
  status: statusSchema.default("active"),
}).strict();

export const updateStudentSchema = z.object({
  id: uuidSchema,
  studentNumber: z.string().trim().min(1).max(48),
  firstName: z.string().trim().min(1).max(100),
  middleName: nullableTextSchema(100), setMiddleName: z.boolean(),
  lastName: z.string().trim().min(1).max(100),
  preferredName: nullableTextSchema(100), setPreferredName: z.boolean(),
  dateOfBirth: dateSchema,
  gender: nullableTextSchema(40), setGender: z.boolean(),
  nationalityCode: nullableCountryCodeSchema, setNationalityCode: z.boolean(),
  primaryLanguage: nullableTextSchema(100), setPrimaryLanguage: z.boolean(),
  photoPath: nullableTextSchema(500), setPhotoPath: z.boolean(),
  admissionDate: nullableDateSchema, setAdmissionDate: z.boolean(),
  exitDate: nullableDateSchema, setExitDate: z.boolean(),
  status: statusSchema,
  schoolId: uuidSchema.nullable(), setSchoolId: z.boolean(),
  campusId: uuidSchema.nullable(), setCampusId: z.boolean(),
}).strict();

const guardianFields = {
  firstName: z.string().trim().min(1).max(100),
  middleName: nullableTextSchema(100),
  lastName: z.string().trim().min(1).max(100),
  email: nullableTextSchema(320),
  phone: nullableTextSchema(40),
  alternatePhone: nullableTextSchema(40),
  occupation: nullableTextSchema(120),
  preferredLanguage: nullableTextSchema(100),
} as const;

const linkFields = {
  relationshipType: z.string().trim().min(1).max(40),
  isPrimary: z.boolean(),
  hasPortalAccess: z.boolean(),
  receivesAcademicUpdates: z.boolean(),
  receivesAttendanceAlerts: z.boolean(),
  financialResponsibility: z.boolean(),
  pickupAuthorized: z.boolean(),
} as const;

export const createGuardianForStudentSchema = z.object({
  studentId: uuidSchema,
  ...guardianFields,
  ...linkFields,
}).strict();

export const updateGuardianSchema = z.object({
  id: uuidSchema,
  ...guardianFields,
  setMiddleName: z.boolean(), setEmail: z.boolean(), setPhone: z.boolean(),
  setAlternatePhone: z.boolean(), setOccupation: z.boolean(),
  setPreferredLanguage: z.boolean(), status: statusSchema,
}).strict();

export const linkGuardianToStudentSchema = z.object({
  studentId: uuidSchema,
  guardianId: uuidSchema,
  ...linkFields,
}).strict();

export const updateStudentGuardianSchema = z.object({
  id: uuidSchema,
  ...linkFields,
  status: statusSchema,
}).strict();

export const createStudentIdentifierSchema = z.object({
  studentId: uuidSchema,
  identifierType: z.string().trim().min(1).max(40),
  identifierValue: z.string().trim().min(1).max(160),
  countryCode: nullableCountryCodeSchema,
  issuedAt: nullableDateSchema,
  expiresAt: nullableDateSchema,
  status: statusSchema.default("active"),
}).strict();

export const updateStudentIdentifierSchema = z.object({
  id: uuidSchema,
  identifierType: z.string().trim().min(1).max(40),
  identifierValue: z.string().trim().min(1).max(160),
  countryCode: nullableCountryCodeSchema, setCountryCode: z.boolean(),
  issuedAt: nullableDateSchema, setIssuedAt: z.boolean(),
  expiresAt: nullableDateSchema, setExpiresAt: z.boolean(),
  status: statusSchema,
}).strict();

export const createStudentAddressSchema = z.object({
  studentId: uuidSchema,
  addressType: z.string().trim().min(1).max(40),
  line1: z.string().trim().min(1).max(200),
  line2: nullableTextSchema(200),
  city: z.string().trim().min(1).max(100),
  stateRegion: nullableTextSchema(100),
  postalCode: nullableTextSchema(40),
  countryCode: countryCodeSchema,
  isPrimary: z.boolean(),
  status: statusSchema.default("active"),
}).strict();

export const updateStudentAddressSchema = z.object({
  id: uuidSchema,
  addressType: z.string().trim().min(1).max(40),
  line1: z.string().trim().min(1).max(200),
  line2: nullableTextSchema(200), setLine2: z.boolean(),
  city: z.string().trim().min(1).max(100),
  stateRegion: nullableTextSchema(100), setStateRegion: z.boolean(),
  postalCode: nullableTextSchema(40), setPostalCode: z.boolean(),
  countryCode: countryCodeSchema,
  isPrimary: z.boolean(),
  status: statusSchema,
}).strict();

export const createStudentEmergencyContactSchema = z.object({
  studentId: uuidSchema,
  guardianId: uuidSchema.nullable(),
  name: z.string().trim().min(1).max(160),
  relationship: z.string().trim().min(1).max(40),
  phone: z.string().trim().min(3).max(40),
  alternatePhone: nullableTextSchema(40),
  priority: z.number().int().min(1).max(20),
  status: statusSchema.default("active"),
}).strict();

export const updateStudentEmergencyContactSchema = z.object({
  id: uuidSchema,
  guardianId: uuidSchema.nullable(), setGuardianId: z.boolean(),
  name: z.string().trim().min(1).max(160),
  relationship: z.string().trim().min(1).max(40),
  phone: z.string().trim().min(3).max(40),
  alternatePhone: nullableTextSchema(40), setAlternatePhone: z.boolean(),
  priority: z.number().int().min(1).max(20),
  status: statusSchema,
}).strict();

export const createStudentDocumentSchema = z.object({
  uploadIntentId: uuidSchema,
  documentType: z.string().trim().min(1).max(60),
  title: z.string().trim().min(1).max(160),
  mimeType: nullableTextSchema(255),
  fileSize: z.number().int().nonnegative().nullable(),
  issuedAt: nullableDateSchema,
  expiresAt: nullableDateSchema,
  visibility: studentDocumentVisibilitySchema,
  status: statusSchema.default("active"),
}).strict();

export const updateStudentDocumentSchema = z.object({
  id: uuidSchema,
  documentType: z.string().trim().min(1).max(60),
  title: z.string().trim().min(1).max(160),
  mimeType: nullableTextSchema(255), setMimeType: z.boolean(),
  fileSize: z.number().int().nonnegative().nullable(), setFileSize: z.boolean(),
  issuedAt: nullableDateSchema, setIssuedAt: z.boolean(),
  expiresAt: nullableDateSchema, setExpiresAt: z.boolean(),
  visibility: studentDocumentVisibilitySchema,
  status: statusSchema,
}).strict();

export const archiveStudentSchema = archiveSchema.extend({ targetStudentId: uuidSchema }).omit({ id: true }).strict();
export const archiveGuardianSchema = archiveSchema;
export const archiveStudentGuardianSchema = archiveSchema;
export const archiveStudentIdentifierSchema = archiveSchema;
export const archiveStudentAddressSchema = archiveSchema;
export const archiveStudentEmergencyContactSchema = archiveSchema;
export const archiveStudentDocumentSchema = archiveSchema;

export type CreateStudentInput = z.infer<typeof createStudentSchema>;
export type UpdateStudentInput = z.infer<typeof updateStudentSchema>;
export type ArchiveStudentInput = z.infer<typeof archiveStudentSchema>;
export type CreateGuardianForStudentInput = z.infer<typeof createGuardianForStudentSchema>;
export type UpdateGuardianInput = z.infer<typeof updateGuardianSchema>;
export type LinkGuardianToStudentInput = z.infer<typeof linkGuardianToStudentSchema>;
export type UpdateStudentGuardianInput = z.infer<typeof updateStudentGuardianSchema>;
export type CreateStudentIdentifierInput = z.infer<typeof createStudentIdentifierSchema>;
export type UpdateStudentIdentifierInput = z.infer<typeof updateStudentIdentifierSchema>;
export type CreateStudentAddressInput = z.infer<typeof createStudentAddressSchema>;
export type UpdateStudentAddressInput = z.infer<typeof updateStudentAddressSchema>;
export type CreateStudentEmergencyContactInput = z.infer<typeof createStudentEmergencyContactSchema>;
export type UpdateStudentEmergencyContactInput = z.infer<typeof updateStudentEmergencyContactSchema>;
export type CreateStudentDocumentInput = z.infer<typeof createStudentDocumentSchema>;
export type UpdateStudentDocumentInput = z.infer<typeof updateStudentDocumentSchema>;
export type ArchiveInput = z.infer<typeof archiveSchema>;

type PublicFunctions = Database["public"]["Functions"];

export const sisRpcNames = [
  "create_student", "update_student", "archive_student",
  "create_guardian_for_student", "update_guardian", "archive_guardian",
  "link_guardian_to_student", "update_student_guardian", "archive_student_guardian",
  "create_student_identifier", "update_student_identifier", "archive_student_identifier",
  "create_student_address", "update_student_address", "archive_student_address",
  "create_student_emergency_contact", "update_student_emergency_contact", "archive_student_emergency_contact",
  "create_student_document", "update_student_document", "archive_student_document",
] as const satisfies readonly (keyof PublicFunctions)[];

export type SisRpcName = (typeof sisRpcNames)[number];
export type SisRpcArgs<Name extends SisRpcName> = PublicFunctions[Name]["Args"];
export type SisRpcResult<Name extends SisRpcName> = PublicFunctions[Name]["Returns"];
export type CreateGuardianResult = SisRpcResult<"create_guardian_for_student">[number];

export const sisEventTypes = [
  "student.created", "student.updated", "student.archived",
  "guardian.created", "guardian.updated", "guardian.archived",
  "student.guardian_linked", "student.guardian_updated", "student.guardian_unlinked",
  "student.identifier_added", "student.identifier_updated", "student.identifier_archived",
  "student.address_added", "student.address_updated", "student.address_archived",
  "student.emergency_contact_added", "student.emergency_contact_updated", "student.emergency_contact_archived",
  "student.document_added", "student.document_updated", "student.document_archived",
] as const;

export type SisEventType = (typeof sisEventTypes)[number];

export const sisPermissionCodes = [
  "students.view", "students.create", "students.edit", "students.archive",
  "students.sensitive_view", "students.sensitive_manage", "student_documents.manage",
] as const;

export type SisPermissionCode = (typeof sisPermissionCodes)[number];

export type SisCommandErrorCode = "22023" | "23503" | "23505" | "40001" | "42501" | "P0002";

/** A 40001 result means authoritative scope or guardian links changed while locking. */
export const isRetryableSisCommandError = (error: { code?: string } | null | undefined) =>
  error?.code === "40001";

export interface SisCommandService {
  createStudent(input: CreateStudentInput): Promise<string>;
  updateStudent(input: UpdateStudentInput): Promise<string>;
  archiveStudent(input: ArchiveStudentInput): Promise<string>;
  createGuardianForStudent(input: CreateGuardianForStudentInput): Promise<CreateGuardianResult>;
  updateGuardian(input: UpdateGuardianInput): Promise<string>;
  archiveGuardian(input: ArchiveInput): Promise<string>;
  linkGuardianToStudent(input: LinkGuardianToStudentInput): Promise<string>;
  updateStudentGuardian(input: UpdateStudentGuardianInput): Promise<string>;
  archiveStudentGuardian(input: ArchiveInput): Promise<string>;
  createStudentIdentifier(input: CreateStudentIdentifierInput): Promise<string>;
  updateStudentIdentifier(input: UpdateStudentIdentifierInput): Promise<string>;
  archiveStudentIdentifier(input: ArchiveInput): Promise<string>;
  createStudentAddress(input: CreateStudentAddressInput): Promise<string>;
  updateStudentAddress(input: UpdateStudentAddressInput): Promise<string>;
  archiveStudentAddress(input: ArchiveInput): Promise<string>;
  createStudentEmergencyContact(input: CreateStudentEmergencyContactInput): Promise<string>;
  updateStudentEmergencyContact(input: UpdateStudentEmergencyContactInput): Promise<string>;
  archiveStudentEmergencyContact(input: ArchiveInput): Promise<string>;
  createStudentDocument(input: CreateStudentDocumentInput): Promise<string>;
  updateStudentDocument(input: UpdateStudentDocumentInput): Promise<string>;
  archiveStudentDocument(input: ArchiveInput): Promise<string>;
}

/** Public boundary for SIS services. Persistence adapters remain private. */
export const studentsModule = {
  name: "students",
  rpcNames: sisRpcNames,
  eventTypes: sisEventTypes,
  permissionCodes: sisPermissionCodes,
} as const;
