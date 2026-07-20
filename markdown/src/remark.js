import { getDefaultRenderer } from "./index.js";
import { createFenceSession, isDiagoInfo } from "./internal/fence.js";
import { resolveDocumentId } from "./internal/identity.js";
import { normalizeAdapterOptions } from "./internal/options.js";

/** @typedef {import("mdast").Root} Root */
/** @typedef {import("mdast").RootContent} RootContent */
/** @typedef {import("mdast").Parent} Parent */
/** @typedef {import("vfile").VFile} VFile */
/** @typedef {import("./index.js").DiagoDiagnostic} DiagoDiagnostic */

const defaultRenderer = await getDefaultRenderer();

/**
 * @typedef {object} RemarkContext
 * @property {VFile} file
 * @property {Root} tree
 * @property {string} source
 */

/**
 * @typedef {object} RemarkAdapterOptions
 * @property {import("./index.js").Renderer} [renderer]
 * @property {import("./index.js").DiagramOptions} [diagram]
 * @property {string | ((context: RemarkContext) => string | undefined)} [documentId]
 * @property {(diagnostic: DiagoDiagnostic) => void} [onDiagnostic]
 */

/** @param {import("unist").Position | undefined} position */
function sourceRange(position) {
  if (position === undefined) return undefined;
  return {
    start: {
      line: position.start.line,
      column: position.start.column,
      ...(position.start.offset === undefined
        ? {}
        : { offset: position.start.offset }),
    },
    end: {
      line: position.end.line,
      column: position.end.column,
      ...(position.end.offset === undefined ? {} : { offset: position.end.offset }),
    },
  };
}

/**
 * @param {VFile} file
 * @param {DiagoDiagnostic} diagnostic
 */
function recordDiagnostic(file, diagnostic) {
  const existing = file.data.diagoDiagnostics;
  if (existing === undefined) {
    file.data.diagoDiagnostics = [diagnostic];
  } else if (Array.isArray(existing)) {
    existing.push(diagnostic);
  } else {
    throw new TypeError("file.data.diagoDiagnostics must be an array when present");
  }
  const message = file.message(
    diagnostic.message,
    diagnostic.range,
    `diago:${diagnostic.code}`,
  );
  message.fatal = false;
}

/**
 * @param {Parent} parent
 * @param {(node: import("mdast").Code, parent: Parent, index: number) => void} visitCode
 */
function walk(parent, visitCode) {
  for (let index = 0; index < parent.children.length; index += 1) {
    const node = parent.children[index];
    if (node.type === "code") {
      visitCode(node, parent, index);
    } else if ("children" in node && Array.isArray(node.children)) {
      walk(/** @type {Parent} */ (node), visitCode);
    }
  }
}

/**
 * @param {RemarkAdapterOptions} [options]
 * @returns {import("unified").Transformer<Root>}
 */
export default function remarkDiago(options) {
  const normalized = normalizeAdapterOptions(options, defaultRenderer);
  return (tree, file) => {
    const source = String(file.value);
    const context = { file, tree, source };
    const documentId = resolveDocumentId(
      normalized.documentId,
      context,
      [file.path],
      source,
    );
    const session = createFenceSession({
      documentId,
      renderer: normalized.renderer,
      diagram: normalized.diagram,
      recordDiagnostic: (diagnostic) => recordDiagnostic(file, diagnostic),
      onDiagnostic:
        /** @type {((diagnostic: DiagoDiagnostic) => void) | undefined} */ (
          normalized.onDiagnostic
        ),
    });
    walk(tree, (node, parent, index) => {
      const info = node.meta === null ? (node.lang ?? "") : `${node.lang ?? ""} ${node.meta}`;
      if (!isDiagoInfo(info)) return;
      const result = session.compile(node.value, sourceRange(node.position));
      if (result.ok) {
        parent.children[index] = /** @type {RootContent} */ ({
          type: "html",
          value: result.svg,
        });
      }
    });
  };
}
