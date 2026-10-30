import { randomUUID } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { expect, test as base } from "@playwright/test";

const coverageDirectory = resolve("out/e2e-coverage/raw");

function normalizeSourcePath(sourcePath: string) {
  const normalizedPath = sourcePath.replaceAll("\\", "/");
  const sourceDirectoryIndex = normalizedPath.lastIndexOf("/src/");
  return sourceDirectoryIndex >= 0 ? normalizedPath.slice(sourceDirectoryIndex + 1) : normalizedPath;
}

function normalizeCoveragePaths(coverage: Record<string, unknown>) {
  return Object.fromEntries(
    Object.entries(coverage).map(([sourcePath, value]) => {
      const normalizedSourcePath = normalizeSourcePath(sourcePath);
      if (!value || typeof value !== "object" || Array.isArray(value)) {
        return [normalizedSourcePath, value];
      }

      const fileCoverage = { ...value } as Record<string, unknown>;
      fileCoverage.path = normalizedSourcePath;

      const inputSourceMap = fileCoverage.inputSourceMap;
      if (inputSourceMap && typeof inputSourceMap === "object" && !Array.isArray(inputSourceMap)) {
        const normalizedSourceMap = { ...inputSourceMap } as Record<string, unknown>;
        if (Array.isArray(normalizedSourceMap.sources)) {
          normalizedSourceMap.sources = normalizedSourceMap.sources.map((item) =>
            typeof item === "string" ? normalizeSourcePath(item) : item,
          );
        }
        normalizedSourceMap.sourceRoot = "";
        fileCoverage.inputSourceMap = normalizedSourceMap;
      }

      return [normalizedSourcePath, fileCoverage];
    }),
  );
}

export const test = base.extend<{ collectE2ECoverage: void }>({
  collectE2ECoverage: [
    async ({ context }, use, testInfo) => {
      await use();

      if (process.env.COLLECT_E2E_COVERAGE !== "true") {
        return;
      }

      for (const page of context.pages()) {
        if (page.isClosed()) {
          continue;
        }

        let coverage: Record<string, unknown> | null;
        try {
          coverage = await page.evaluate(() => {
            const coverageGlobal = globalThis as typeof globalThis & {
              __coverage__?: Record<string, unknown>;
            };
            return coverageGlobal.__coverage__ ?? null;
          });
        } catch {
          continue;
        }

        if (!coverage || Object.keys(coverage).length === 0) {
          continue;
        }

        await mkdir(coverageDirectory, { recursive: true });
        const filename = `${testInfo.workerIndex}-${testInfo.retry}-${randomUUID()}.json`;
        await writeFile(resolve(coverageDirectory, filename), JSON.stringify(normalizeCoveragePaths(coverage)));
      }
    },
    { auto: true },
  ],
});

export { expect };
