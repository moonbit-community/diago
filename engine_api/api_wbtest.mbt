///|
test "nested grids size markdown children with markdown block metrics" {
  let markdown = @graph.ObjectInput::from_parts(
    "teleport.inp",
    "# Identity Native Proxy",
    Text,
    @graph.StyleInput::new(),
    Some(@graph.Box::new(0.0, 0.0, 300.0, 0.0)),
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
    language=Some("markdown"),
  )
  let markdown_size = semantic_object_size(markdown, LayoutConfig::new())
  @debug.assert_eq(markdown_size.0, 300.0)
  @debug.assert_eq(markdown_size.1, 51.0)

  let child_ids = ["teleport.inp", "teleport.audit", "teleport.cert"]
  let parent = @graph.ObjectInput::from_parts(
    "teleport",
    "Teleport",
    Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    child_ids,
    0,
    None,
    None,
    None,
    [],
    Some(2),
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
  let child_sizes : Map[String, (Double, Double)] = Map([
    ("teleport.inp", (300.0, 51.0)),
    ("teleport.audit", (140.0, 92.0)),
    ("teleport.cert", (173.0, 92.0)),
  ])
  let layout = estimate_grid_container_layout_like_d2(
    parent, child_ids, child_sizes,
  ).unwrap()
  @debug.assert_eq(layout.width, 473.0)
  @debug.assert_eq(layout.height, 303.0)
  let inp = layout.child_boxes["teleport.inp"]
  @debug.assert_eq(inp.x, 60.0)
  @debug.assert_eq(inp.y, 60.0)
  @debug.assert_eq(inp.width, 353.0)
  @debug.assert_eq(inp.height, 51.0)
  let audit = layout.child_boxes["teleport.audit"]
  @debug.assert_eq(audit.x, 60.0)
  @debug.assert_eq(audit.y, 151.0)
  @debug.assert_eq(audit.width, 140.0)
  @debug.assert_eq(audit.height, 92.0)
}

///|
test "constant near bounds ignore SQL member implementation nodes" {
  let field = @graph.ObjectInput::from_parts(
    "data.a",
    "int",
    Rectangle,
    @graph.StyleInput::new(),
    Some(@graph.Box::new(0.0, 0.0, 65.0, 66.0)),
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
  )
  let table = @graph.ObjectInput::from_parts(
    "data",
    "data",
    SqlTable,
    @graph.StyleInput::new(),
    Some(@graph.Box::new(12.0, 12.0, 266.0, 72.0)),
    None,
    ["data.a"],
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
  )
  let root = @graph.ObjectInput::from_parts(
    "root",
    "",
    Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["data"],
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
  )
  let graph = @graph.GraphInput::from_parts(
    "near-sql-member",
    root,
    [field, table],
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
  @debug.assert_eq(
    constant_near_bounding_box_like_d2(graph, Map([])),
    (12.0, 12.0, 278.0, 84.0),
  )
}

///|
test "final edge label placement uses the target route precision stage" {
  let route = [
    @graph.Point::new(256.9166666666667, 128.0),
    @graph.Point::new(256.9166666666667, 353.0),
    @graph.Point::new(350.0, 353.0),
    @graph.Point::new(349.99999999999994, 796.0),
    @graph.Point::new(253.58333333333334, 796.0),
    @graph.Point::new(253.58333333333334, 836.0),
  ]
  let center = d2_target_route_point_at_percent_like_d2(route, 0.5)
  @debug.assert_eq(
    d2_label_chop_precision_like_d2(center.x - 31.0 / 2.0),
    334.0,
  )
}
