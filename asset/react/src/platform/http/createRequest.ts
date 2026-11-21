import axios, { AxiosError } from "axios";
import type { AxiosResponse, InternalAxiosRequestConfig } from "axios";
import { replaceFieldPrefixes } from "./fieldPrefixMappings";
import type { FieldPrefixMapping } from "./fieldPrefixMappings";

interface HttpErrorData {
  error?: { message?: string };
  detail?: string;
  message?: string;
}

interface OperationResult {
  success?: boolean;
  message?: string;
}

interface CreateRequestOptions {
  baseURL?: string;
  additionalAuthenticatedPaths?: RegExp;
  getAccessToken: () => Promise<string | null>;
  invalidateAccessToken: (token: string | null) => Promise<void>;
  expireSession: () => void;
  getFieldPrefixMappings: () => readonly FieldPrefixMapping[] | undefined;
  notify: (type: "error" | "success", title: string) => void;
}

declare module "axios" {
  export interface AxiosRequestConfig {
    noResponseInterceptor?: boolean;
    noFieldPrefixReplacement?: boolean;
    noMessageSuccess?: boolean;
    noMessageNotFound?: boolean;
  }
}

const AUTHENTICATED_API_PATH = /^\/(?:api\/)?[^/]+\/(?:user|admin|get_login_info)(\/|$)/;

export function isResourceNotFound(response?: Pick<AxiosResponse<unknown>, "status" | "data">) {
  if (!response) return false;
  if (response.status === 404) return true;
  const data = response.data;
  return data !== null && typeof data === "object" && "message" in data && data.message === "指定资源不存在";
}

function getHttpErrorMessage({ status, data }: AxiosResponse<HttpErrorData>) {
  switch (status) {
    case 400:
      return data?.message || data?.error?.message || data?.detail || "请求参数有误。";
    case 403:
      return data?.message || "当前账号没有执行此操作的权限。";
    case 413:
      return "上传文件太大！";
    case 500:
      return data?.message || "服务器错误，请稍后重试。";
    case 502:
    case 504:
      return "无法连接到服务器。";
    default:
      return data?.message || `请求失败：${status}`;
  }
}

function serializeQueryParams(values: unknown) {
  if (values instanceof URLSearchParams) return values;
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(values ?? {})) {
    if (value === undefined || value === null || value === "") continue;
    for (const item of Array.isArray(value) ? value : [value]) {
      params.append(key, String(item));
    }
  }
  return params;
}

export function createRequest({
  baseURL,
  additionalAuthenticatedPaths,
  getAccessToken,
  invalidateAccessToken,
  expireSession,
  getFieldPrefixMappings,
  notify,
}: CreateRequestOptions) {
  const request = axios.create({
    baseURL,
    withCredentials: true,
    timeout: 300000,
    headers: { Accept: "application/json" },
  });

  function requiresAccessToken(config: InternalAxiosRequestConfig) {
    const origin = window.location.origin;
    const url = new URL(request.getUri(config), origin);
    const apiOrigin = new URL(request.defaults.baseURL || "/", origin).origin;
    const pathname = new URL(config.url || "/", origin).pathname;
    return (
      url.origin === apiOrigin &&
      (AUTHENTICATED_API_PATH.test(pathname) || additionalAuthenticatedPaths?.test(pathname) === true)
    );
  }

  request.interceptors.request.use(async (config) => {
    if (requiresAccessToken(config)) {
      const accessToken = await getAccessToken();
      if (!accessToken) throw new axios.CanceledError("正在重新授权");
      config.headers.set("Authorization", `Bearer ${accessToken}`);
    }
    if (!config.noFieldPrefixReplacement) {
      const fields = replaceFieldPrefixes(
        { data: config.data as unknown, params: config.params as unknown },
        getFieldPrefixMappings(),
        "request",
      );
      config.data = fields.data;
      config.params = fields.params;
    }
    config.params = serializeQueryParams(config.params);
    return config;
  });

  request.interceptors.response.use(
    (response: AxiosResponse<OperationResult>) => {
      const { config } = response;
      if (config?.noResponseInterceptor) return response;
      if (!config?.noFieldPrefixReplacement) {
        response.data = replaceFieldPrefixes(response.data, getFieldPrefixMappings());
      }
      const data = response.data;
      if (!data || typeof data !== "object" || !Object.hasOwn(data, "success")) return response;

      if (!data.success) {
        const message = data.message || "操作失败。";
        if (!config?.noMessageNotFound || !isResourceNotFound(response)) notify("error", message);
        throw new AxiosError(message, undefined, config, response.request, response);
      }
      if (data.message && !config?.noMessageSuccess) notify("success", data.message);
      return response;
    },
    async (error: AxiosError<HttpErrorData>) => {
      const { config, response } = error;
      if (axios.isCancel(error) || config?.noResponseInterceptor) throw error;
      if (!response) {
        notify("error", "网络连接失败，请稍后重试。");
        throw error;
      }
      if (!config?.noFieldPrefixReplacement) {
        response.data = replaceFieldPrefixes(response.data, getFieldPrefixMappings());
      }
      if (response.status === 401 && config && requiresAccessToken(config)) {
        const authorization = config.headers.get("Authorization");
        const token =
          typeof authorization === "string" && authorization.startsWith("Bearer ") ? authorization.slice(7) : null;
        await invalidateAccessToken(token);
        throw error;
      }
      if (config?.noMessageNotFound && isResourceNotFound(response)) throw error;

      if (response.status === 401) expireSession();
      else notify("error", getHttpErrorMessage(response));
      throw error;
    },
  );

  return request;
}
