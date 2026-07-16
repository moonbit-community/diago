import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import {
  createDiagoWasm,
  DiagoWasmErrorKind,
} from "../web/diago-wasm.js";

const wasmPath = process.argv[2];
if (!wasmPath) {
  throw new Error("usage: node scripts/wasm_smoke.mjs <wasm-path>");
}

const bytes = await readFile(wasmPath);
const { instance } = await WebAssembly.instantiate(bytes);
const exports = instance.exports;
const diago = createDiagoWasm(instance);

assert.ok(exports.memory instanceof WebAssembly.Memory);
assert.equal(exports.abi_version(), 1);
assert.equal(exports.set_input, undefined);
assert.equal(exports.render_svg, undefined);

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

console.log("WASM smoke test passed");
