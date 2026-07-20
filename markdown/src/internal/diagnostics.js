/** @typedef {import("../index.js").SourceRange} SourceRange */
/** @typedef {import("../index.js").DiagoDiagnostic} DiagoDiagnostic */

/** @param {string} name */
function diagnosticCode(name) {
  return `DIAGO_${name.replace(/[^a-zA-Z0-9]+/g, "_").toUpperCase()}`;
}

/**
 * @param {object} input
 * @param {string} input.message
 * @param {string} input.documentId
 * @param {string} input.blockId
 * @param {SourceRange | undefined} input.range
 * @param {import("../index.js").WasmErrorMetadata} input.wasm
 * @returns {DiagoDiagnostic}
 */
export function createDiagnostic({
  message,
  documentId,
  blockId,
  range,
  wasm,
}) {
  return Object.freeze({
    source: "diago",
    severity: "error",
    code: diagnosticCode(wasm.name),
    message,
    documentId,
    blockId,
    ...(range === undefined ? {} : { range }),
    wasm: Object.freeze({ ...wasm }),
  });
}
