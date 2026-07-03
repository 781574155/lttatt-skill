// @ts-ignore
import { camelCase } from "lodash";
import { readFileSync } from "fs";
import { resolve } from "path";

function parseEnvFile(filePath: string): Record<string, string> {
  try {
    const content = readFileSync(filePath, "utf-8");
    return Object.fromEntries(
      content
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line && !line.startsWith("#"))
        .map((line) => {
          const idx = line.indexOf("=");
          return idx === -1
            ? null
            : [
                line.slice(0, idx).trim(),
                line
                  .slice(idx + 1)
                  .trim()
                  .replace(/^(['"])(.*)\1$/, "$2"),
              ];
        })
        .filter(Boolean) as [string, string][],
    );
  } catch {
    return {};
  }
}

const env = parseEnvFile(resolve(process.cwd(), ".env.lttatt"));
const upstream = (env.UPSTREAM ?? process.env.UPSTREAM ?? "").replace(/\/$/, "");

if (!upstream) {
  throw new Error("Missing UPSTREAM in .env.lttatt");
}

function customFunctionName(data: any) {
  var name = data.operationId.indexOf("_") === -1 ? data.operationId : data.operationId.split("_")[0];
  return name === "delete" ? "deleteItem" : name;
}

function customTypeName(data: any) {
  var funcName = customFunctionName(data);
  var resourceName = camelCase(data.tags[0]);
  return `${funcName}__${resourceName.charAt(0).toUpperCase() + resourceName.slice(1)}`;
}

export default {
  schemaPath: `${upstream}/backend-api/v3/api-docs`,
  apiPrefix: '"/backend-api"',
  serversPath: "./src/http",
  requestImportStatement: 'import request from "@/http/request";',
  isCamelCase: false,
  hook: {
    customFunctionName: customFunctionName,
    customTypeName: customTypeName,
  },
};
