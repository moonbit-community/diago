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
fn railway_scale_fixture(node_count : Int) -> @graph.GraphInput {
  let graph = @graph.GraphInput::new("railway-scale-\{node_count}")
  for i in 0..<node_count {
    graph.objects.push(@graph.ObjectInput::new("n\{i}"))
  }
  let mut edge_index = 0
  for src in 0..<node_count {
    for step in [5, 6] {
      let dst = src + step
      if dst >= node_count {
        continue
      }
      graph.edges.push(
        @graph.EdgeInput::new(edge_index, "n\{src}", "n\{dst}", false, true),
      )
      edge_index = edge_index + 1
    }
  }
  graph
}

///|
fn run_railway_scale_fixture(
  node_count : Int,
) -> RailwayRoutingResult raise @engine_api.LayoutError {
  let graph = railway_scale_fixture(node_count)
  let config = @engine_api.LayoutConfig::new()
  let placement = run_placement_stage(graph, config, Down)
  let hierarchy = run_hierarchy_layout_stage(graph, placement, config, Down)
  let problem = build_routing_problem(placement, hierarchy, config, Down)
  run_routing_stage(graph, problem)
}

///|
test "railway readability and scale gates cover 10 50 and 200 nodes" {
  for node_count in [10, 50, 200] {
    let graph = railway_scale_fixture(node_count)
    let result = run_railway_scale_fixture(node_count)
    let patch = result.patch
    assert_true(patch.nodes.length() == node_count)
    assert_true(patch.edges.length() == graph.edges.length())
    assert_true(result.routing_passes >= 1 && result.routing_passes <= 2)
    assert_true(result.title_collision_score == 0)

    let mut route_point_count = 0
    for _, route in patch.edges {
      assert_true(route.length() >= 2)
      route_point_count = route_point_count + route.length()
    }
    assert_true(
      route_point_count <= graph.edges.length() * 8,
      msg="route complexity gate failed for \{node_count} nodes",
    )

    let (
      crossing_count,
      label_overlap_count,
      node_overlap_count,
      long_detour_count,
      edge_total_length,
    ) = railway_readability_metrics(graph, patch)
    assert_true(label_overlap_count == 0)
    assert_true(node_overlap_count == 0)
    assert_true(
      crossing_count <= graph.edges.length() * 2,
      msg="crossing gate failed for \{node_count} nodes",
    )
    assert_true(
      long_detour_count <= graph.edges.length() / 2,
      msg="detour gate failed for \{node_count} nodes",
    )
    assert_true(edge_total_length > 0.0)
  }
}
