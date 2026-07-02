import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import { codeInspectorPlugin } from "code-inspector-plugin";
import { resolve } from "path";

const env = loadEnv("lttatt", process.cwd(), "");
const upstream = env.UPSTREAM?.replace(/\/$/, "");

if (!upstream) {
  throw new Error("Missing UPSTREAM in .env.lttatt");
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    codeInspectorPlugin({
      bundler: "vite",
    }),

    react(),
  ],
  resolve: {
    alias: {
      "@": resolve(__dirname, "src"),
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
