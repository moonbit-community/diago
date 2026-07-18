///|
test "syntax_path_last_display preserves quoted dots and escapes" {
  @debug.assert_eq(
    syntax_path_last_display("alpha.\"beta.gamma\""),
    "beta.gamma",
  )
  @debug.assert_eq(syntax_path_last_display("alpha.'beta.gamma'"), "beta.gamma")
  @debug.assert_eq(
    syntax_path_last_display("alpha.\"+peek\\\"()\""),
    "+peek\"()",
  )
  @debug.assert_eq(syntax_path_last_display("alpha.rewind()"), "rewind()")
}

///|
test "layout default font is recursive and preserves explicit styles" {
  let graph = GraphInput::new("root")
  let defaulted = graph.with_default_font("mono")
  @debug.assert_eq(
    defaulted.root.style.font,
    Some(StyleValue::from_string("mono")),
  )

  let explicit_style = {
    ..StyleInput::new(),
    font: Some(StyleValue::from_string("serif")),
  }
  let explicit_root = { ..ObjectInput::new("root"), style: explicit_style }
  let explicit_graph = { ..GraphInput::new("root"), root: explicit_root }.with_default_font(
    "mono",
  )
  @debug.assert_eq(
    explicit_graph.root.style.font,
    Some(StyleValue::from_string("serif")),
  )
}

///|
test "theme caps lock is recursive and respects D2 exemptions" {
  let plain = ObjectInput::new("plain")
  let code = { ..ObjectInput::new("code"), shape_type: Code }
  let latex = { ..ObjectInput::new("latex"), language: Some("latex") }
  let none_style = {
    ..StyleInput::new(),
    text_transform: Some(StyleValue::from_string("none")),
  }
  let exempt = { ..ObjectInput::new("exempt"), style: none_style }
  let edge = EdgeInput::new(0, "plain", "code", false, true)
  let graph = {
    ..GraphInput::new("root"),
    objects: [plain, code, latex, exempt],
    edges: [{ ..edge, label: "edge label" }],
  }.with_caps_lock()
  @debug.assert_eq(graph.objects[0].label, "PLAIN")
  @debug.assert_eq(graph.objects[1].label, "code")
  @debug.assert_eq(graph.objects[2].label, "latex")
  @debug.assert_eq(graph.objects[3].label, "exempt")
  @debug.assert_eq(graph.edges[0].label, "EDGE LABEL")
}
