import {
  createRenderer,
  getDefaultRenderer,
} from "./internal/wasm.js";

export { createRenderer, getDefaultRenderer };

/**
 * @typedef {"svg" | "ascii" | "unicode"} OutputMode
 */

/**
 * @typedef {"auto" | "dagre" | "elk" | "railway"} LayoutEngine
 */

/**
 * @typedef {"down" | "up" | "left" | "right"} Direction
 */

/**
 * @typedef {"request_length" | "invalid_utf8" | "invalid_json" |
 * "unsupported_version" | "invalid_request" | "parse" | "io" | "ir" |
 * "graph" | "config" | "layout" | "render" | "target" |
 * "result_too_large" | "unsupported_feature" | "unknown"} WasmErrorName
 */

/**
 * @typedef {object} RenderStyleOptions
 * @property {string | null} [themeName]
 * @property {number | null} [darkThemeId]
 * @property {boolean | null} [sketch]
 * @property {number | null} [pad]
 * @property {boolean | null} [center]
 * @property {Record<string, string> | null} [themeOverrides]
 * @property {Record<string, string> | null} [darkThemeOverrides]
 * @property {number | null} [scale]
 * @property {boolean | null} [noXmlTag]
 * @property {string | null} [salt]
 * @property {boolean | null} [omitVersion]
 */

/**
 * @typedef {object} RenderRequest
 * @property {string} source
 * @property {OutputMode} [output]
 * @property {LayoutEngine} [layout]
 * @property {Direction} [direction]
 * @property {string | null} [target]
 * @property {RenderStyleOptions} [render]
 */

/**
 * @typedef {object} WasmErrorMetadata
 * @property {number} kind
 * @property {WasmErrorName} name
 * @property {number} requiredLength
 */

/**
 * @typedef {object} RenderSuccess
 * @property {true} ok
 * @property {Uint8Array} body
 * @property {string} text
 * @property {null} error
 */

/**
 * @typedef {object} RenderFailure
 * @property {false} ok
 * @property {Uint8Array} body
 * @property {string} text
 * @property {WasmErrorMetadata} error
 */

/** @typedef {RenderSuccess | RenderFailure} RenderResult */

/**
 * @typedef {object} SourcePoint
 * @property {number} line One-based line.
 * @property {number} column One-based column.
 * @property {number} [offset] Zero-based UTF-16 offset when available.
 */

/**
 * @typedef {object} SourceRange
 * @property {SourcePoint} start
 * @property {SourcePoint} end Exclusive end.
 */

/**
 * @typedef {object} DiagoDiagnostic
 * @property {"diago"} source
 * @property {"error"} severity
 * @property {string} code
 * @property {string} message
 * @property {string} documentId
 * @property {string} blockId
 * @property {SourceRange} [range]
 * @property {WasmErrorMetadata} wasm
 */

/**
 * @typedef {object} DiagramRenderOptions
 * @property {string | null} [themeName]
 * @property {number | null} [darkThemeId]
 * @property {number | null} [pad]
 * @property {boolean | null} [center]
 * @property {Record<string, string> | null} [themeOverrides]
 * @property {Record<string, string> | null} [darkThemeOverrides]
 * @property {number | null} [scale]
 */

/**
 * @typedef {object} DiagramOptions
 * @property {LayoutEngine} [layout]
 * @property {Direction} [direction]
 * @property {string | null} [target]
 * @property {DiagramRenderOptions} [render]
 */

/**
 * @typedef {{
 *   readonly abiVersion: number,
 *   readonly transferCapacity: number,
 *   render: (request: RenderRequest) => RenderResult,
 * }} Renderer
 */
