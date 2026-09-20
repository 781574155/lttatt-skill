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
  throw new Error(`Invalid PLAYWRIGHT_SLOW_MO: ${process.env.PLAYWRIGHT_SLOW_MO}`);
}

export default defineConfig({
  fullyParallel: isCI,
  workers: isCI ? 64 : undefined,
  retries: isCI ? 1 : 0,
  forbidOnly: isCI,
  timeout: isCI ? 120_000 : 0,
  outputDir: "out/test-results",
  reporter: isCI
    ? [
        [
          "junit",
          {
            outputFile: "out/e2e-junit.xml",
            stripANSIControlSequences: true,
            includeProjectInTestName: true,
          },
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
      ]
    : [
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
    extraHTTPHeaders: {
      "X-Execution-Mode": "CI",
    },
    locale: "zh-CN",
    timezoneId: "Asia/Shanghai",
    navigationTimeout: 30_000,
    actionTimeout: 20_000,
    trace: isCI ? "on-first-retry" : "retain-on-failure",
    screenshot: "only-on-failure",
    launchOptions: {
      slowMo: slowMo,
    },
  },
  expect: {
    timeout: 20_000,
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
