// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn test_object_input(
  box : @graph.Box,
  label? : String = "",
  shape_type? : @graph.ShapeType = Rectangle,
  style? : @graph.StyleInput = @graph.StyleInput::new(),
  label_box? : @graph.Box? = None,
  child_ids? : Array[String] = [],
  label_position? : String? = None,
  icon? : String? = None,
  icon_position? : String? = None,
  tooltip? : String? = None,
  tooltip_position? : String? = None,
) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    "node",
    label,
    shape_type,
    style,
    Some(box),
    label_box,
    child_ids,
    0,
    icon,
    tooltip,
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
    icon_position~,
    tooltip_position~,
    label_position~,
  )
}

///|
fn test_diagram_with_object(obj : @graph.ObjectInput) -> @diagram.Diagram {
  let graph = @graph.GraphInput::from_parts(
    "svg-render-test",
    @graph.ObjectInput::new("root"),
    [obj],
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
fn test_edge_input(
  label? : String = "",
  label_box? : @graph.Box? = None,
  icon? : String? = None,
  icon_position? : String? = None,
  icon_border_radius? : Double? = None,
  link? : String? = None,
) -> @graph.EdgeInput {
  @graph.EdgeInput::from_parts(
    0,
    "a",
    "b",
    false,
    true,
    None,
    Triangle,
    None,
    None,
    None,
    None,
    None,
    None,
    label,
    @graph.StyleInput::new(),
    [@graph.Point::new(50.0, 25.0), @graph.Point::new(200.0, 25.0)],
    None,
    false,
    0,
    1,
    label_box,
    None,
    None,
    icon~,
    icon_position~,
    icon_border_radius~,
    link~,
  )
}

///|
fn test_diagram_with_edge(edge : @graph.EdgeInput) -> @diagram.Diagram {
  let graph = @graph.GraphInput::from_parts(
    "svg-edge-render-test",
    @graph.ObjectInput::new("root"),
    [
      test_object_input(@graph.Box::new(0.0, 0.0, 50.0, 50.0)),
      @graph.ObjectInput::from_parts(
        "b",
        "",
        Rectangle,
        @graph.StyleInput::new(),
        Some(@graph.Box::new(200.0, 0.0, 50.0, 50.0)),
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
    [edge],
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
test "edge icon and link render with D2 connection geometry" {
  let diagram = test_diagram_with_edge(
    test_edge_input(
      label="hello",
      label_box=Some(@graph.Box::new(100.0, 15.0, 40.0, 20.0)),
      icon=Some("https://example.com/icon.svg"),
      icon_border_radius=Some(12.0),
      link=Some("https://example.com/docs"),
    ),
  )
  let rendered = render(diagram, SvgConfig::new())
  assert_true(
    rendered.contains(
      "<image href=\"https://example.com/icon.svg\" x=\"60.000000\" y=\"9.000000\" width=\"32\" height=\"32\" clip-path=\"inset(0 round 12.000000px)\"",
    ),
  )
  assert_true(
    rendered.contains(
      "<rect x=\"58.000000\" y=\"15.000000\" width=\"84\" height=\"20\" fill=\"black\"",
    ),
  )
  assert_true(
    rendered.contains(
      "<a href=\"https://example.com/docs\" xlink:href=\"https://example.com/docs\"><text",
    ),
  )
  assert_true(rendered.contains("text-underline text-link"))
}

///|
test "edge icon near positions work without a label" {
  let diagram = test_diagram_with_edge(
    test_edge_input(
      icon=Some("https://example.com/icon.svg"),
      icon_position=Some("OUTSIDE_TOP_CENTER"),
      link=Some("https://example.com/docs"),
    ),
  )
  let edge = diagram.connections[0]
  guard edge_icon_box(edge, 2.0) is Some(box) else {
    fail("expected edge icon box")
  }
  @debug.assert_eq(box, @graph.Box::new(109.0, -13.0, 32.0, 32.0))
  let rendered = render(diagram, SvgConfig::new())
  assert_false(rendered.contains("<a href=\"https://example.com/docs\""))
}

///|
test "plain object label layout uses explicit label position" {
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(100.0, 80.0, 80.0, 40.0),
      label="Node",
      label_position=Some("OUTSIDE_TOP_LEFT"),
    ),
  )
  guard diagram.find_object("node") is Some(shape) else {
    fail("expected node shape")
  }
  guard shape.box is Some(box) else { fail("expected shape box") }
  let (x, y, width) = plain_object_label_layout(shape, box, 20.0, 10.0, "dagre")
  @debug.assert_eq(x, 95.0)
  @debug.assert_eq(y, 65.0)
  @debug.assert_eq(width, 20.0)
}

///|
test "container label layout is derived from the container box" {
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(100.0, 80.0, 80.0, 40.0),
      label="Node",
      label_box=Some(@graph.Box::new(117.5, 60.0, 20.0, 10.0)),
      child_ids=["child"],
    ),
  )
  guard diagram.find_object("node") is Some(shape) else {
    fail("expected node shape")
  }
  guard shape.box is Some(box) else { fail("expected shape box") }
  let (x, y, width) = plain_object_label_layout(shape, box, 20.0, 10.0, "dagre")
  @debug.assert_eq(x, 130.0)
  @debug.assert_eq(y, 60.0)
  @debug.assert_eq(width, 20.0)
}

///|
test "shape border radius is clamped to half the smaller dimension" {
  let box = @graph.Box::new(0.0, 0.0, 96.0, 66.0)
  @debug.assert_eq(clamped_shape_border_radius(999.0, box), 33.0)
  @debug.assert_eq(clamped_shape_border_radius(-1.0, box), 0.0)
}

///|
test "board links use generated SVG paths" {
  @debug.assert_eq(d2_svg_link_href("root.layers.cat"), "cat.svg")
  @debug.assert_eq(d2_svg_link_href("root.layers.\"cat.go\""), "cat.go.svg")
  @debug.assert_eq(
    d2_svg_link_href("root.layers.cat.layers.kitten"),
    "cat/kitten.svg",
  )
  @debug.assert_eq(
    d2_svg_link_href("https://example.com/docs"),
    "https://example.com/docs",
  )
}

///|
test "markdown HTML is normalized as an XHTML fragment" {
  @debug.assert_eq(
    normalize_markdown_xhtml("<p>a<br>b</p><hr>&nbsp;"),
    "<p>a<br />b</p><hr />&#160;",
  )
}

///|
test "markdown table accessibility wrapper is removed like D2" {
  @debug.assert_eq(
    normalize_markdown_xhtml(
      "<div role=\"region\"><table>\n<tr><th>A</th></tr>\n<tr><td>B</td></tr>\n</table></div>",
    ),
    "<table>\n<thead>\n<tr><th>A</th></tr>\n</thead>\n<tbody>\n<tr><td>B</td></tr>\n</tbody>\n</table>",
  )
}

///|
test "sketch path decimals are truncated without a JS callback" {
  @debug.assert_eq(
    truncate_sketch_path_decimals("M-1.123456789 2.5 C 10.0000001 3 4.123456 5"),
    "M-1.123456 2.5 C 10.000000 3 4.123456 5",
  )
}

///|
test "sketch runtime returns rough connection paths" {
  let session = SketchSession::new() catch {
    error => fail("failed to initialize sketch runtime: \{error}")
  }
  let path = "M 55 32 M 55 32 C 94 32 114 32 150 33 M 54 31 C 93 33 113 33 150 32"
  let shape_nodes = session.path_shape(path, 2.0) catch {
    error => fail("failed to render sketch path shape: \{error}")
  }
  assert_true(!shape_nodes.is_empty())
  let nodes = session.connection(path) catch {
    error => fail("failed to render sketch connection: \{error}")
  }
  assert_true(!nodes.is_empty())
  let mut has_path = false
  for node in nodes {
    if node.get("d").unwrap_or("") != "" {
      has_path = true
    }
  }
  assert_true(has_path)
}

///|
test "sketch angles retain D2 transform precision" {
  assert_eq(sketch_angle_string(sketch_angle(0.0, 0.0, 1.0, 0.0)), "0")
  assert_eq(
    sketch_angle_string(sketch_angle(0.0, 0.0, 0.0, 1.0)),
    "90.00000250447816",
  )
}

///|
test "zero-opacity objects do not emit labels" {
  let style = @graph.StyleInput::from_parts(
    Some(@graph.StyleValue::from_double(0.0)),
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
    None,
    None,
  )
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(0.0, 0.0, 80.0, 40.0),
      label="hidden",
      style~,
    ),
  )
  guard diagram.find_object("node") is Some(shape) else {
    fail("expected node shape")
  }
  assert_false(object_label_visible(shape))
  assert_false(render(diagram, SvgConfig::new()).contains(">hidden</text>"))
}

///|
test "person paths preserve stroke dash styling" {
  let style = @graph.StyleInput::from_parts(
    None,
    None,
    None,
    None,
    Some(@graph.StyleValue::from_double(3.0)),
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
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(0.0, 0.0, 68.3, 77.4),
      shape_type=Person,
      style~,
    ),
  )
  assert_true(
    render(diagram, SvgConfig::new()).contains(
      "stroke-dasharray:6.000000,5.919384;",
    ),
  )
}

///|
test "positioned tooltips render without fallback appendix icon title" {
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(100.0, 80.0, 80.0, 40.0),
      tooltip=Some("hover text"),
      tooltip_position=Some("bottom-right"),
    ),
  )
  guard diagram.find_object("node") is Some(shape) else {
    fail("expected node shape")
  }
  guard shape.box is Some(box) else { fail("expected shape box") }
  let rendered = render_object_appendix_icons(
    "hash",
    shape,
    box,
    SvgConfig::new(),
    @themes.get_theme(0),
  ).join("\n")
  assert_true(rendered.contains("positioned-tooltip"))
  assert_false(rendered.contains("<title>hover text</title>"))
}

///|
test "person appendix icon is traced to the shape border" {
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(386.0, 337.0, 44.0, 66.0),
      shape_type=Person,
      tooltip=Some("hover text"),
    ),
  )
  guard diagram.find_object("node") is Some(shape) else {
    fail("expected node shape")
  }
  guard shape.box is Some(box) else { fail("expected shape box") }
  let rendered = render_object_appendix_icons(
    "hash",
    shape,
    box,
    SvgConfig::new(),
    @themes.get_theme(0),
  ).join("\n")
  assert_true(rendered.contains("translate(406 333)"))
}

///|
test "compute graph bounds includes outside icon and positioned tooltip extents" {
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(100.0, 80.0, 80.0, 40.0),
      icon=Some("https://example.com/icon.svg"),
      icon_position=Some("OUTSIDE_RIGHT_MIDDLE"),
      tooltip=Some("hover text"),
      tooltip_position=Some("bottom-right"),
    ),
  )
  let bounds = compute_graph_bounds(
    diagram,
    SvgConfig::new(),
    @themes.get_theme(0),
  )
  assert_true(bounds.0 < 100.0)
  @debug.assert_eq(bounds.1, 79.0)
  assert_true(bounds.2 >= 217.0)
  assert_true(bounds.3 > 121.0)
}

///|
test "compute graph bounds does not double count inline shape labels" {
  let diagram = test_diagram_with_object(
    test_object_input(
      @graph.Box::new(0.0, 0.0, 100.0, 80.0),
      label="users",
      shape_type=SqlTable,
      label_position=Some("OUTSIDE_TOP_CENTER"),
    ),
  )
  let bounds = compute_graph_bounds(
    diagram,
    SvgConfig::new(),
    @themes.get_theme(0),
  )
  @debug.assert_eq(bounds, (-1.0, -1.0, 101.0, 81.0))
}

///|
test "compute graph bounds uses D2 target-truncated shape geometry" {
  let diagram = test_diagram_with_object(
    test_object_input(@graph.Box::new(-58.9, 0.9, 100.9, 80.9)),
  )
  let bounds = compute_graph_bounds(
    diagram,
    SvgConfig::new(),
    @themes.get_theme(0),
  )
  @debug.assert_eq(bounds, (-59.0, -1.0, 43.0, 81.0))
}

///|
test "label bounds truncate a negative half-pixel top-left like D2 target" {
  @debug.assert_eq(
    d2_target_label_bounds(-58.5, -13.5, 380.0, 36.0),
    (-58.0, -13.0, 322.0, 23.0),
  )
}
