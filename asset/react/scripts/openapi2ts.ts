import { mkdir, mkdtemp, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { dirname, resolve, join } from "node:path";
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
  await mkdir(httpDirectory, { recursive: true });
  const stagingDirectory = await mkdtemp(join(httpDirectory, ".openapi-"));
  const outputDirectory = name === undefined ? join(httpDirectory, "api") : join(httpDirectory, "api", name);
  const stagedOutputDirectory =
    name === undefined ? join(stagingDirectory, "api") : join(stagingDirectory, "api", name);
  const backupDirectory = join(stagingDirectory, "previous-api");
  let hasBackup = false;

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

    // 选中的服务全部生成成功后再替换对应目录，失败时保留原来的客户端。
    await mkdir(dirname(outputDirectory), { recursive: true });
    try {
      await rename(outputDirectory, backupDirectory);
      hasBackup = true;
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) {
        throw error;
      }
    }

    try {
      await rename(stagedOutputDirectory, outputDirectory);
      hasBackup = false;
    } catch (error) {
      if (hasBackup) {
        await rename(backupDirectory, outputDirectory);
        hasBackup = false;
      }
      throw error;
    }
  } finally {
    if (!hasBackup) {
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
