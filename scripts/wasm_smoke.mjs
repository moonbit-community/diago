import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  DiagoWasmErrorKind,
  instantiateDiagoWasm,
} from "../web/diago-wasm.js";

const wasmPath = process.argv[2];
if (!wasmPath) {
  throw new Error("usage: node scripts/wasm_smoke.mjs <wasm-path>");
}

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const bytes = await readFile(wasmPath);
const module = await WebAssembly.compile(bytes);
const diago = await instantiateDiagoWasm(module);
const instance = await WebAssembly.instantiate(module, {
  __moonbit_time_unstable: {
    now: () => BigInt.asUintN(64, BigInt(Date.now())),
  },
  wasi_snapshot_preview1: {
    random_get: () => 0,
  },
});
const exports = instance.exports;

assert.ok(exports.memory instanceof WebAssembly.Memory);
assert.equal(exports.abi_version(), 2);
assert.equal(exports.set_input, undefined);
assert.equal(exports.render_svg, undefined);

const highlighted = diago.highlight('"🌙": true\nnote: |md\n  **editing');
assert.equal(highlighted.ok, true, highlighted.text);
assert.deepEqual(highlighted.tokens, [
  { from: 0, to: 4, kind: "string" },
  { from: 4, to: 5, kind: "punctuation" },
  { from: 6, to: 10, kind: "boolean" },
  { from: 11, to: 15, kind: "identifier" },
  { from: 15, to: 16, kind: "punctuation" },
  { from: 17, to: 32, kind: "string" },
]);

for (const [output, layout] of [
  ["svg", "dagre"],
  ["ascii", "elk"],
  ["unicode", "railway"],
]) {
  const result = diago.render({ source: "a -> b", output, layout });
  assert.equal(result.ok, true, result.text);
  assert.ok(result.body instanceof Uint8Array);
  assert.match(result.text, output === "svg" ? /<svg/ : /a/);
}

const unicode = diago.render({
  source: "你好 -> 世界",
  output: "unicode",
  layout: "dagre",
});
assert.equal(unicode.ok, true, unicode.text);
assert.match(unicode.text, /你好/);

const parseError = diago.render({ source: "a: {" });
assert.equal(parseError.ok, false);
assert.equal(parseError.error.kind, DiagoWasmErrorKind.parse);
assert.equal(parseError.error.name, "parse");
assert.ok(parseError.body instanceof Uint8Array);

const invalidLayout = diago.render({
  source: "a -> b",
  layout: "unknown",
});
assert.equal(invalidLayout.ok, false);
assert.equal(
  invalidLayout.error.kind,
  DiagoWasmErrorKind.invalid_request,
);

const sourceConfig = diago.render({
  source: "vars: { d2-config: { layout-engine: invalid } }\na -> b",
});
assert.equal(sourceConfig.ok, false);
assert.equal(sourceConfig.error.kind, DiagoWasmErrorKind.config);

assert.equal(exports.render(-1), 1);
assert.equal(
  exports.result_error_kind(),
  DiagoWasmErrorKind.request_length,
);
new Uint8Array(exports.memory.buffer, exports.transfer_ptr(), 1)[0] = 255;
assert.equal(exports.render(1), 1);
assert.equal(
  exports.result_error_kind(),
  DiagoWasmErrorKind.invalid_utf8,
);

const officialFiles = (
  await readFile(
    resolve(repositoryRoot, "testdata/d2-official/FILES.txt"),
    "utf8",
  )
)
  .trim()
  .split("\n");
assert.equal(officialFiles.length, 187);
for (const relativePath of officialFiles) {
  const source = await readFile(
    resolve(
      repositoryRoot,
      "testdata/d2-official/d2-docs",
      relativePath,
    ),
    "utf8",
  );
  const result = diago.highlight(source);
  assert.equal(result.ok, true, `${relativePath}: ${result.text}`);
}

console.log("WASM smoke test passed, including 187 syntax fixtures");
