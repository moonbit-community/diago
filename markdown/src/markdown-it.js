import { getDefaultRenderer } from "./index.js";
import { createFenceSession, isDiagoInfo } from "./internal/fence.js";
import { resolveDocumentId } from "./internal/identity.js";
import { normalizeAdapterOptions } from "./internal/options.js";
import { VITEPRESS_RENDER_SVG } from "./internal/vitepress.js";

/** @typedef {import("markdown-it").default} MarkdownIt */
/** @typedef {import("markdown-it/lib/token.mjs").default} Token */
/** @typedef {import("./index.js").DiagoDiagnostic} DiagoDiagnostic */

const defaultRenderer = await getDefaultRenderer();
const INSTALLED = Symbol.for("diago.markdown-it.installed");
const RESULT = Symbol("diago.fence.result");

/**
 * @typedef {object} MarkdownItContext
 * @property {Record<string, unknown>} env
 * @property {string} source
 */

/**
 * @typedef {object} MarkdownItAdapterOptions
 * @property {import("./index.js").Renderer} [renderer]
 * @property {import("./index.js").DiagramOptions} [diagram]
 * @property {string | ((context: MarkdownItContext) => string | undefined)} [documentId]
 * @property {(diagnostic: DiagoDiagnostic) => void} [onDiagnostic]
 */

/**
 * @param {string} source
 * @returns {number[]}
 */
function lineOffsets(source) {
  const offsets = [0];
  for (let index = 0; index < source.length; index += 1) {
    if (source.charCodeAt(index) === 10) offsets.push(index + 1);
  }
  return offsets;
}

/**
 * @param {Token} token
 * @param {number[]} offsets
 * @param {number} sourceLength
 */
function tokenRange(token, offsets, sourceLength) {
  if (token.map === null) return undefined;
  const [startLine, endLine] = token.map;
  return {
    start: {
      line: startLine + 1,
      column: 1,
      offset: offsets[startLine] ?? sourceLength,
    },
    end: {
      line: endLine + 1,
      column: 1,
      offset: offsets[endLine] ?? sourceLength,
    },
  };
}

/**
 * @param {Record<string, unknown>} env
 * @param {DiagoDiagnostic} diagnostic
 */
function recordDiagnostic(env, diagnostic) {
  const existing = env.diagoDiagnostics;
  if (existing === undefined) {
    env.diagoDiagnostics = [diagnostic];
  } else if (Array.isArray(existing)) {
    existing.push(diagnostic);
  } else {
    throw new TypeError("env.diagoDiagnostics must be an array when present");
  }
}

/**
 * @param {MarkdownIt} md
 * @param {MarkdownItAdapterOptions} [options]
 */
export default function markdownItDiago(md, options) {
  const marked = /** @type {MarkdownIt & {[INSTALLED]?: boolean}} */ (md);
  if (marked[INSTALLED]) {
    throw new Error("diago is already installed on this markdown-it instance");
  }
  const normalized = normalizeAdapterOptions(options, defaultRenderer);
  const configuredRenderSvg =
    options !== null && typeof options === "object"
      ? Reflect.get(options, VITEPRESS_RENDER_SVG)
      : undefined;
  if (
    configuredRenderSvg !== undefined &&
    typeof configuredRenderSvg !== "function"
  ) {
    throw new TypeError("internal SVG renderer must be a function");
  }
  /** @type {(svg: string) => string} */
  const renderSvg = configuredRenderSvg ?? ((svg) => svg);
  const fallback = md.renderer.rules.fence;
  if (fallback === undefined) {
    throw new Error("markdown-it does not provide a fence renderer");
  }
  marked[INSTALLED] = true;

  md.core.ruler.after("block", "diago", (state) => {
    const env = /** @type {Record<string, unknown>} */ (state.env);
    const context = { env, source: state.src };
    const documentId = resolveDocumentId(
      normalized.documentId,
      context,
      [env.relativePath, env.path],
      state.src,
    );
    const session = createFenceSession({
      documentId,
      renderer: normalized.renderer,
      diagram: normalized.diagram,
      recordDiagnostic: (diagnostic) => recordDiagnostic(env, diagnostic),
      onDiagnostic:
        /** @type {((diagnostic: DiagoDiagnostic) => void) | undefined} */ (
          normalized.onDiagnostic
        ),
    });
    const offsets = lineOffsets(state.src);
    for (const token of state.tokens) {
      if (token.type !== "fence" || !isDiagoInfo(token.info)) continue;
      const result = session.compile(
        token.content,
        tokenRange(token, offsets, state.src.length),
      );
      const meta = token.meta ?? {};
      Object.defineProperty(meta, RESULT, { value: result });
      token.meta = meta;
    }
  });

  md.renderer.rules.fence = (tokens, index, renderOptions, env, renderer) => {
    const meta = tokens[index].meta;
    const result = meta?.[RESULT];
    if (result?.ok === true) return renderSvg(result.svg);
    return fallback(tokens, index, renderOptions, env, renderer);
  };
}
