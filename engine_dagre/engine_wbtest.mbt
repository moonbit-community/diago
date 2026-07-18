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
test "leaf label measurement keeps D2 default bold when style says false" {
  let style = @graph.StyleInput::from_parts(
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
    Some(@graph.StyleValue::from_bool(false)),
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
  let obj = @graph.ObjectInput::from_parts(
    "leaf",
    "leaf",
    Rectangle,
    style,
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
  )
  assert_true(object_label_bold_like_d2(obj))
}

///|
test "non-rectangular endpoint tracing matches D2 perimeters" {
  let box = @graph.Box::new(0.0, 0.0, 100.0, 100.0)
  inspect(
    trace_to_shape_border(
      Parallelogram,
      box,
      @graph.Point::new(100.0, 50.0),
      @graph.Point::new(50.0, 50.0),
    ),
    content="{x: 87, y: 50}",
  )
  inspect(
    trace_to_shape_border(
      Page,
      box,
      @graph.Point::new(100.0, 10.0),
      @graph.Point::new(50.0, 50.0),
    ),
    content="{x: 95, y: 14}",
  )
  inspect(
    trace_to_shape_border(
      Cloud,
      box,
      @graph.Point::new(100.0, 50.0),
      @graph.Point::new(50.0, 50.0),
    ),
    content="{x: 97, y: 50}",
  )
  inspect(
    trace_to_shape_border(
      Person,
      @graph.Box::new(61.0, 0.0, 44.0, 66.0),
      @graph.Point::new(104.5, 65.0),
      @graph.Point::new(139.5, 116.0),
    ),
    content="{x: 104, y: 65}",
  )
  inspect(
    trace_to_shape_border(
      Cylinder,
      @graph.Box::new(345.0, 1595.0, 125.0, 118.0),
      @graph.Point::new(431.0, 1595.0),
      @graph.Point::new(450.0, 1545.0),
    ),
    content="{x: 431, y: 1596}",
  )
  inspect(
    trace_to_shape_border(
      Diamond,
      @graph.Box::new(37.0, 343.0, 46.0, 92.0),
      @graph.Point::new(76.0, 343.0),
      @graph.Point::new(93.0, 293.0),
    ),
    content="{x: 70, y: 361}",
  )
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
test "sequence participants use regular label metrics like D2" {
  let obj = @graph.ObjectInput::from_parts(
    "participant",
    "to be well-adjusted?",
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
  )
  let object_by_id : Map[String, @graph.ObjectInput] = Map([])
  let size = object_size(
    obj,
    @engine_api.LayoutConfig::new(),
    object_by_id,
    inside_sequence=true,
  )
  @debug.assert_eq(size, (181.0, 66.0))
}

///|
test "dagre node center offsets use Go math.Round tie semantics" {
  let attrs = @moon_dagre.empty_attrs()
  attrs.set_float("x", 463.0)
  attrs.set_float("y", 754.5)
  attrs.set_float("width", 362.0)
  attrs.set_float("height", 200.0)
  @debug.assert_eq(
    box_from_dagre_node(attrs, 362.0, 200.0),
    Some(@graph.Box::new(282.0, 655.0, 362.0, 200.0)),
  )
}

///|
test "box tracing rounds a half-pixel dagre endpoint like D2" {
  @debug.assert_eq(
    first_box_intersection(
      @graph.Box::new(282.0, 655.0, 362.0, 200.0),
      @graph.Point::new(463.0, 854.5),
      @graph.Point::new(463.0, 906.0),
    ),
    Some(@graph.Point::new(463.0, 854.5)),
  )
}

///|
test "C4 person tracing matches D2's exact cubic intersection" {
  let box = @graph.Box::new(1065.0, 0.0, 415.0, 394.0)
  let rect = @graph.Point::new(1065.25, 264.1230581784953)
  let prev = @graph.Point::new(452.0, 462.5)
  let chopped = first_box_intersection(box, prev, rect).unwrap()
  @debug.assert_eq(chopped, @graph.Point::new(1065.0, 264.5))
  let extended = extended_trace_segment_end(box, chopped, prev)
  @debug.assert_eq(
    segment_segment_intersection(
      @graph.Point::new(1065.0, 337.0),
      @graph.Point::new(1065.0, 222.0),
      prev,
      extended,
    ),
    Some(@graph.Point::new(1065.0, 265.0)),
  )
  @debug.assert_eq(
    trace_to_shape_border(C4Person, box, chopped, prev),
    @graph.Point::new(1065.0, 265.0),
  )
}
