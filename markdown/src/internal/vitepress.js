export const VITEPRESS_RENDER_SVG = Symbol("diago.vitepress.render-svg");

/** @param {string} value */
function escapeSingleQuotedAttribute(value) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("'", "&#39;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

/** @param {string} svg */
export function renderVitePressSvg(svg) {
  const expression = JSON.stringify(svg)
    .replaceAll("\u2028", "\\u2028")
    .replaceAll("\u2029", "\\u2029");
  return `<div class="diago" v-html='${escapeSingleQuotedAttribute(expression)}'></div>`;
}
