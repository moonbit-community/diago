///|
fn[Engine : @engine_api.LayoutEngine] custom_diagram(
  source : String,
  engine : Engine,
  measurer : @fonts.Measurer?,
) -> @diagram.Diagram raise {
  let compiled = @compiler.compile_graph("custom-font", source).unwrap()
  let graph = @engine_api.layout_with_engine(
    engine,
    compiled.graph_input(),
    @engine_api.LayoutConfig::new().with_measurer(measurer),
    Down,
  )
  @diagram.from_graph(graph, compiled.source_config())
}

///|
fn[Engine : @engine_api.LayoutEngine] check_custom_layout(
  engine : Engine,
) -> Unit raise {
  let requests : Array[@fonts.MeasureRequest] = []
  let measurer = Some(
    @fonts.Measurer::new(fn(request) {
      requests.push(request)
      { width: 400.0, height: 100.0, }
    }),
  )
  let source = "a: Alpha\na -> b: Message\nextra: { shape: class; field: string }"
  let original = custom_diagram(source, engine, None)
  let custom = custom_diagram(source, engine, measurer)
  let original_box = original.find_object("a").unwrap().get_box().unwrap()
  let custom_box = custom.find_object("a").unwrap().get_box().unwrap()
  assert_true(custom_box.width > original_box.width)
  assert_true(custom_box.height > original_box.height)
  assert_true(custom.connections[0].label_box.unwrap().width >= 400.0)
  assert_true(custom.connections[0].label_box.unwrap().height >= 100.0)
  let count_after_layout = requests.length()
  let svg = @renderer_svg_core.render(
    custom,
    @renderer_svg_core.SvgConfig::new().with_measurer(measurer),
    fonts=fn(_) { Some(Url("https://example.test/arbitrary-typeface.woff2")) },
  )
  assert_true(requests.length() > count_after_layout)
  assert_true(svg.contains("https://example.test/arbitrary-typeface.woff2"))
  assert_true(svg.contains("Alpha"))
  let after = custom_diagram(source, engine, None)
  assert_eq(after.find_object("a").unwrap().get_box().unwrap(), original_box)
  let nested_sources = [
    ("grid: { grid-columns: 2; a: Alpha; b: Beta }", "grid.a"),
    ("shape: sequence_diagram\na: Alpha\na -> b: Message", "a"),
    ("a: { shape: class; field: string; method(): bool }", "a"),
    (
      "a: { shape: sql_table; id: int {constraint: primary_key}; name: text }", "a",
    ),
    ("a: |md\n  # Heading\n  **Bold** and `code`\n|", "a"),
  ]
  for (source, id) in nested_sources {
    let original = custom_diagram(source, engine, None)
    let custom = custom_diagram(source, engine, measurer)
    let original_box = original.find_object(id).unwrap().get_box().unwrap()
    let custom_box = custom.find_object(id).unwrap().get_box().unwrap()
    assert_true(custom_box.width > original_box.width, msg=source)
  }
}

///|
test "Dagre applies custom measurements to ordinary and structured labels" {
  check_custom_layout(@engine_dagre.DagreEngine::new())
}

///|
test "ELK applies custom measurements to ordinary and structured labels" {
  check_custom_layout(@engine_elk.ElkEngine::new())
}

///|
test "Railway applies custom measurements to ordinary and structured labels" {
  check_custom_layout(@engine_railway.RailwayEngine::new())
}
