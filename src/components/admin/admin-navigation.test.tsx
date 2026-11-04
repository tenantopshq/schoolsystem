import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminNavigation } from "./admin-navigation";

const navigation = vi.hoisted(() => ({ pathname: "/admin" }));

vi.mock("next/navigation", () => ({ usePathname: () => navigation.pathname }));

afterEach(cleanup);

describe("AdminNavigation", () => {
  it("marks overview as current on the admin landing page", () => {
    navigation.pathname = "/admin";
    render(<AdminNavigation />);

    expect(screen.getByRole("link", { name: "Overview" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByRole("link", { name: "Students" })).not.toHaveAttribute("aria-current");
  });

  it("keeps students current on nested student routes", () => {
    navigation.pathname = "/admin/students/student-id/edit";
    render(<AdminNavigation />);

    expect(screen.getByRole("link", { name: "Students" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByRole("link", { name: "Overview" })).not.toHaveAttribute("aria-current");
  });
});
