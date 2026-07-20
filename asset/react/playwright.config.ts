import { defineConfig, devices } from "@playwright/test";

const baseURL = process.env.E2E_TEST_BASE_URL;
if (!baseURL) {
  throw new Error("Missing environment variable: E2E_TEST_BASE_URL");
}
try {
  new URL(baseURL);
} catch {
  throw new Error(`Invalid E2E_TEST_BASE_URL: ${baseURL}`);
}

const isCI = Boolean(process.env.CI);

const slowMo = Number(process.env.PLAYWRIGHT_SLOW_MO ?? "0");
if (!Number.isFinite(slowMo) || slowMo < 0) {
  throw new Error(
    `Invalid PLAYWRIGHT_SLOW_MO: ${process.env.PLAYWRIGHT_SLOW_MO}`,
  );
}

export default defineConfig({
  retries: isCI ? 1 : 0,
  failOnFlakyTests: isCI,
  forbidOnly: isCI,
  timeout: 60_000,
  outputDir: "out/test-results",
  reporter: isCI ? [
    [
      "junit",
      {
        outputFile: "out/e2e-junit.xml",
        stripANSIControlSequences: true,
        includeProjectInTestName: true,
      }
    ],
    [
      "list",
      {
        printSteps: true,
        printFailuresInline: true,
      },
    ],
    [
      "html",
      {
        outputFolder: "out/playwright-report",
        open: "never",
      },
    ],
  ] : [
    [
      "list",
      {
        printSteps: true,
        printFailuresInline: true,
      },
    ],
    [
      "html",
      {
        outputFolder: "out/playwright-report",
        open: "never",
      },
    ],
  ],
  use: {
    baseURL: baseURL,
    locale: "zh-CN",
    timezoneId: "Asia/Shanghai",
    navigationTimeout: 30_000,
    actionTimeout: 10_000,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    launchOptions: {
      slowMo: slowMo,
    },
  },
  expect: {
    timeout: 10_000,
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
