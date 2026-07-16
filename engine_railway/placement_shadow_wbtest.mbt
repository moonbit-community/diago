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
priv struct PlacementShadowMetrics {
  crossings : Int
  label_overlaps : Int
  node_overlaps : Int
  long_detours : Int
  total_length : Double
  route_points : Int
}

///|
fn placement_shadow_metrics(
  graph : @graph.GraphInput,
  patch : @graph.LayoutPatch,
) -> PlacementShadowMetrics {
  let (crossings, label_overlaps, node_overlaps, long_detours, total_length) = railway_readability_metrics(
    graph, patch,
  )
  let mut route_points = 0
  for _, route in patch.edges {
    route_points = route_points + route.length()
  }
  {
    crossings,
    label_overlaps,
    node_overlaps,
    long_detours,
    total_length,
    route_points,
  }
}

///|
fn placement_overlap_pairs(
  graph : @graph.GraphInput,
  patch : @graph.LayoutPatch,
) -> String {
  let parent_id_by_child_id = build_parent_id_by_child_id(graph)
  let nodes : Array[(String, @graph.Box)] = []
  for id, box in patch.nodes {
    nodes.push((id, box))
  }
  let out = StringBuilder::new()
  let mut has_any = false
  for i in 0..<nodes.length() {
    for j in (i + 1)..<nodes.length() {
      let a = nodes[i]
      let b = nodes[j]
      if is_ancestor_of(a.0, b.0, parent_id_by_child_id) ||
        is_ancestor_of(b.0, a.0, parent_id_by_child_id) {
        continue
      }
      if boxes_overlap_strict(a.1, b.1) {
        if has_any {
          out.write_string(", ")
        }
        has_any = true
        out.write_string(a.0)
        out.write_string("(\{a.1.x},\{a.1.y},\{a.1.width},\{a.1.height})")
        out.write_string("/")
        out.write_string(b.0)
        out.write_string("(\{b.1.x},\{b.1.y},\{b.1.width},\{b.1.height})")
      }
    }
  }
  out.to_string()
}

///|
fn dense_placement_fixture() -> @graph.GraphInput {
  let graph = @graph.GraphInput::new("dense-placement")
  let layer_width = 5
  let layer_count = 4
  for layer in 0..<layer_count {
    for column in 0..<layer_width {
      graph.objects.push(@graph.ObjectInput::new("n\{layer}_\{column}"))
    }
  }
  let mut edge_index = 0
  for layer in 0..<(layer_count - 1) {
    for src in 0..<layer_width {
      for dst in 0..<layer_width {
        graph.edges.push(
          @graph.EdgeInput::new(
            edge_index,
            "n\{layer}_\{src}",
            "n\{layer + 1}_\{dst}",
            false,
            true,
          ),
        )
        edge_index = edge_index + 1
      }
    }
  }
  graph
}

///|
fn long_edge_placement_fixture() -> @graph.GraphInput {
  let graph = @graph.GraphInput::new("long-edge-placement")
  for i in 0..<30 {
    graph.objects.push(@graph.ObjectInput::new("n\{i}"))
  }
  let mut edge_index = 0
  for i in 0..<29 {
    graph.edges.push(
      @graph.EdgeInput::new(edge_index, "n\{i}", "n\{i + 1}", false, true),
    )
    edge_index = edge_index + 1
  }
  for i in 0..<20 {
    graph.edges.push(
      @graph.EdgeInput::new(edge_index, "n\{i}", "n\{i + 10}", false, true),
    )
    edge_index = edge_index + 1
  }
  graph
}

///|
fn nested_placement_fixture() -> @graph.GraphInput {
  let outer = @graph.ObjectInput::from_parts(
    "outer",
    "Outer",
    Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["outer.inner", "outer.gateway"],
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
  let inner = @graph.ObjectInput::from_parts(
    "outer.inner",
    "Inner",
    Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["outer.inner.a", "outer.inner.b"],
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
  let graph = @graph.GraphInput::new("nested-placement")
  graph.objects.append([
    outer,
    inner,
    @graph.ObjectInput::new("outer.inner.a"),
    @graph.ObjectInput::new("outer.inner.b"),
    @graph.ObjectInput::new("outer.gateway"),
    @graph.ObjectInput::new("external"),
  ])
  graph.edges.append([
    @graph.EdgeInput::new(0, "external", "outer.inner.a", false, true),
    @graph.EdgeInput::new(1, "outer.inner.a", "outer.gateway", false, true),
    @graph.EdgeInput::new(2, "outer.gateway", "outer.inner.b", false, true),
  ])
  graph
}

///|
fn assert_placement_shadow_gate(
  name : String,
  graph : @graph.GraphInput,
) -> Unit raise {
  let config = @engine_api.LayoutConfig::new()
  let dagre_patch = layout_graph_with_placement_adapter(
    graph,
    config,
    Down,
    Dagre,
  )
  let sugiyama_patch = layout_graph_with_placement_adapter(
    graph,
    config,
    Down,
    Sugiyama,
  )
  for patch in [dagre_patch, sugiyama_patch] {
    assert_true(
      patch.nodes.length() == graph.objects.length(),
      msg="\{name}: missing nodes",
    )
    assert_true(
      patch.edges.length() == graph.edges.length(),
      msg="\{name}: missing edges",
    )
    for edge in graph.edges {
      assert_true(
        patch.edges.get(edge.index).unwrap_or([]).length() >= 2,
        msg="\{name}: missing route for edge \{edge.index}",
      )
    }
  }
  let dagre = placement_shadow_metrics(graph, dagre_patch)
  let sugiyama = placement_shadow_metrics(graph, sugiyama_patch)
  assert_true(dagre.node_overlaps == 0, msg="\{name}: Dagre node overlap")
  assert_true(
    sugiyama.node_overlaps == 0,
    msg="\{name}: Sugiyama node overlap: \{placement_overlap_pairs(graph, sugiyama_patch)}",
  )
  assert_true(dagre.label_overlaps == 0, msg="\{name}: Dagre label overlap")
  assert_true(
    sugiyama.label_overlaps == 0,
    msg="\{name}: Sugiyama label overlap",
  )
  let crossing_limit = @cmp.maximum(
    graph.edges.length() * 5,
    dagre.crossings * 4 + 20,
  )
  assert_true(
    sugiyama.crossings <= crossing_limit,
    msg="\{name}: Sugiyama crossings \{sugiyama.crossings} > \{crossing_limit}",
  )
  let detour_limit = dagre.long_detours + graph.edges.length() / 2
  assert_true(
    sugiyama.long_detours <= detour_limit,
    msg="\{name}: Sugiyama detours \{sugiyama.long_detours} > \{detour_limit}",
  )
  assert_true(
    sugiyama.route_points <= graph.edges.length() * 10,
    msg="\{name}: Sugiyama route complexity",
  )
  let length_limit = @cmp.maximum(1.0, dagre.total_length * 4.0)
  assert_true(
    sugiyama.total_length <= length_limit,
    msg="\{name}: Sugiyama route length \{sugiyama.total_length} > \{length_limit}",
  )
}

///|
test "railway shadow-qualifies dagre and sugiyama placement adapters" {
  assert_placement_shadow_gate("sparse", railway_scale_fixture(50))
  assert_placement_shadow_gate("dense", dense_placement_fixture())
  assert_placement_shadow_gate("nested", nested_placement_fixture())
  assert_placement_shadow_gate("long-edge", long_edge_placement_fixture())
}
