import { cleanup,render,screen } from "@testing-library/react";
import { afterEach,describe,expect,it,vi } from "vitest";
import { StaffForm } from "./staff-form";

vi.mock("./actions",()=>({createStaffProfile:vi.fn(),updateStaffProfile:vi.fn()}));
afterEach(cleanup);

describe("StaffForm",()=>{
  it("creates an unlinked staff record with directly entered identity",()=>{
    render(<StaffForm mode="create" requestId="10000000-0000-4000-8000-000000000001" scope={{schoolId:null,campusId:null}}/>);
    expect(screen.getByLabelText("Platform access (optional)")).toHaveValue("");
    expect(screen.getByLabelText("First name")).toBeRequired();
    expect(screen.getByLabelText("Work email")).toHaveAttribute("type","email");
  });

  it("preserves an existing link and does not offer relinking",()=>{
    const {container}=render(<StaffForm mode="update" requestId="10000000-0000-4000-8000-000000000001" scope={{id:"20000000-0000-4000-8000-000000000001",membershipId:"30000000-0000-4000-8000-000000000001"}} initial={{firstName:"Ada",lastName:"Lovelace"}}/>);
    expect(screen.queryByLabelText("Platform access (optional)")).not.toBeInTheDocument();
    expect(container.querySelector('input[name="membershipId"]')).toHaveValue("30000000-0000-4000-8000-000000000001");
  });
});
