export const DIAGO_WASM_ABI_VERSION = 2;

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
  unsupported_feature: 19,
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
  "highlight",
  "result_len",
  "result_error_kind",
  "result_required_len",
];

const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true });
const SYNTAX_TOKEN_KINDS = new Set([
  "comment",
  "string",
  "number",
  "boolean",
  "keyword",
  "identifier",
  "operator",
  "punctuation",
]);

function createMoonBitHostImports(imports) {
  let memory = null;
  return {
    imports: {
      ...imports,
      __moonbit_time_unstable: {
        now: () => BigInt.asUintN(64, BigInt(Date.now())),
        ...imports.__moonbit_time_unstable,
      },
      wasi_snapshot_preview1: {
        random_get(pointer, length) {
          if (
            !(memory instanceof WebAssembly.Memory) ||
            !Number.isInteger(pointer) ||
            !Number.isInteger(length) ||
            pointer < 0 ||
            length < 0 ||
            pointer + length > memory.buffer.byteLength ||
            globalThis.crypto?.getRandomValues === undefined
          ) {
            return 21;
          }
          const output = new Uint8Array(memory.buffer, pointer, length);
          for (let offset = 0; offset < output.length; offset += 65536) {
            globalThis.crypto.getRandomValues(
              output.subarray(offset, Math.min(offset + 65536, output.length)),
            );
          }
          return 0;
        },
        ...imports.wasi_snapshot_preview1,
      },
    },
    setMemory(value) {
      memory = value;
    },
  };
}

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

function parseSyntaxTokens(text, source) {
  let tokens;
  try {
    tokens = JSON.parse(text);
  } catch (error) {
    throw new Error("diago wasm returned invalid syntax token JSON", {
      cause: error,
    });
  }
  if (!Array.isArray(tokens)) {
    throw new Error("diago wasm syntax token result must be an array");
  }

  const requestedOffsets = new Set([0]);
  let previousEnd = 0;
  for (const token of tokens) {
    if (
      token === null ||
      typeof token !== "object" ||
      !Number.isInteger(token.from) ||
      !Number.isInteger(token.to) ||
      token.from < previousEnd ||
      token.to <= token.from ||
      !SYNTAX_TOKEN_KINDS.has(token.kind)
    ) {
      throw new Error("diago wasm returned an invalid syntax token");
    }
    requestedOffsets.add(token.from);
    requestedOffsets.add(token.to);
    previousEnd = token.to;
  }

  const utf16Offsets = new Map([[0, 0]]);
  let codePointOffset = 0;
  let utf16Offset = 0;
  for (const char of source) {
    codePointOffset += 1;
    utf16Offset += char.length;
    if (requestedOffsets.has(codePointOffset)) {
      utf16Offsets.set(codePointOffset, utf16Offset);
    }
  }
  if (previousEnd > codePointOffset) {
    throw new Error("diago wasm returned an out-of-bounds syntax token");
  }

  return tokens.map((token) => ({
    from: utf16Offsets.get(token.from),
    to: utf16Offsets.get(token.to),
    kind: token.kind,
  }));
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

  function transact(requestBody, operation) {
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
    const status = operation(requestBody.length);
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
      return transact(requestBody, exports.render);
    },

    highlight(source) {
      if (typeof source !== "string") {
        throw new TypeError("diago source must be a string");
      }
      const result = transact(encoder.encode(source), exports.highlight);
      if (!result.ok) {
        return { ...result, tokens: [] };
      }
      return {
        ...result,
        tokens: parseSyntaxTokens(result.text, source),
      };
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
  const host = createMoonBitHostImports(imports);
  const instantiated = await WebAssembly.instantiate(bytes, host.imports);
  host.setMemory(getExports(instantiated).memory);
  return createDiagoWasm(instantiated);
}
