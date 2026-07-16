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
  label_position? : String? = None,
  icon? : String? = None,
  icon_position? : String? = None,
  tooltip? : String? = None,
  tooltip_position? : String? = None,
) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    "node",
    label,
    Rectangle,
    @graph.StyleInput::new(),
    Some(box),
    None,
    [],
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
  let (x, y, width) = plain_object_label_layout(shape, box, 20.0, 10.0)
  @debug.assert_eq(x, 105.0)
  @debug.assert_eq(y, 65.0)
  @debug.assert_eq(width, 20.0)
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
