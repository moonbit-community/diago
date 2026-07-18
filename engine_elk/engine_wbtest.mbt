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
fn constant_near_label_test_object(
  label_position : String?,
) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    "cluster",
    "Near label",
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
    label_position~,
  )
}

///|
test "constant near place shifts left for outside-right labels like the reference" {
  let plain = constant_near_label_test_object(None)
  let outside_right = constant_near_label_test_object(
    Some("OUTSIDE_RIGHT_MIDDLE"),
  )
  let plain_pos = place_constant_near_box(
    plain, "top-left", 0.0, 0.0, 100.0, 80.0, 60.0, 40.0,
  )
  let adjusted_pos = place_constant_near_box(
    outside_right, "top-left", 0.0, 0.0, 100.0, 80.0, 60.0, 40.0,
  )
  let (label_width, _) = object_label_dimensions(outside_right).unwrap()
  @debug.assert_eq(adjusted_pos.0, plain_pos.0 - label_width)
  @debug.assert_eq(adjusted_pos.1, plain_pos.1)
}

///|
test "constant near place shifts down for outside-top labels like the reference" {
  let plain = constant_near_label_test_object(None)
  let outside_top = constant_near_label_test_object(Some("OUTSIDE_TOP_CENTER"))
  let plain_pos = place_constant_near_box(
    plain, "bottom-right", 0.0, 0.0, 100.0, 80.0, 60.0, 40.0,
  )
  let adjusted_pos = place_constant_near_box(
    outside_top, "bottom-right", 0.0, 0.0, 100.0, 80.0, 60.0, 40.0,
  )
  let (_, label_height) = object_label_dimensions(outside_top).unwrap()
  @debug.assert_eq(adjusted_pos.0, plain_pos.0)
  @debug.assert_eq(adjusted_pos.1, plain_pos.1 + label_height)
}

///|
test "outside icon layout margin uses the rendered icon size" {
  let box = @graph.Box::new(0.0, 0.0, 123.0, 118.0)
  @debug.assert_eq(
    object_layout_icon_size(box, "OUTSIDE_TOP_RIGHT") + D2_LABEL_PADDING,
    64.0,
  )
}

///|
test "edge labels use D2 target route precision before midpoint rounding" {
  let route = [
    @graph.Point::new(256.9166666666667, 128.0),
    @graph.Point::new(256.9166666666667, 353.0),
    @graph.Point::new(350.0, 353.0),
    @graph.Point::new(349.99999999999994, 796.0),
    @graph.Point::new(253.58333333333334, 796.0),
    @graph.Point::new(253.58333333333334, 836.0),
  ]
  let center = d2_target_route_point_at_percent(route, 0.5)
  @debug.assert_eq(
    d2_path_chop_precision_for_trace(center.x - 31.0 / 2.0),
    334.0,
  )
}

///|
test "person with only an explicit width preserves the reference aspect ratio" {
  let obj = @graph.ObjectInput::from_parts(
    "user",
    "user",
    Person,
    @graph.StyleInput::new(),
    Some(@graph.Box::new(0.0, 0.0, 130.0, 0.0)),
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
  let object_by_id : Map[String, @graph.ObjectInput] = Map([])
  let (width, height) = object_size(
    obj,
    @engine_api.LayoutConfig::new(),
    object_by_id,
  )
  @debug.assert_eq(width, 130.0)
  @debug.assert_eq(height, 87.0)
}

///|
test "elk edge ids preserve quoted syntax path segments" {
  let quoted = @graph.EdgeInput::new(0, "\"a.b\"", "c", false, true)
  let nested = @graph.EdgeInput::new(1, "a.b", "c", false, true)
  @debug.assert_eq(d2_edge_abs_id(quoted, 0), "(\"a.b\" -> c)[0]")
  @debug.assert_eq(d2_edge_abs_id(nested, 0), "(a.b -> c)[0]")
  assert_true(
    d2_edge_abs_id(quoted, 0) != d2_edge_abs_id(nested, 0),
    msg="quoted-dot and nested edges need distinct ELK ids",
  )
}

///|
test "ELK route parsing preserves duplicate section points like D2" {
  let point = fn(x : Double, y : Double) {
    Json::object({ "x": Json::number(x), "y": Json::number(y) })
  }
  let section : Map[String, Json] = {
    "startPoint": point(10.0, 20.0),
    "bendPoints": Json::array([point(30.0, 20.0), point(30.0, 20.0)]),
    "endPoint": point(30.0, 40.0),
  }
  let edge : Map[String, Json] = {
    "sections": Json::array([Json::object(section)]),
  }
  let route = parse_edge_route(edge, 100.0, 200.0)
  @debug.assert_eq(route.length(), 4)
  @debug.assert_eq(route[0], @graph.Point::new(110.0, 220.0))
  @debug.assert_eq(route[1], @graph.Point::new(130.0, 220.0))
  @debug.assert_eq(route[2], @graph.Point::new(130.0, 220.0))
  @debug.assert_eq(route[3], @graph.Point::new(130.0, 240.0))
}

///|
test "moving an edge start removes collinear points passed by the endpoint" {
  let route = [
    @graph.Point::new(0.0, 0.0),
    @graph.Point::new(10.0, 0.0),
    @graph.Point::new(20.0, 0.0),
    @graph.Point::new(20.0, 10.0),
  ]
  @debug.assert_eq(shift_route_start_like_d2(route, 15.0, true), [
    @graph.Point::new(15.0, 0.0),
    @graph.Point::new(20.0, 0.0),
    @graph.Point::new(20.0, 10.0),
  ])
}

///|
test "moving an edge end removes collinear points passed by the endpoint" {
  let route = [
    @graph.Point::new(0.0, 0.0),
    @graph.Point::new(0.0, 10.0),
    @graph.Point::new(0.0, 20.0),
    @graph.Point::new(0.0, 30.0),
  ]
  @debug.assert_eq(shift_route_end_like_d2(route, -15.0, false), [
    @graph.Point::new(0.0, 0.0),
    @graph.Point::new(0.0, 10.0),
    @graph.Point::new(0.0, 15.0),
  ])
}

///|
test "quoted class method syntax is excluded from ELK layout nodes" {
  let parent = @graph.ObjectInput::from_parts(
    "DebitCard",
    "Debit card",
    Class,
    @graph.StyleInput::new(),
    None,
    None,
    ["DebitCard.\"+access()\""],
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
  let child = @graph.ObjectInput::new(
    "DebitCard.+access()",
    abs_id_syntax="DebitCard.\"+access()\"",
  )
  let root = @graph.ObjectInput::from_parts(
    "root",
    "",
    Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["DebitCard"],
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
    "classes",
    root,
    [parent, child],
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
  let (object_by_id, parent_id_by_child_id) = build_object_maps(graph)
  let excluded = build_excluded_layout_node_ids(
    graph, parent_id_by_child_id, object_by_id,
  )
  assert_true(excluded.contains(child.id))
  assert_true(excluded.contains(child.abs_id_syntax))
}

///|
test "cylinder tracing follows D2 path direction and precision" {
  inspect(
    trace_to_shape_border(
      Cylinder,
      @graph.Box::new(332.0, 80.0, 168.0, 118.0),
      @graph.Point::new(332.0, 104.5),
      @graph.Point::new(260.0, 34.5),
    ),
    content="{x: 332, y: 104}",
  )
}

///|
test "person tracing follows D2 relative SVG path semantics" {
  inspect(
    trace_to_shape_border(
      Person,
      @graph.Box::new(97.0, 12.0, 103.0, 69.0),
      @graph.Point::new(200.0, 59.5),
      @graph.Point::new(354.0, 59.5),
    ),
    content="{x: 187, y: 60}",
  )
}
