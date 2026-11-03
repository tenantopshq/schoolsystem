import { defineConfig } from "vitest/config";
import path from "node:path";
export default defineConfig({test:{environment:"jsdom",setupFiles:["./src/test/setup.ts"],exclude:["tests/e2e/**","node_modules/**"]},resolve:{alias:{"@":path.resolve(__dirname,"src")}}});
