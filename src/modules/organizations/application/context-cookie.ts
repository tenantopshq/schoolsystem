import { createHmac, timingSafeEqual } from "node:crypto";
import { adminContextSchema, type AdminContext, type AdminContextSelection } from "../index";

const signature = (body: string, secret: string) => createHmac("sha256", secret).update(body).digest("base64url");

export function encodeContextCookie(value: AdminContextSelection, secret: string): string {
  const body = Buffer.from(JSON.stringify(adminContextSchema.parse(value))).toString("base64url");
  return `${body}.${signature(body, secret)}`;
}

export function decodeContextCookie(value: string, secret: string): AdminContextSelection | null {
  try {
    const [body, supplied, ...extra] = value.split(".");
    if (!body || !supplied || extra.length) return null;
    const expected = signature(body, secret);
    if (supplied.length !== expected.length || !timingSafeEqual(Buffer.from(supplied), Buffer.from(expected))) return null;
    const parsed = adminContextSchema.safeParse(JSON.parse(Buffer.from(body, "base64url").toString("utf8")));
    return parsed.success ? parsed.data : null;
  } catch { return null; }
}

export function reauthorizeContext(selection: AdminContextSelection, contexts: AdminContext[]): AdminContext | null {
  return contexts.find((context) => context.organizationId === selection.organizationId && context.schoolId === selection.schoolId && context.campusId === selection.campusId) ?? null;
}
