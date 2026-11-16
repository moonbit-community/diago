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

The supported roles are `SansRegular`, `SansBold`, `SansSemibold`, `SansItalic`,
`MonoRegular`, `MonoBold`, and `MonoItalic`. Sources should use the matching
Source Sans Pro or Source Code Pro face. Measurements still come from the
existing role-specific tables; arbitrary replacement typefaces can change
visible text extents without changing the computed layout.

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
