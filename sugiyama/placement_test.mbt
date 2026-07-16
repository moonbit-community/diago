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
fn fixed_placement_size(_obj : @graph.ObjectInput) -> (Double, Double) {
  (100.0, 60.0)
}

///|
fn placement_graph(
  ids : Array[String],
  endpoints : Array[(String, String)],
) -> @graph.GraphInput {
  let graph = @graph.GraphInput::new("placement")
  for id in ids {
    graph.objects.push(@graph.ObjectInput::new(id))
  }
  for index, endpoint in endpoints {
    graph.edges.push(
      @graph.EdgeInput::new(index, endpoint.0, endpoint.1, false, true),
    )
  }
  graph
}

///|
fn place_test_graph(
  graph : @graph.GraphInput,
  direction : @engine_api.Direction,
) -> PlacementResult raise @layout_core.LayoutProblemError {
  place(
    @layout_core.compile(graph),
    fixed_placement_size,
    direction,
    60.0,
    40.0,
  )
}

///|
test "sugiyama placement handles virtual nodes cycles and disconnected nodes" {
  let long_edge = placement_graph(["a", "b", "c"], [
    ("a", "b"),
    ("b", "c"),
    ("a", "c"),
  ])
  let long_result = place_test_graph(long_edge, Down)
  assert_true(long_result.boxes.length() == 3)
  assert_true(long_result.virtual_node_count == 1)
  assert_true(long_result.reversed_edge_count == 0)

  let cycle = placement_graph(["a", "b", "c"], [
    ("a", "b"),
    ("b", "c"),
    ("c", "a"),
  ])
  let cycle_result = place_test_graph(cycle, Down)
  assert_true(cycle_result.boxes.length() == 3)
  assert_true(cycle_result.reversed_edge_count >= 1)

  let disconnected = placement_graph(["a", "b", "c"], [])
  let disconnected_result = place_test_graph(disconnected, Down)
  for id in ["a", "b", "c"] {
    assert_true(
      disconnected_result.boxes.contains(@layout_core.ObjectId::new(id)),
    )
  }
}

///|
test "sugiyama placement supports all layout directions" {
  let graph = placement_graph(["a", "b"], [("a", "b")])
  let a = @layout_core.ObjectId::new("a")
  let b = @layout_core.ObjectId::new("b")

  let down = place_test_graph(graph, Down)
  assert_true(down.boxes.get(a).unwrap().y < down.boxes.get(b).unwrap().y)

  let up = place_test_graph(graph, Up)
  assert_true(up.boxes.get(a).unwrap().y > up.boxes.get(b).unwrap().y)

  let right = place_test_graph(graph, Right)
  assert_true(right.boxes.get(a).unwrap().x < right.boxes.get(b).unwrap().x)

  let left = place_test_graph(graph, Left)
  assert_true(left.boxes.get(a).unwrap().x > left.boxes.get(b).unwrap().x)
}

///|
test "sugiyama placement returns typed boxes for containers and children" {
  let container = @graph.ObjectInput::from_parts(
    "group",
    "Group",
    Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["group.a"],
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
  let graph = @graph.GraphInput::new("container-placement")
  graph.objects.append([
    container,
    @graph.ObjectInput::new("group.a"),
    @graph.ObjectInput::new("outside"),
  ])
  graph.edges.push(@graph.EdgeInput::new(0, "group.a", "outside", false, true))
  let result = place_test_graph(graph, Down)
  for id in ["group", "group.a", "outside"] {
    assert_true(result.boxes.contains(@layout_core.ObjectId::new(id)))
    assert_true(result.rank_by_id.contains(@layout_core.ObjectId::new(id)))
  }
  assert_true(!result.level_heights.is_empty())
}
