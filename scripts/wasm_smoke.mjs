import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const wasmPath = process.argv[2];
if (!wasmPath) {
  throw new Error("usage: node scripts/wasm_smoke.mjs <wasm-path>");
}

const bytes = await readFile(wasmPath);
const { instance } = await WebAssembly.instantiate(bytes);
const exports = instance.exports;
const encoder = new TextEncoder();
const decoder = new TextDecoder();

function render(exportName, source) {
  const input = encoder.encode(source);
  exports.set_input(input.length);
  for (let index = 0; index < input.length; index += 1) {
    exports.write_input_byte(index, input[index]);
  }
  const status = exports[exportName]();
  const output = new Uint8Array(exports.get_output_len());
  for (let index = 0; index < output.length; index += 1) {
    output[index] = exports.read_output_byte(index);
  }
  assert.equal(status, 0, decoder.decode(output));
  return decoder.decode(output);
}

assert.match(render("render_svg", "a -> b"), /<svg/);
assert.match(render("render_ascii", "a -> b"), /a/);
assert.match(render("render_unicode", "a -> b"), /a/);

console.log("WASM smoke test passed");
