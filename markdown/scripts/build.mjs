import { cp, mkdir, rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const markdownRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = resolve(markdownRoot, "..");
const dist = resolve(markdownRoot, "dist");

function run(command, args, cwd) {
  const result = spawnSync(command, args, { cwd, stdio: "inherit" });
  if (result.status !== 0) process.exit(result.status ?? 1);
}

run("moon", ["build", "cmd/wasm", "--target", "wasm", "--release"], repositoryRoot);
await rm(dist, { recursive: true, force: true });
run(resolve(markdownRoot, "node_modules/.bin/tsc"), [], markdownRoot);
await mkdir(resolve(dist, "internal"), { recursive: true });
await cp(
  resolve(repositoryRoot, "web/diago-wasm.js"),
  resolve(dist, "internal/abi.js"),
);
await cp(
  resolve(repositoryRoot, "_build/wasm/release/build/cmd/wasm/wasm.wasm"),
  resolve(dist, "diago.wasm"),
);
