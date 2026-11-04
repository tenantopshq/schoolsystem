import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminNavigation } from "./admin-navigation";

const navigation = vi.hoisted(() => ({ pathname: "/admin" }));

vi.mock("next/navigation", () => ({ usePathname: () => navigation.pathname }));

afterEach(cleanup);

describe("AdminNavigation", () => {
  it("marks overview as current on the admin landing page", () => {
    navigation.pathname = "/admin";
    render(<AdminNavigation permissionCodes={["students.view", "staff_profiles.view"]} />);

    expect(screen.getByRole("link", { name: "Overview" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByRole("link", { name: "Students" })).not.toHaveAttribute("aria-current");
  });

  it("keeps students current on nested student routes", () => {
    navigation.pathname = "/admin/students/student-id/edit";
    render(<AdminNavigation permissionCodes={["students.view"]} />);

    expect(screen.getByRole("link", { name: "Students" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByRole("link", { name: "Overview" })).not.toHaveAttribute("aria-current");
  });

  it("hides modules outside the effective context permissions", () => {
    navigation.pathname = "/admin";
    render(<AdminNavigation permissionCodes={["staff_profiles.view"]} />);

    expect(screen.queryByRole("link", { name: "Students" })).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Staff" })).toBeInTheDocument();
  });

  it("shows staff navigation for manage-only contexts", () => {
    navigation.pathname = "/admin/staff";
    render(<AdminNavigation permissionCodes={["staff_profiles.manage"]} />);

    expect(screen.getByRole("link", { name: "Staff" })).toHaveAttribute("aria-current", "page");
  });
});
