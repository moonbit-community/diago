///|
fn diagram_from_source(source : String) -> @diagram.Diagram raise {
  let compiled = @compiler.compile_graph("external-fonts", source).unwrap()
  let graph = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    compiled.graph_input(),
    @engine_api.LayoutConfig::new(),
    Down,
  )
  @diagram.from_graph(graph, compiled.source_config())
}

///|
test "URL fonts are resolved on demand without bundled assets" {
  let diagram = diagram_from_source("a: { style.bold: false }")
  let requested : Array[@fonts.Face] = []
  let svg = @renderer_svg_core.render(
    diagram,
    @renderer_svg_core.SvgConfig::new(),
    fonts=fn(face) {
      requested.push(face)
      match face {
        SansRegular => Some(Url("https://example.test/fonts/regular.woff2"))
        _ => None
      }
    },
  )
  inspect(requested.length(), content="1")
  assert_true(requested[0] == SansRegular)
  assert_true(svg.contains("url(\"https://example.test/fonts/regular.woff2\")"))
  assert_false(svg.contains("data:application/font-woff"))
}

///|
test "injected TTF sources preserve every bundled font role" {
  let source =
    #|regular: { style.bold: false }
    #|bold: { style.bold: true }
    #|italic: { style.bold: false; style.italic: true }
    #|mono: { style.font: mono; style.bold: false }
    #|mono_bold: { style.font: mono; style.bold: true }
    #|mono_italic: { style.font: mono; style.bold: false; style.italic: true }
    #|markdown: |md
    #|  # Heading
    #|  Text **bold** *italic* `code`
    #||
    #|code: |js
    #|  // comment
    #|  function f() { return 1 + 2; }
    #||
  let diagram = diagram_from_source(source)
  let config = @renderer_svg_core.SvgConfig::new()
  let seen : Map[@fonts.Face, Bool] = Map([])
  let external = @renderer_svg_core.render(diagram, config, fonts=fn(face) {
    seen[face] = true
    @builtin_fonts.resolve(face)
  })
  assert_eq(external, @bundled_svg.render(diagram, config))
  for
    face in [
      @fonts.Face::SansRegular,
      SansBold,
      SansSemibold,
      SansItalic,
      MonoRegular,
      MonoBold,
      MonoItalic,
    ] {
    assert_true(seen.contains(face), msg=face.name())
  }
}

///|
test "missing and invalid external fonts report rendering errors" {
  let diagram = diagram_from_source("a: { style.bold: false }")
  let missing = try
    @renderer_svg_core.render(diagram, @renderer_svg_core.SvgConfig::new(), fonts=fn(
      _,
    ) {
      None
    })
  catch {
    error => error.to_string()
  } noraise {
    _ => "unexpected success"
  }
  assert_true(missing.contains("missing font 'sans-regular'"))
  let invalid = try
    @renderer_svg_core.render(diagram, @renderer_svg_core.SvgConfig::new(), fonts=fn(
      _,
    ) {
      Some(Ttf(b"invalid font"))
    })
  catch {
    error => error.to_string()
  } noraise {
    _ => "unexpected success"
  }
  assert_true(invalid.contains("failed to subset embedded font"))
}

///|
test "external font URLs are escaped as CSS strings" {
  let diagram = diagram_from_source("a: { style.bold: false }")
  let svg = @renderer_svg_core.render(
    diagram,
    @renderer_svg_core.SvgConfig::new(),
    fonts=fn(_) { Some(Url("https://example.test/a\"b\\c\nd.woff2")) },
  )
  assert_true(
    svg.contains("url(\"https://example.test/a\\\"b\\\\c\\a d.woff2\")"),
  )
}
