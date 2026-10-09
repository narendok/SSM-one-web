import { defineConfig } from "vitest/config";
import { fileURLToPath } from "node:url";

// Unit tests do not need the production MCP route generator.
export default defineConfig({
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  test: {
    environment: "node",
    environmentMatchGlobs: [
      ["src/components/lifecycle/**/*.dom.test.tsx", "jsdom"],
      ["src/components/tasks/**/*.dom.test.tsx", "jsdom"],
    ],
  },
});
