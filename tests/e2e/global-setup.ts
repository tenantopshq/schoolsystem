import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createClient } from "@supabase/supabase-js";

const users = [
  { id: "a4000000-0000-0000-0000-000000000001", email: "admin-v13@e2e.local" },
  { id: "a4000000-0000-0000-0000-000000000002", email: "denied-v13@e2e.local" },
];

export default async function globalSetup() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const databaseUrl = process.env.DB_URL;
  if (!url || !key || !databaseUrl) throw new Error("Local Supabase environment is required for Playwright");
  if (!["127.0.0.1", "localhost"].includes(new URL(url).hostname) || !databaseUrl.includes("127.0.0.1")) {
    throw new Error("Refusing E2E fixture writes to a non-local Supabase instance");
  }

  const auth = createClient(url, key, { auth: { persistSession: false } }).auth.admin;
  for (const user of users) {
    const created = await auth.createUser({ ...user, password: "V13-test-password!", email_confirm: true });
    if (created.error) {
      const updated = await auth.updateUserById(user.id, { password: "V13-test-password!", email_confirm: true });
      if (updated.error) throw created.error;
    }
  }

  execFileSync("docker", ["exec", "-i", "supabase_db_school-platform", "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1"], {
    input: readFileSync(resolve("tests/e2e/fixtures.sql")),
    stdio: ["pipe", "inherit", "inherit"],
  });
}
