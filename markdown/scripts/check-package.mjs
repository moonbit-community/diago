import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const markdownRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = resolve(markdownRoot, "..");
const limit = 18 * 1024 * 1024;

function run(command, args, cwd) {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (result.status !== 0) {
    throw new Error(`${command} failed:\n${result.stdout}\n${result.stderr}`);
  }
  return result.stdout;
}

const packed = JSON.parse(
  run("npm", ["pack", "--json", "--ignore-scripts"], markdownRoot),
)[0];
const paths = packed.files.map((entry) => entry.path);
const wasmFiles = packed.files.filter((entry) => entry.path.endsWith(".wasm"));
assert.equal(wasmFiles.length, 1);
assert.equal(wasmFiles[0].path, "dist/diago.wasm");
assert.ok(wasmFiles[0].size <= limit, `Wasm exceeds ${limit} bytes`);
for (const required of [
  "LICENSE",
  "README.md",
  "dist/index.js",
  "dist/index.d.ts",
  "dist/markdown-it.js",
  "dist/remark.js",
  "dist/vitepress.js",
  "package.json",
]) {
  assert.ok(paths.includes(required), `package is missing ${required}`);
}
assert.equal(paths.some((path) => path.startsWith("src/")), false);
assert.equal(paths.some((path) => path.startsWith("test/")), false);
assert.equal(paths.some((path) => path.startsWith("_build/")), false);

const moonVersion = /version\s*=\s*"([^"]+)"/.exec(
  await readFile(resolve(repositoryRoot, "moon.mod"), "utf8"),
)?.[1];
assert.equal(packed.version, moonVersion);

const consumer = await mkdtemp(resolve(tmpdir(), "diago-package-"));
const tarball = resolve(markdownRoot, packed.filename);
try {
  await writeFile(
    resolve(consumer, "package.json"),
    JSON.stringify({ private: true, type: "module" }),
  );
  run("npm", ["install", "--ignore-scripts", tarball], consumer);
  await writeFile(
    resolve(consumer, "smoke.mjs"),
    [
      "import { getDefaultRenderer } from 'diago'",
      "const renderer = await getDefaultRenderer()",
      "const result = renderer.render({ source: 'a -> b', output: 'svg' })",
      "if (!result.ok || !result.text.includes('<svg')) process.exit(1)",
      "for (const path of ['diago/markdown-it', 'diago/remark', 'diago/vitepress']) await import(path)",
      "try { await import('diago/internal/fence') } catch { process.exit(0) }",
      "process.exit(1)",
    ].join("\n"),
  );
  run(process.execPath, ["smoke.mjs"], consumer);
} finally {
  await rm(consumer, { recursive: true, force: true });
  await rm(tarball, { force: true });
}

console.log(
  `package ${packed.name}@${packed.version}: ${packed.size} bytes, Wasm ${wasmFiles[0].size} bytes`,
);
