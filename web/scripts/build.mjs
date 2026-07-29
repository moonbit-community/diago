import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { build } from "esbuild";

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const output = resolve(webRoot, "assets/editor.js");

await mkdir(dirname(output), { recursive: true });
await build({
  entryPoints: [resolve(webRoot, "src/editor.js")],
  outfile: output,
  bundle: true,
  format: "esm",
  minify: true,
  sourcemap: false,
  target: ["es2022"],
});
