import { writeFileSync } from "node:fs";
import { getUpstreamPrefix, loadLttattConfig } from "./lttatt-config.ts";

const outputPath = process.argv[2];
if (!outputPath) {
  throw new Error("请指定 Nginx 上游配置的输出路径");
}

const { upstreams, proxies } = loadLttattConfig();
const locations = [
  ...upstreams.map((upstream) => ({
    location: `${getUpstreamPrefix(upstream)}/`,
    proxy_pass: `http://${upstream.name}:8080/backend-api/`,
  })),
  ...proxies,
].map(
  (proxy) => `location ^~ ${proxy.location} {
    proxy_pass ${proxy.proxy_pass};
${new URL(proxy.proxy_pass).protocol === "https:" ? "    proxy_ssl_server_name on;\n" : ""}    proxy_set_header Host $proxy_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    client_max_body_size 2048M;
    proxy_buffering off;
    proxy_read_timeout 600;
}
`,
);

writeFileSync(outputPath, locations.join("\n"));
