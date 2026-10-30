import { defineConfig, loadEnv, type ProxyOptions } from "vite";
import react, { reactCompilerPreset } from "@vitejs/plugin-react";
import babel from "@rolldown/plugin-babel";
import tailwindcss from "@tailwindcss/vite";
import { codeInspectorPlugin } from "code-inspector-plugin";
import { fileURLToPath, URL } from "node:url";
import istanbul from "vite-plugin-istanbul";
import { getUpstreamPrefix, loadUpstreams } from "./scripts/lttatt-config.ts";

const compilerPreset = reactCompilerPreset();
compilerPreset.rolldown.filter = {
  ...compilerPreset.rolldown.filter,
  id: {
    exclude: [/\/node_modules\//, /\/src\/http\/api\//],
  },
};

const env = loadEnv("lttatt", process.cwd(), "");
const coverageEnabled = process.env.VITE_COVERAGE === "true";
const umamiEnabled = process.env.VITE_UMAMI_ENABLED === "true";
const umamiWebsiteId = env.VITE_UMAMI_WEBSITE_ID?.trim() || "";

const proxy = Object.fromEntries(
  loadUpstreams().map((upstream) => {
    const prefix = getUpstreamPrefix(upstream);
    const options: ProxyOptions = {
      target: upstream.url,
      changeOrigin: true,
      secure: false,
      rewrite: (path) => `/backend-api${path.slice(prefix.length)}`,
    };
    return [`${prefix}/`, options];
  }),
);

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    umamiEnabled &&
      umamiWebsiteId && {
        name: "inject-umami",
        transformIndexHtml: {
          order: "pre",
          handler: () => [
            {
              tag: "script",
              attrs: {
                defer: true,
                src: "https://umami.lttatt.com/script.js",
                "data-website-id": umamiWebsiteId,
              },
              injectTo: "head",
            },
          ],
        },
      },
    codeInspectorPlugin({
      bundler: "vite",
      importClient: "file",
    }),
    tailwindcss(),
    react({
      exclude: [/\/node_modules\//, /\/src\/http\/api\//],
    }),
    babel({
      presets: [compilerPreset],
    }),
    coverageEnabled &&
      istanbul({
        include: "src/**/*",
        exclude: ["src/http/api/**/*", "**/*.d.ts"],
        requireEnv: false,
        forceBuildInstrument: true,
      }),
  ],
  build: {
    sourcemap: coverageEnabled ? "inline" : false,
  },
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  server: {
    proxy,
  },
});
