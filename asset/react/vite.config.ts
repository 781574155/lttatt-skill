import { defineConfig, loadEnv } from "vite";
import react, { reactCompilerPreset } from "@vitejs/plugin-react";
import babel from "@rolldown/plugin-babel";
import tailwindcss from "@tailwindcss/vite";
import { codeInspectorPlugin } from "code-inspector-plugin";
import { fileURLToPath, URL } from "node:url";
import istanbul from "vite-plugin-istanbul";

const env = loadEnv("lttatt", process.cwd(), "");
const upstream = env.UPSTREAM?.replace(/\/$/, "");
const coverageEnabled = process.env.VITE_COVERAGE === "true";
const umamiEnabled = process.env.VITE_UMAMI_ENABLED === "true";
const umamiWebsiteId = env.VITE_UMAMI_WEBSITE_ID?.trim() || "";

if (!upstream) {
  throw new Error("Missing UPSTREAM in .env.lttatt");
}

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
    }),
    tailwindcss(),
    react({
      exclude: [/\/node_modules\//, /\/src\/http\/api\//],
    }),
    babel({
      exclude: [/[/\\]node_modules[/\\]/, /[/\\]src[/\\]http[/\\]api[/\\]/, /\0rolldown\/runtime\.js/],
      presets: [reactCompilerPreset()],
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
      "@canvas": fileURLToPath(new URL("./src/pages/Drama/Canvas", import.meta.url)),
    },
  },
  css: {
    modules: {
      localsConvention: "camelCaseOnly",
    },
  },
  server: {
    proxy: {
      "/backend-api": {
        target: upstream,
        changeOrigin: true,
        secure: false,
      },
    },
  },
});
