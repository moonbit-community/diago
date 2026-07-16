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
test "railway can use sugiyama without changing hierarchy or routing stages" {
  let graph = railway_scale_fixture(10)
  let config = @engine_api.LayoutConfig::new()
  let patch = layout_graph_with_placement_adapter(graph, config, Down, Sugiyama)
  assert_true(patch.nodes.length() == graph.objects.length())
  assert_true(patch.edges.length() == graph.edges.length())
  for edge in graph.edges {
    assert_true(patch.edges.get(edge.index).unwrap_or([]).length() >= 2)
  }
  let (
    crossing_count,
    label_overlap_count,
    node_overlap_count,
    long_detour_count,
    edge_total_length,
  ) = railway_readability_metrics(graph, patch)
  assert_true(label_overlap_count == 0)
  assert_true(node_overlap_count == 0)
  assert_true(crossing_count <= graph.edges.length() * 2)
  assert_true(long_detour_count <= graph.edges.length() / 2)
  assert_true(edge_total_length > 0.0)
}

///|
test "railway sugiyama adapter supports every direction" {
  let graph = @graph.GraphInput::new("sugiyama-directions")
  graph.objects.append([
    @graph.ObjectInput::new("a"),
    @graph.ObjectInput::new("b"),
    @graph.ObjectInput::new("c"),
  ])
  graph.edges.append([
    @graph.EdgeInput::new(0, "a", "b", false, true),
    @graph.EdgeInput::new(1, "b", "c", false, true),
  ])
  let config = @engine_api.LayoutConfig::new()
  let directions : Array[@engine_api.Direction] = [Down, Up, Right, Left]
  for direction in directions {
    let patch = layout_graph_with_placement_adapter(
      graph,
      config,
      direction,
      Sugiyama,
    )
    assert_true(patch.nodes.length() == 3)
    assert_true(patch.edges.length() == 2)
  }
}
