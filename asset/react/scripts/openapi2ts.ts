import { cp, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import { generateService } from "@easyfollow/openapi";
import { format, resolveConfig } from "prettier";
import configs from "../openapi2ts.config.ts";

async function formatService(directory: string) {
  const options = await resolveConfig(resolve(".prettierrc"));
  for (const file of await readdir(directory)) {
    if (file.endsWith(".ts")) {
      const filePath = join(directory, file);
      const source = await readFile(filePath, "utf8");
      await writeFile(filePath, await format(source, { ...options, filepath: filePath }));
    }
  }
}

async function writeChangedFile(sourcePath: string, targetPath: string) {
  const source = await readFile(sourcePath);
  let current: Buffer | undefined;
  try {
    current = await readFile(targetPath);
  } catch (error) {
    if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) {
      throw error;
    }
  }
  if (!current || !source.equals(current)) {
    await writeFile(targetPath, source);
  }
}

async function syncDirectory(sourceDirectory: string, targetDirectory: string) {
  const entries = await readdir(sourceDirectory, { withFileTypes: true });
  const names = new Set(entries.map((entry) => entry.name));
  await mkdir(targetDirectory, { recursive: true });

  // Windows 下开发服务可能占用目录句柄，保留目录并原位更新文件。
  for (const entry of entries) {
    const sourcePath = join(sourceDirectory, entry.name);
    const targetPath = join(targetDirectory, entry.name);
    if (entry.isDirectory()) {
      await syncDirectory(sourcePath, targetPath);
    } else {
      await writeChangedFile(sourcePath, targetPath);
    }
  }

  for (const name of await readdir(targetDirectory)) {
    if (!names.has(name)) {
      await rm(join(targetDirectory, name), { recursive: true, force: true });
    }
  }
}

async function generate() {
  const [name, ...extraArgs] = process.argv.slice(2);
  if (extraArgs.length > 0) {
    throw new Error("用法：pnpm openapi2ts [name]，最多指定一个上游名称");
  }
  const selectedConfigs = name === undefined ? configs : configs.filter((config) => config.projectName === name);
  if (selectedConfigs.length === 0) {
    throw new Error(`未找到上游 ${name}，可选名称：${configs.map((config) => config.projectName).join("、")}`);
  }

  const httpDirectory = resolve("src/http");
  const stagingDirectory = await mkdtemp(join(tmpdir(), "account-react-openapi-"));
  const outputDirectory = name === undefined ? join(httpDirectory, "api") : join(httpDirectory, "api", name);
  const stagedOutputDirectory =
    name === undefined ? join(stagingDirectory, "api") : join(stagingDirectory, "api", name);
  const backupDirectory = join(stagingDirectory, "previous-api");
  let preserveBackup = false;

  try {
    for (const config of selectedConfigs) {
      const response = await fetch(config.schemaPath, { signal: AbortSignal.timeout(30000) });
      if (!response.ok) {
        throw new Error(`下载上游 ${config.projectName} 的 OpenAPI 文档失败：HTTP ${response.status}`);
      }
      const schema: unknown = await response.json();
      const schemaPath = join(stagingDirectory, `${config.projectName}.json`);
      await writeFile(schemaPath, JSON.stringify(schema));
      await generateService({ ...config, schemaPath, serversPath: join(stagingDirectory, "api") });
      await formatService(join(stagingDirectory, "api", config.projectName));
    }

    // 全部生成成功后再备份并同步，失败时恢复原来的客户端。
    await mkdir(outputDirectory, { recursive: true });
    await cp(outputDirectory, backupDirectory, { recursive: true });

    try {
      await syncDirectory(stagedOutputDirectory, outputDirectory);
    } catch (error) {
      try {
        await syncDirectory(backupDirectory, outputDirectory);
      } catch (restoreError) {
        preserveBackup = true;
        throw new AggregateError(
          [error, restoreError],
          `更新和恢复 API 客户端失败，原文件备份保留在：${backupDirectory}`,
        );
      }
      throw error;
    }
  } finally {
    if (!preserveBackup) {
      await rm(stagingDirectory, { recursive: true, force: true });
    }
  }
}

try {
  await generate();
} catch (error) {
  console.error(error);
  process.exitCode = 1;
}
