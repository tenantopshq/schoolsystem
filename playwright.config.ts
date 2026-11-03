import { defineConfig } from "@playwright/test";
export default defineConfig({testDir:"tests/e2e",globalSetup:"./tests/e2e/global-setup.ts",fullyParallel:false,workers:1,use:{baseURL:"http://127.0.0.1:3000",trace:"retain-on-failure"},webServer:{command:"npm start",url:"http://127.0.0.1:3000/login",reuseExistingServer:true}});
