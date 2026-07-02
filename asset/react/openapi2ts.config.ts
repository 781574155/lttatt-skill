// @ts-ignore
import { camelCase } from "lodash";
import { loadEnv } from "vite";

const env = loadEnv("lttatt", process.cwd(), "");
const upstream = env.UPSTREAM?.replace(/\/$/, "");

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
