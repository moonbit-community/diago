const LAYOUTS = new Set(["auto", "dagre", "elk", "railway"]);
const DIRECTIONS = new Set(["down", "up", "left", "right"]);
const OPTION_KEYS = new Set([
  "renderer",
  "diagram",
  "documentId",
  "onDiagnostic",
]);
const DIAGRAM_KEYS = new Set(["layout", "direction", "target", "render"]);
const RENDER_KEYS = new Set([
  "themeName",
  "darkThemeId",
  "pad",
  "center",
  "themeOverrides",
  "darkThemeOverrides",
  "scale",
]);

/** @param {unknown} value */
function isPlainObject(value) {
  return (
    value !== null &&
    typeof value === "object" &&
    (Object.getPrototypeOf(value) === Object.prototype ||
      Object.getPrototypeOf(value) === null)
  );
}

/**
 * @param {Record<string, unknown>} value
 * @param {Set<string>} allowed
 * @param {string} label
 */
function rejectUnknownKeys(value, allowed, label) {
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      throw new TypeError(`unknown ${label} option \`${key}\``);
    }
  }
}

/**
 * @param {unknown} value
 * @param {string} label
 */
function nullableString(value, label) {
  if (value !== undefined && value !== null && typeof value !== "string") {
    throw new TypeError(`${label} must be a string or null`);
  }
}

/**
 * @param {unknown} value
 * @param {string} label
 */
function nullableNumber(value, label) {
  if (
    value !== undefined &&
    value !== null &&
    (typeof value !== "number" || !Number.isFinite(value))
  ) {
    throw new TypeError(`${label} must be a finite number or null`);
  }
}

/**
 * @param {unknown} value
 * @param {string} label
 */
function nullableBoolean(value, label) {
  if (value !== undefined && value !== null && typeof value !== "boolean") {
    throw new TypeError(`${label} must be a boolean or null`);
  }
}

/**
 * @param {unknown} value
 * @param {string} label
 */
function nullableStringRecord(value, label) {
  if (value === undefined || value === null) return;
  if (!isPlainObject(value)) {
    throw new TypeError(`${label} must be an object or null`);
  }
  for (const [key, entry] of Object.entries(value)) {
    if (typeof entry !== "string") {
      throw new TypeError(`${label}.${key} must be a string`);
    }
  }
}

/**
 * @param {unknown} options
 * @param {import("../index.js").Renderer} defaultRenderer
 */
export function normalizeAdapterOptions(options, defaultRenderer) {
  if (options === undefined) options = {};
  if (!isPlainObject(options)) {
    throw new TypeError("adapter options must be an object");
  }
  const raw = /** @type {Record<string, unknown>} */ (options);
  rejectUnknownKeys(raw, OPTION_KEYS, "adapter");

  const renderer = raw.renderer ?? defaultRenderer;
  if (
    renderer === null ||
    typeof renderer !== "object" ||
    typeof /** @type {{render?: unknown}} */ (renderer).render !== "function"
  ) {
    throw new TypeError("renderer must implement render(request)");
  }
  if (
    raw.documentId !== undefined &&
    typeof raw.documentId !== "string" &&
    typeof raw.documentId !== "function"
  ) {
    throw new TypeError("documentId must be a string or function");
  }
  if (typeof raw.documentId === "string" && raw.documentId.trim() === "") {
    throw new TypeError("documentId must not be empty");
  }
  if (raw.onDiagnostic !== undefined && typeof raw.onDiagnostic !== "function") {
    throw new TypeError("onDiagnostic must be a function");
  }

  const diagram = raw.diagram ?? {};
  if (!isPlainObject(diagram)) {
    throw new TypeError("diagram must be an object");
  }
  const diagramRaw = /** @type {Record<string, unknown>} */ (diagram);
  rejectUnknownKeys(diagramRaw, DIAGRAM_KEYS, "diagram");
  if (
    diagramRaw.layout !== undefined &&
    (typeof diagramRaw.layout !== "string" ||
      !LAYOUTS.has(diagramRaw.layout))
  ) {
    throw new TypeError("diagram.layout must be auto, dagre, elk, or railway");
  }
  if (
    diagramRaw.direction !== undefined &&
    (typeof diagramRaw.direction !== "string" ||
      !DIRECTIONS.has(diagramRaw.direction))
  ) {
    throw new TypeError("diagram.direction must be down, up, left, or right");
  }
  nullableString(diagramRaw.target, "diagram.target");

  const render = diagramRaw.render ?? {};
  if (!isPlainObject(render)) {
    throw new TypeError("diagram.render must be an object");
  }
  const renderRaw = /** @type {Record<string, unknown>} */ (render);
  rejectUnknownKeys(renderRaw, RENDER_KEYS, "diagram.render");
  nullableString(renderRaw.themeName, "diagram.render.themeName");
  nullableNumber(renderRaw.darkThemeId, "diagram.render.darkThemeId");
  nullableNumber(renderRaw.pad, "diagram.render.pad");
  nullableBoolean(renderRaw.center, "diagram.render.center");
  nullableStringRecord(renderRaw.themeOverrides, "diagram.render.themeOverrides");
  nullableStringRecord(
    renderRaw.darkThemeOverrides,
    "diagram.render.darkThemeOverrides",
  );
  nullableNumber(renderRaw.scale, "diagram.render.scale");

  const normalizedRender = {
    ...renderRaw,
    ...(renderRaw.themeOverrides === undefined || renderRaw.themeOverrides === null
      ? {}
      : {
          themeOverrides: Object.freeze({
            .../** @type {Record<string, string>} */ (renderRaw.themeOverrides),
          }),
        }),
    ...(renderRaw.darkThemeOverrides === undefined ||
    renderRaw.darkThemeOverrides === null
      ? {}
      : {
          darkThemeOverrides: Object.freeze({
            .../** @type {Record<string, string>} */ (
              renderRaw.darkThemeOverrides
            ),
          }),
        }),
  };
  return Object.freeze({
    renderer: /** @type {import("../index.js").Renderer} */ (renderer),
    diagram: Object.freeze({
      ...diagramRaw,
      render: Object.freeze(normalizedRender),
    }),
    documentId: raw.documentId,
    onDiagnostic: raw.onDiagnostic,
  });
}
