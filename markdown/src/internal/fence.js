import {
  blockIdentity,
  canonicalizeFenceSource,
  sha256,
} from "./identity.js";
import { createDiagnostic } from "./diagnostics.js";

/** @typedef {import("../index.js").SourceRange} SourceRange */
/** @typedef {import("../index.js").DiagoDiagnostic} DiagoDiagnostic */

/**
 * @param {object} input
 * @param {string} input.documentId
 * @param {import("../index.js").Renderer} input.renderer
 * @param {Record<string, unknown>} input.diagram
 * @param {(diagnostic: DiagoDiagnostic) => void} input.recordDiagnostic
 * @param {((diagnostic: DiagoDiagnostic) => void) | undefined} input.onDiagnostic
 */
export function createFenceSession({
  documentId,
  renderer,
  diagram,
  recordDiagnostic,
  onDiagnostic,
}) {
  /** @type {Map<string, number>} */
  const occurrences = new Map();

  return Object.freeze({
    /**
     * @param {string} source
     * @param {SourceRange | undefined} range
     */
    compile(source, range) {
      const canonicalSource = canonicalizeFenceSource(source);
      const sourceDigest = sha256(canonicalSource);
      const occurrence = occurrences.get(sourceDigest) ?? 0;
      occurrences.set(sourceDigest, occurrence + 1);
      const { blockId, salt } = blockIdentity(
        documentId,
        sourceDigest,
        occurrence,
      );
      const configuredRender =
        diagram.render !== null && typeof diagram.render === "object"
          ? /** @type {Record<string, unknown>} */ (diagram.render)
          : {};
      const request = {
        ...diagram,
        source: canonicalSource,
        output: "svg",
        render: {
          ...configuredRender,
          noXmlTag: true,
          salt,
        },
      };
      const result = renderer.render(
        /** @type {import("../index.js").RenderRequest} */ (request),
      );
      if (result.ok) {
        return Object.freeze({ ok: true, svg: result.text, blockId });
      }
      const diagnostic = createDiagnostic({
        message: result.text,
        documentId,
        blockId,
        range,
        wasm: result.error,
      });
      recordDiagnostic(diagnostic);
      onDiagnostic?.(diagnostic);
      return Object.freeze({ ok: false, diagnostic, blockId });
    },
  });
}

/** @param {string} info */
export function isDiagoInfo(info) {
  return info.trim() === "diago";
}
