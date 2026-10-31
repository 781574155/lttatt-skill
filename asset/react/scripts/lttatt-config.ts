import { readFileSync } from "node:fs";
import { resolve } from "node:path";

export interface Upstream {
  name: string;
  type: "java";
  url: string;
}

export interface ProxyConfig {
  location: string;
  proxy_pass: string;
}

interface LttattConfig {
  upstreams: Upstream[];
  proxies: ProxyConfig[];
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

function parseProxy(value: unknown): ProxyConfig {
  if (!isRecord(value)) {
    throw new Error("lttatt.json 的每个 proxy 必须是对象");
  }

  const { location, proxy_pass } = value;
  if (typeof location !== "string" || !/^\/[^\s?#{};"'$\\]*$/.test(location)) {
    throw new Error("proxy.location 必须是以 / 开头的路径，不能包含空白、查询参数或配置特殊字符");
  }
  if (
    typeof proxy_pass !== "string" ||
    !/^https?:\/\//i.test(proxy_pass) ||
    /[\s{};"'$\\]/.test(proxy_pass) ||
    !URL.canParse(proxy_pass)
  ) {
    throw new Error(`代理 ${location} 的 proxy_pass 必须是有效的 HTTP 或 HTTPS 地址`);
  }

  const target = new URL(proxy_pass);
  if (target.username || target.password || target.search || target.hash) {
    throw new Error(`代理 ${location} 的 proxy_pass 不能包含认证信息、查询参数或片段`);
  }

  return { location, proxy_pass };
}

export function loadLttattConfig(): LttattConfig {
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

  if (config.proxies !== undefined && !Array.isArray(config.proxies)) {
    throw new Error("lttatt.json 的 proxies 必须是列表");
  }
  const proxies = (config.proxies ?? []).map(parseProxy);
  const locations = new Set(upstreams.map((upstream) => `${getUpstreamPrefix(upstream)}/`));
  for (const proxy of proxies) {
    if (locations.has(proxy.location)) {
      throw new Error(`代理路径重复：${proxy.location}`);
    }
    locations.add(proxy.location);
  }

  return { upstreams, proxies };
}

export function loadUpstreams(): Upstream[] {
  return loadLttattConfig().upstreams;
}

export function getUpstreamPrefix(upstream: Upstream): string {
  return `/${upstream.name}`;
}

export function getUpstreamNamespace(upstream: Upstream): string {
  return `API_${upstream.name.replaceAll("-", "_")}`;
}
