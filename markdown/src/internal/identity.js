import { createHash } from "node:crypto";
import { isAbsolute, relative } from "node:path";

/** @param {string} value */
export function sha256(value) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

/** @param {string} source */
export function canonicalizeFenceSource(source) {
  const normalized = source.replace(/\r\n?/g, "\n");
  return normalized.endsWith("\n") ? normalized.slice(0, -1) : normalized;
}

/**
 * @param {string} value
 * @param {boolean} hostPath
 */
export function normalizeDocumentId(value, hostPath) {
  let normalized = value.trim();
  if (normalized === "") {
    throw new TypeError("documentId must not be empty");
  }
  if (hostPath && isAbsolute(normalized)) {
    normalized = relative(process.cwd(), normalized);
  }
  return normalized.replaceAll("\\", "/");
}

/**
 * @param {unknown} configured
 * @param {unknown} context
 * @param {unknown[]} hostCandidates
 * @param {string} markdownSource
 */
export function resolveDocumentId(
  configured,
  context,
  hostCandidates,
  markdownSource,
) {
  if (typeof configured === "function") {
    const resolved = configured(context);
    if (resolved !== undefined) {
      if (typeof resolved !== "string") {
        throw new TypeError("documentId resolver must return a string or undefined");
      }
      return normalizeDocumentId(resolved, false);
    }
  } else if (configured !== undefined) {
    if (typeof configured !== "string") {
      throw new TypeError("documentId must be a string or function");
    }
    return normalizeDocumentId(configured, false);
  }

  for (const candidate of hostCandidates) {
    if (typeof candidate === "string" && candidate.trim() !== "") {
      return normalizeDocumentId(candidate, true);
    }
  }
  return `content:${sha256(markdownSource)}`;
}

/**
 * @param {string} documentId
 * @param {string} sourceDigest
 * @param {number} occurrence
 */
export function blockIdentity(documentId, sourceDigest, occurrence) {
  const digest = sha256(`${documentId}\0${sourceDigest}\0${occurrence}`);
  const blockId = `diago-${digest.slice(0, 24)}`;
  return { blockId, salt: `markdown:${blockId}` };
}
