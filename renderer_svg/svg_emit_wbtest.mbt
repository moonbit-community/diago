///|
test "reference legend corpus ignores custom entries" {
  let legend = @graph.LegendInput::from_parts(
    Some("Legendary"),
    TopRight,
    [
      @graph.LegendEntryInput::shape(Rectangle, "Node", None),
      @graph.LegendEntryInput::connection(None, Triangle, "Edge", None),
      @graph.LegendEntryInput::custom("https://example.com/icon.svg", "Custom"),
    ],
    None,
    None,
    0.0,
    0.0,
    0.0,
  )
  @debug.assert_eq(d2_legend_corpus(legend), "LegendaryNodeEdge")
}

///|
test "reference legend corpus uses fallback title when empty" {
  let legend = @graph.LegendInput::from_parts(
    Some(""),
    TopRight,
    [@graph.LegendEntryInput::shape(Rectangle, "Node", None)],
    None,
    None,
    0.0,
    0.0,
    0.0,
  )
  @debug.assert_eq(d2_legend_corpus(legend), "LegendNode")
}

///|
fn test_diagram_for_scope_hash() -> @diagram.Diagram {
  let graph = @graph.GraphInput::from_parts(
    "hash-test",
    @graph.ObjectInput::new("root"),
    [
      @graph.ObjectInput::from_parts(
        "node",
        "Node",
        Rectangle,
        @graph.StyleInput::new(),
        None,
        None,
        [],
        0,
        None,
        None,
        None,
        [],
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
      ),
    ],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    None,
  )
  @diagram.from_graph(graph, None)
}

///|
test "diagram scope class follows diagram hash id instead of svg config font settings" {
  let diagram = test_diagram_for_scope_hash()
  let base = SvgConfig::new()
  let font_variant = {
    ..SvgConfig::new(),
    font_family: "monospace",
    font_size: 24,
  }
  let salted = { ..font_variant, salt: Some("salt"), }

  @debug.assert_eq(diagram_scope_class(diagram, base), diagram.hash_id(None))
  @debug.assert_eq(
    diagram_scope_class(diagram, font_variant),
    diagram.hash_id(None),
  )
  @debug.assert_eq(
    diagram_scope_class(diagram, base),
    diagram_scope_class(diagram, font_variant),
  )
  @debug.assert_eq(
    diagram_scope_class(diagram, salted),
    diagram.hash_id(Some("salt")),
  )
}

///|
test "svg identity formatting preserves quoted syntax paths" {
  @debug.assert_eq(d2_output_abs_id("\"a.b\""), "\"a.b\"")
  @debug.assert_eq(d2_output_abs_id("a.b"), "a.b")
  @debug.assert_eq(d2_output_abs_id("outer.\"a.b\""), "outer.\"a.b\"")
  @debug.assert_eq(
    d2_output_abs_id("outer.\"line\\nnext\""),
    "outer.\"line\\nnext\"",
  )
  assert_true(
    d2_shape_wrapper_class("\"a.b\"") != d2_shape_wrapper_class("a.b"),
    msg="quoted-dot and nested identities need distinct SVG wrapper classes",
  )
}
