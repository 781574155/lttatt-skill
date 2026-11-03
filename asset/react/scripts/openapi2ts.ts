import { cp, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import { generateService } from "@easyfollow/openapi";
import { format, resolveConfig } from "prettier";
import ts from "typescript";
import configs from "../openapi2ts.config.ts";
import { getUpstreamPrefix, loadUpstreams } from "./lttatt-config.ts";

function replacePrefix(path: string, prefix: string, location: string): string {
  return path === prefix || path.startsWith(`${prefix}/`) ? `${location}${path.slice(prefix.length)}` : path;
}

function replacePathPrefix(node: ts.Expression, prefix: string, location: string): ts.Expression {
  const path = ts.isTemplateExpression(node) ? node.head.text : ts.isStringLiteralLike(node) ? node.text : undefined;
  if (path === undefined) return node;

  const targetPath = replacePrefix(path, prefix, location);
  if (targetPath === path) return node;

  if (ts.isTemplateExpression(node)) {
    return ts.factory.updateTemplateExpression(node, ts.factory.createTemplateHead(targetPath), node.templateSpans);
  }
  if (ts.isNoSubstitutionTemplateLiteral(node)) {
    return ts.factory.createNoSubstitutionTemplateLiteral(targetPath);
  }
  return ts.factory.createStringLiteral(targetPath);
}

function replaceCommentPath(comment: string, prefix: string, location: string): string {
  return comment.replace(
    /(\b(?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|TRACE)\s+)(\/\S*)(\s*\*\/)$/,
    (_match, method: string, path: string, ending: string) =>
      `${method}${replacePrefix(path, prefix, location.replaceAll("*", "&#42;"))}${ending}`,
  );
}

function rewriteOpenApiRequestPaths(source: string, prefix: string, location: string): string {
  if (prefix === location) return source;

  const sourceFile = ts.createSourceFile("service.ts", source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
  const printer = ts.createPrinter();
  const replacements: { start: number; end: number; text: string }[] = [];

  function visit(node: ts.Node) {
    if (ts.isFunctionDeclaration(node)) {
      for (const comment of ts.getLeadingCommentRanges(source, node.getFullStart()) ?? []) {
        const text = source.slice(comment.pos, comment.end);
        if (!text.startsWith("/**")) continue;
        const target = replaceCommentPath(text, prefix, location);
        if (target !== text) {
          replacements.push({ start: comment.pos, end: comment.end, text: target });
        }
      }
    }
    if (ts.isCallExpression(node) && ts.isIdentifier(node.expression) && node.expression.text === "request") {
      const argument = node.arguments[0];
      if (argument) {
        const target = replacePathPrefix(argument, prefix, location);
        if (target !== argument) {
          replacements.push({
            start: argument.getStart(sourceFile),
            end: argument.getEnd(),
            text: printer.printNode(ts.EmitHint.Expression, target, sourceFile),
          });
        }
      }
    }
    ts.forEachChild(node, visit);
  }

  visit(sourceFile);
  for (const replacement of replacements.sort((a, b) => b.start - a.start)) {
    source = source.slice(0, replacement.start) + replacement.text + source.slice(replacement.end);
  }
  return source;
}

async function formatService(directory: string, prefix: string, location: string) {
  const options = await resolveConfig(resolve(".prettierrc"));
  for (const file of await readdir(directory)) {
    if (file.endsWith(".ts")) {
      const filePath = join(directory, file);
      const source = rewriteOpenApiRequestPaths(await readFile(filePath, "utf8"), prefix, location);
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
  const upstreams = loadUpstreams();
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
      const upstream = upstreams.find((item) => item.name === config.projectName);
      if (!upstream) throw new Error(`未找到上游配置：${config.projectName}`);
      const response = await fetch(config.schemaPath, { signal: AbortSignal.timeout(30000) });
      if (!response.ok) {
        throw new Error(`下载上游 ${config.projectName} 的 OpenAPI 文档失败：HTTP ${response.status}`);
      }
      const schema: unknown = await response.json();
      const schemaPath = join(stagingDirectory, `${config.projectName}.json`);
      await writeFile(schemaPath, JSON.stringify(schema));
      await generateService({ ...config, schemaPath, serversPath: join(stagingDirectory, "api") });
      await formatService(
        join(stagingDirectory, "api", config.projectName),
        `/${upstream.name}`,
        getUpstreamPrefix(upstream),
      );
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
          { cause: restoreError },
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
