"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const items = [
  { href: "/admin", label: "Overview", exact: true },
  { href: "/admin/students", label: "Students", exact: false, permissions: ["students.view"] },
  { href: "/admin/staff", label: "Staff", exact: false, permissions: ["staff_profiles.view", "staff_profiles.manage"] },
  { href: "/admin/access", label: "Access", exact: false, permissions: ["memberships.view", "memberships.manage", "roles.view", "roles.manage"] },
] as const;

export function AdminNavigation({ permissionCodes = [] }: { permissionCodes?: string[] }) {
  const pathname = usePathname();

  return (
    <nav className="admin-navigation" aria-label="Primary navigation">
      <ul>
        {items.filter((item) => !("permissions" in item) || item.permissions.some((permission) => permissionCodes.includes(permission))).map((item) => {
          const active = item.exact ? pathname === item.href : pathname.startsWith(item.href);
          return (
            <li key={item.href}>
              <Link href={item.href} aria-current={active ? "page" : undefined}>
                {item.label}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
