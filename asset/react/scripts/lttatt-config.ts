import { readFileSync } from "node:fs";
import { resolve } from "node:path";

export interface Upstream {
  name: string;
  type: "java";
  url: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function parseUpstream(value: unknown): Upstream {
  if (!isRecord(value)) {
    throw new Error("lttatt.json 的每个 upstream 必须是对象");
  }

  const { name, type, url } = value;
  if (typeof name !== "string" || !/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(name)) {
    throw new Error("upstream.name 必须以小写字母开头，只能包含小写字母、数字和单个连字符");
  }
  if (type !== "java") {
    throw new Error(`上游 ${name} 的 type 目前仅支持 java`);
  }
  if (typeof url !== "string" || !URL.canParse(url)) {
    throw new Error(`上游 ${name} 的 url 必须是有效的 HTTP 或 HTTPS 地址`);
  }

  const parsedUrl = new URL(url);
  if (
    !["http:", "https:"].includes(parsedUrl.protocol) ||
    parsedUrl.username ||
    parsedUrl.password ||
    parsedUrl.pathname !== "/" ||
    parsedUrl.search ||
    parsedUrl.hash
  ) {
    throw new Error(`上游 ${name} 的 url 只能包含 HTTP 或 HTTPS 协议、主机和端口`);
  }

  return { name, type, url: parsedUrl.origin };
}

export function loadUpstreams(): Upstream[] {
  const config: unknown = JSON.parse(readFileSync(resolve("lttatt.json"), "utf8"));
  if (!isRecord(config) || !Array.isArray(config.upstreams) || config.upstreams.length === 0) {
    throw new Error("lttatt.json 必须包含非空的 upstreams 列表");
  }

  const upstreams = config.upstreams.map(parseUpstream);
  const names = new Set<string>();
  for (const upstream of upstreams) {
    if (names.has(upstream.name)) {
      throw new Error(`上游名称重复：${upstream.name}`);
    }
    names.add(upstream.name);
  }
  return upstreams;
}

export function getUpstreamPrefix(upstream: Upstream): string {
  return `/${upstream.name}`;
}

export function getUpstreamNamespace(upstream: Upstream): string {
  return `API_${upstream.name.replaceAll("-", "_")}`;
}
