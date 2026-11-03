import { describe,expect,it } from "vitest";
import { studentDirectoryQuerySchema } from "./index";
describe("student directory query",()=>{it("applies safe defaults",()=>{expect(studentDirectoryQuerySchema.parse({})).toMatchObject({status:"active",sort:"name",dir:"asc",after:null})});it("rejects unknown sort",()=>{expect(()=>studentDirectoryQuerySchema.parse({sort:"sql"})).toThrow()});});
