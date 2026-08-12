import markdownItDiago from "./markdown-it.js";
import {
  renderVitePressSvg,
  VITEPRESS_RENDER_SVG,
} from "./internal/vitepress.js";

/** @typedef {import("./markdown-it.js").MarkdownItAdapterOptions} MarkdownItAdapterOptions */
/** @typedef {import("./index.js").DiagoDiagnostic} DiagoDiagnostic */

/** @param {DiagoDiagnostic} diagnostic */
function formatDiagnostic(diagnostic) {
  const point = diagnostic.range?.start;
  const location = point
    ? `${diagnostic.documentId}:${point.line}:${point.column}`
    : diagnostic.documentId;
  return `${location} error [${diagnostic.code}] ${diagnostic.message}`;
}

/**
 * @param {MarkdownItAdapterOptions} [options]
 * @returns {NonNullable<import("vitepress").UserConfig["markdown"]>["config"]}
 */
export default function vitepressDiago(options = {}) {
  if (options === null || typeof options !== "object" || Array.isArray(options)) {
    throw new TypeError("adapter options must be an object");
  }
  const configured = {
    ...options,
    [VITEPRESS_RENDER_SVG]: renderVitePressSvg,
    onDiagnostic: options.onDiagnostic ?? ((diagnostic) => {
      console.error(formatDiagnostic(diagnostic));
    }),
  };
  return (md) => {
    markdownItDiago(
      /** @type {import("./markdown-it.js").MarkdownIt} */ (
        /** @type {unknown} */ (md)
      ),
      configured,
    );
  };
}
