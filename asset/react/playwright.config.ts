import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  fullyParallel: false,
  maxFailures: 1,
  retries: 0,
  timeout: 60000,
  reporter: [["junit", { outputFile: "out/e2e-junit.xml" }]],
  use: {
    baseURL: process.env.E2E_TEST_BASE_URL,
    locale: "zh-CN",
    timezoneId: "Asia/Shanghai",
    navigationTimeout: 60000,
    actionTimeout: 30000,
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
