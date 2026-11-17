# SVG with external font sources

This package renders a laid-out `diagram.Diagram` without importing the bundled
TTF assets. Supply a `fonts.Resolver` for the font roles actually needed by the
SVG. A missing requested role produces a rendering error.

Use the compiler and a chosen engine directly to keep the full facade and its
bundled assets out of the dependency graph:

```moonbit check
///|
test {
  let compiled = @compiler.compile_graph("diagram", "a -> b").unwrap()
  let graph = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    compiled.graph_input(),
    @engine_api.LayoutConfig::new(),
    Down,
  )
  let diagram = @diagram.from_graph(graph, compiled.source_config())
  let fonts : @fonts.Resolver = fn(face) {
    Some(Url("https://example.test/fonts/\{face.name()}.ttf"))
  }
  let svg = @renderer_svg_core.render(
    diagram,
    @renderer_svg_core.SvgConfig::new(),
    fonts~,
  )
  inspect(
    svg.contains("https://example.test/fonts/sans-bold.ttf"),
    content="true",
  )
  inspect(svg.contains("data:application/font-woff"), content="false")
}
```

Two source types are supported:

- `fonts.Source::Ttf(bytes)` subsets a loaded TrueType font to the diagram's
  characters, converts it to WOFF, and embeds it in the SVG. This keeps the SVG
  self-contained. Invalid input produces a rendering error.
- `fonts.Source::Url(url)` writes the URL into `@font-face`; the SVG consumer
  must make that resource available. The core does not fetch the URL.

Resolve filesystem and network resources in the host before rendering. For
example, a browser can load and cache TTF bytes asynchronously, then make them
available through a synchronous resolver. Callers can supply only the faces
their diagrams require. The optional `fonts/builtin.resolve` resolver provides
all seven original assets when self-contained bundled fonts are preferred.

## Arbitrary typefaces and custom measurements

The roles are `SansRegular`, `SansBold`, `SansSemibold`, `SansItalic`,
`MonoRegular`, `MonoBold`, and `MonoItalic`. They identify styling roles, not
fixed font families. A resolver can map them to any supported typeface, and
can return the same source for every role when only one font is wanted.

For a replacement typeface, create a `fonts.Measurer` backed by that font's
metrics and pass the **same measurer to layout and rendering**. Load the fonts
before calling either operation. The synchronous callback can delegate to a
browser canvas, a native font library, or your own measurement tables. The
following checked example uses the built-in metrics as a fallback; replace
the callback body with your host's measurement implementation for other fonts:

```moonbit check
///|
test {
  let measurer = @fonts.Measurer::new(fn(request) {
    let measured = @text_metrics.measure_builtin(request)
    { width: measured.max_line_width, height: measured.dimensions.height, }
  })
  let compiled = @compiler.compile_graph("diagram", "a -> b").unwrap()
  let graph = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    compiled.graph_input(),
    @engine_api.LayoutConfig::new().with_measurer(Some(measurer)),
    Down,
  )
  let svg = @renderer_svg_core.render(
    @diagram.from_graph(graph, compiled.source_config()),
    @renderer_svg_core.SvgConfig::new().with_measurer(Some(measurer)),
    fonts=fn(face) {
      Some(Url("https://example.test/fonts/\{face.name()}.ttf"))
    },
  )
  inspect(svg.contains("<svg"), content="true")
}
```

Each `fonts.MeasureRequest` contains `text`, `font_size` in pixels, `face`,
`bounds_with_dot`, and `code_line_height`. Return finite, nonnegative pixel
`width` and `height` for the entire text run, including newlines and spaces;
width is the maximum line width. Do not round your result. Diago rounds label
bounds up and retains fractional widths while composing Markdown runs.
`bounds_with_dot` requests pen-advance bounds (including trailing whitespace)
for Markdown/code, while `code_line_height` requests the code-label line-height
convention.
The callback owns measurement for every requested role; it can call
`text_metrics.measure_builtin` explicitly for selected fallback roles.

Custom measurements apply to Dagre, ELK, Railway, grids, sequence diagrams,
class/SQL labels, Markdown, and renderer label bounds. Markdown keeps its
existing block spacing and HTML/CSS layout rules; this callback measures text
runs rather than replacing the browser's HTML layout engine. There is no
global measurement setting: separate calls can use different fonts safely.
`AsciiConfig` and `LegendLayoutConfig` also offer `with_measurer` for direct
renderer/layout use.

Without a measurer, layout uses the original Source Sans Pro and Source Code
Pro tables. Changing a URL or supplying TTF bytes alone does not replace those
tables or extract measurements from the font.

Export the original matching font assets for hosting with:

```bash
node scripts/export_font_assets.mjs _build/font-assets
```

This writes `sans-regular.ttf`, `sans-bold.ttf`, `sans-semibold.ttf`,
`sans-italic.ttf`, `mono-regular.ttf`, `mono-bold.ttf`, and `mono-italic.ttf`.
Serve the directory at the base URL used by the resolver. URL sources can also
reference WOFF or WOFF2 versions of the matching faces.

Existing imports of `renderer_svg` and the root facade keep bundled-font
behavior. Use `renderer_svg_core` directly to avoid linking those assets.
