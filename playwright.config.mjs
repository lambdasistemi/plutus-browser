import { defineConfig, devices } from "@playwright/test";

const port = Number(process.env.PLAYWRIGHT_PORT || "4173");
const baseURL = process.env.PLAYWRIGHT_BASE_URL || `http://127.0.0.1:${port}/`;
const siteDir = process.env.UPLC_SPA_SITE_DIR || "dist";
const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE;

const shellQuote = (value) => `'${String(value).replaceAll("'", "'\\''")}'`;

export default defineConfig({
  testDir: "./test",
  timeout: 90_000,
  expect: {
    timeout: 20_000,
  },
  fullyParallel: false,
  workers: 1,
  reporter: process.env.CI ? "line" : "list",
  use: {
    baseURL,
    ...devices["Desktop Chrome"],
    launchOptions: {
      executablePath,
      args: ["--no-sandbox", "--disable-dev-shm-usage"],
    },
    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },
  webServer: process.env.PLAYWRIGHT_SKIP_WEBSERVER
    ? undefined
    : {
        command: `node scripts/serve-dist.mjs ${port} ${shellQuote(siteDir)}`,
        port,
        timeout: 20_000,
        reuseExistingServer: true,
      },
  projects: [
    {
      name: "chromium",
      use: { browserName: "chromium" },
    },
  ],
});
