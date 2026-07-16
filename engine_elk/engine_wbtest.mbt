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
