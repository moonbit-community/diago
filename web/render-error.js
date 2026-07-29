export function formatRenderErrorMessage(result) {
  const text = result.text.trim();
  if (text.length === 0) {
    return "Failed to render diagram.";
  }
  if (result.error.name === "parse") {
    return text;
  }
  if (
    result.error.name === "ir" ||
    result.error.name === "graph" ||
    result.error.name === "config" ||
    result.error.name === "layout"
  ) {
    return "Failed to layout diagram. Please check syntax and connections.";
  }
  return text;
}
