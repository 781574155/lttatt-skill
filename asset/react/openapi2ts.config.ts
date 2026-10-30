import lodash from "lodash";
import type { GenerateServiceProps } from "@easyfollow/openapi";
import { getUpstreamNamespace, getUpstreamPrefix, loadUpstreams } from "./scripts/lttatt-config.ts";

const { camelCase } = lodash;
const RESERVED_FUNCTION_NAMES = new Set(
  (
    "arguments await break case catch class const continue debugger default delete do else enum eval export extends " +
    "false finally for function if implements import in instanceof interface let new null package private protected " +
    "public return static super switch this throw true try typeof var void while with yield"
  ).split(" "),
);

interface OpenApiOperation {
  operationId?: string;
  tags?: string[];
}

function customFunctionName(data: OpenApiOperation) {
  if (!data.operationId) {
    throw new Error("OpenAPI 接口缺少 operationId");
  }
  const name = data.operationId.split("_")[0];
  return RESERVED_FUNCTION_NAMES.has(name) ? `${name}Item` : name;
}

function customTypeName(data: OpenApiOperation) {
  const funcName = customFunctionName(data);
  const resourceName = camelCase(data.tags?.[0] ?? "");
  return `${funcName}__${resourceName.charAt(0).toUpperCase() + resourceName.slice(1)}`;
}

export default loadUpstreams().map(
  (upstream) =>
    ({
      schemaPath: `${upstream.url}/backend-api/v3/api-docs`,
      serversPath: "./src/http/api",
      projectName: upstream.name,
      namespace: getUpstreamNamespace(upstream),
      requestImportStatement: 'import request from "@/http/request";',
      isCamelCase: false,
      hook: {
        customFunctionName,
        customTypeName,
        afterOpenApiDataInited(data) {
          if (!data?.openapi?.startsWith("3.") || !data.info || !data.paths) {
            throw new Error(`上游 ${upstream.name} 未返回有效的 OpenAPI 3 文档`);
          }

          // 在生成前加入服务前缀，让请求路径和普通、无限查询的 Query Key 一起隔离。
          const paths = Object.fromEntries(
            Object.entries(data.paths).map(([path, operation]) => {
              const backendPath = path.replace(/^\/backend-api(?=\/|$)/, "");
              return [`${getUpstreamPrefix(upstream)}${backendPath || "/"}`, operation];
            }),
          );
          return { ...data, paths };
        },
      },
      reactQuery: true,
    }) satisfies GenerateServiceProps,
);
