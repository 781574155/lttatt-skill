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
    async ({ context, baseURL }, use, testInfo) => {
      if (process.env.COLLECT_E2E_COVERAGE !== "true") {
        await use();
        return;
      }

      if (!baseURL) {
        throw new Error("采集覆盖率需要配置 E2E_TEST_BASE_URL。");
      }

      const coverageOrigin = new URL(baseURL).origin;
      const storagePrefix = `__adminReactE2ECoverage__:${randomUUID()}:`;
      await context.addInitScript(
        ({ coverageOrigin, storagePrefix }) => {
          if (globalThis.location.origin !== coverageOrigin || globalThis.top !== globalThis) {
            return;
          }

          const coverageGlobal = globalThis as typeof globalThis & {
            __coverage__?: Record<string, unknown>;
            __collectE2ECoverage__?: () => void;
          };
          const storageKey = `${storagePrefix}${Date.now()}-${Math.random()}`;
          const collectCoverage = () => {
            const coverage = coverageGlobal.__coverage__;
            if (coverage && Object.keys(coverage).length > 0) {
              globalThis.localStorage.setItem(storageKey, JSON.stringify(coverage));
            }
          };

          // 跨站跳转会销毁当前页面，先同步保存；同一文档重复采集只保留最新快照。
          coverageGlobal.__collectE2ECoverage__ = collectCoverage;
          globalThis.addEventListener("pagehide", collectCoverage);
        },
        { coverageOrigin, storagePrefix },
      );

      await use();

      for (const page of context.pages()) {
        if (page.isClosed()) {
          continue;
        }

        try {
          await page.evaluate((coverageOrigin) => {
            if (globalThis.location.origin !== coverageOrigin) {
              return;
            }

            const coverageGlobal = globalThis as typeof globalThis & {
              __collectE2ECoverage__?: () => void;
            };
            coverageGlobal.__collectE2ECoverage__?.();
          }, coverageOrigin);
        } catch {
          continue;
        }
      }

      const storageState = await context.storageState();
      const snapshots = storageState.origins
        .filter(({ origin }) => origin === coverageOrigin)
        .flatMap(({ localStorage }) => localStorage.filter(({ name }) => name.startsWith(storagePrefix)));
      if (snapshots.length > 0) {
        await mkdir(coverageDirectory, { recursive: true });
      }
      for (const { value } of snapshots) {
        const coverage = JSON.parse(value) as Record<string, unknown>;
        const filename = `${testInfo.workerIndex}-${testInfo.retry}-${randomUUID()}.json`;
        await writeFile(resolve(coverageDirectory, filename), JSON.stringify(normalizeCoveragePaths(coverage)));
      }
    },
    { auto: true },
  ],
});

export { expect };
