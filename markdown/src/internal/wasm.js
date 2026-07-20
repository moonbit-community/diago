import { readFile } from "node:fs/promises";

import { instantiateDiagoWasm } from "./abi.js";

/** @typedef {import("../index.js").Renderer} Renderer */

/** @type {Promise<WebAssembly.Module> | undefined} */
let modulePromise;

/** @type {Promise<Renderer> | undefined} */
let defaultRendererPromise;

/** @returns {Promise<WebAssembly.Module>} */
function getBundledModule() {
  if (modulePromise === undefined) {
    modulePromise = readFile(new URL("../diago.wasm", import.meta.url)).then(
      (bytes) => WebAssembly.compile(bytes),
    );
  }
  return modulePromise;
}

/** @returns {Promise<Renderer>} */
export async function createRenderer() {
  const module = await getBundledModule();
  return /** @type {Renderer} */ (await instantiateDiagoWasm(module));
}

/** @returns {Promise<Renderer>} */
export function getDefaultRenderer() {
  if (defaultRendererPromise === undefined) {
    defaultRendererPromise = createRenderer();
  }
  return defaultRendererPromise;
}
