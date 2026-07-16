export const DIAGO_WASM_ABI_VERSION = 1;

export const DiagoWasmErrorKind = Object.freeze({
  none: 0,
  request_length: 1,
  invalid_utf8: 2,
  invalid_json: 3,
  unsupported_version: 4,
  invalid_request: 5,
  parse: 10,
  io: 11,
  ir: 12,
  graph: 13,
  config: 14,
  layout: 15,
  render: 16,
  target: 17,
  result_too_large: 18,
});

const ERROR_NAMES = new Map(
  Object.entries(DiagoWasmErrorKind).map(([name, value]) => [value, name]),
);

const REQUIRED_EXPORTS = [
  "memory",
  "abi_version",
  "transfer_ptr",
  "transfer_capacity",
  "render",
  "result_len",
  "result_error_kind",
  "result_required_len",
];

const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true });

function getExports(wasm) {
  if (wasm instanceof WebAssembly.Instance) {
    return wasm.exports;
  }
  if (wasm?.instance instanceof WebAssembly.Instance) {
    return wasm.instance.exports;
  }
  if (wasm && typeof wasm === "object") {
    return wasm;
  }
  throw new Error("diago wasm instance or exports object is required");
}

function validateExports(exports) {
  for (const name of REQUIRED_EXPORTS) {
    if (!(name in exports)) {
      throw new Error(`diago wasm is missing required export \`${name}\``);
    }
  }
  if (!(exports.memory instanceof WebAssembly.Memory)) {
    throw new Error("diago wasm export `memory` must be WebAssembly.Memory");
  }
  const version = exports.abi_version();
  if (version !== DIAGO_WASM_ABI_VERSION) {
    throw new Error(
      `unsupported diago wasm ABI ${version}; expected ${DIAGO_WASM_ABI_VERSION}`,
    );
  }
}

function makeResult(status, body, errorKind, requiredLength) {
  const text = decoder.decode(body);
  if (status === 0) {
    return { ok: true, body, text, error: null };
  }
  return {
    ok: false,
    body,
    text,
    error: {
      kind: errorKind,
      name: ERROR_NAMES.get(errorKind) ?? "unknown",
      requiredLength,
    },
  };
}

export function createDiagoWasm(wasm) {
  const exports = getExports(wasm);
  validateExports(exports);

  const transferPtr = exports.transfer_ptr();
  const transferCapacity = exports.transfer_capacity();
  if (
    !Number.isInteger(transferPtr) ||
    !Number.isInteger(transferCapacity) ||
    transferPtr < 0 ||
    transferCapacity <= 0 ||
    transferPtr + transferCapacity > exports.memory.buffer.byteLength
  ) {
    throw new Error("diago wasm exported an invalid transfer arena");
  }

  return Object.freeze({
    abiVersion: DIAGO_WASM_ABI_VERSION,
    transferCapacity,

    render(request) {
      const requestBody = encoder.encode(
        JSON.stringify({
          ...request,
          version: request?.version ?? DIAGO_WASM_ABI_VERSION,
        }),
      );
      if (requestBody.length > transferCapacity) {
        const text =
          `request body requires ${requestBody.length} bytes, ` +
          `exceeding transfer capacity ${transferCapacity}`;
        return makeResult(
          1,
          encoder.encode(text),
          DiagoWasmErrorKind.request_length,
          requestBody.length,
        );
      }

      new Uint8Array(
        exports.memory.buffer,
        transferPtr,
        requestBody.length,
      ).set(requestBody);
      const status = exports.render(requestBody.length);
      const resultLength = exports.result_len();
      const errorKind = exports.result_error_kind();
      const requiredLength = exports.result_required_len();

      if (status !== 0 && status !== 1) {
        throw new Error(`diago wasm returned invalid status ${status}`);
      }
      if (
        !Number.isInteger(resultLength) ||
        resultLength < 0 ||
        resultLength > transferCapacity
      ) {
        throw new Error(
          `diago wasm returned invalid result length ${resultLength}`,
        );
      }
      if (
        !Number.isInteger(errorKind) ||
        !Number.isInteger(requiredLength) ||
        requiredLength < 0 ||
        (status === 0) !== (errorKind === DiagoWasmErrorKind.none)
      ) {
        throw new Error("diago wasm returned inconsistent result metadata");
      }

      const body = new Uint8Array(
        new Uint8Array(
          exports.memory.buffer,
          transferPtr,
          resultLength,
        ),
      );
      return makeResult(status, body, errorKind, requiredLength);
    },
  });
}

export async function instantiateDiagoWasm(source, imports = {}) {
  let bytes = source;
  if (
    typeof source === "string" ||
    source instanceof URL ||
    (typeof Request !== "undefined" && source instanceof Request)
  ) {
    const response = await fetch(source);
    if (!response.ok) {
      throw new Error(`failed to fetch diago wasm: ${response.status}`);
    }
    bytes = await response.arrayBuffer();
  } else if (
    typeof Response !== "undefined" &&
    source instanceof Response
  ) {
    if (!source.ok) {
      throw new Error(`failed to fetch diago wasm: ${source.status}`);
    }
    bytes = await source.arrayBuffer();
  }
  const instantiated = await WebAssembly.instantiate(bytes, imports);
  return createDiagoWasm(instantiated);
}
