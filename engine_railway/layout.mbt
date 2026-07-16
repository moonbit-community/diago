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
fn layout_graph(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  keep_legacy_railway_symbols_alive()
  if graph.root.shape_type == SequenceDiagram {
    return layout_sequence_with_engine_metrics(graph, config)
  }
  let placement = run_placement_stage(graph, config, direction)
  let hierarchy = run_hierarchy_layout_stage(
    graph, placement, config, direction,
  )
  let routing_problem = build_routing_problem(
    placement, hierarchy, config, direction,
  )
  run_routing_stage(graph, routing_problem).patch
}

///|
fn run_placement_stage(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> RailwayPlacementResult raise @engine_api.LayoutError {
  let (layout_input, object_by_id, parent_id_by_child_id) = build_railway_layout_input(
    graph,
  )
  let plan = els_tarjan_plan(layout_input)
  let (self_loop, reversed_set) = dag_edge_index_sets(plan)
  let n = layout_input.objects.length()
  let id_to_idx : Map[String, Int] = Map([], capacity=n * 2)
  for i in 0..<n {
    id_to_idx.set(layout_input.objects[i].id, i)
  }
  ignore(reversed_set)
  let node_layout = place_nodes(layout_input, config, direction, object_by_id)
  let boxes = node_layout.boxes
  let level_heights = node_layout.level_heights
  let depths = rank_array_for_layout(
    layout_input,
    id_to_idx,
    node_layout.rank_by_id,
  )
  {
    layout_input,
    object_by_id,
    parent_id_by_child_id,
    self_loop,
    id_to_idx,
    boxes,
    rank_by_id: node_layout.rank_by_id,
    depths,
    level_heights,
  }
}

///|
fn run_hierarchy_layout_stage(
  graph : @graph.GraphInput,
  placement : RailwayPlacementResult,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> RailwayHierarchyLayout {
  let patch = @graph.LayoutPatch::new()
  copy_passthrough_layout_data(patch, graph)
  let container_padding = @cmp.maximum(
    RAILWAY_CONTAINER_PADDING,
    config.edge_padding,
  )
  let mut has_layout_container = false
  for obj in graph.objects {
    if is_layout_container_candidate(obj) {
      has_layout_container = true
      break
    }
  }
  layout_hierarchy_railway(
    placement.boxes,
    graph,
    placement.object_by_id,
    placement.parent_id_by_child_id,
    placement.rank_by_id,
    direction,
    config,
    container_padding,
    has_layout_container,
  )
  for obj in placement.layout_input.objects {
    match placement.boxes.get(obj.id) {
      Some(b) => patch.nodes[obj.id] = b
      None => ()
    }
  }
  fit_container_boxes_railway(
    patch,
    graph,
    placement.object_by_id,
    placement.parent_id_by_child_id,
    config,
  )
  sync_boxes_from_patch_railway(placement.boxes, patch)
  { patch, boxes: placement.boxes }
}

///|
fn build_routing_problem(
  placement : RailwayPlacementResult,
  hierarchy : RailwayHierarchyLayout,
  config : @engine_api.LayoutConfig,
  direction : @engine_api.Direction,
) -> RailwayRoutingProblem raise @engine_api.LayoutError {
  let (src_ports, dst_ports) = assign_ports(
    placement.layout_input,
    placement.id_to_idx,
    placement.depths,
    placement.self_loop,
    direction,
    config,
    hierarchy.boxes,
  )
  let rail_tracks = assign_rail_tracks(
    placement.layout_input,
    placement.id_to_idx,
    placement.depths,
    placement.self_loop,
    direction,
    src_ports,
    dst_ports,
  )
  let lane_plan = plan_gap_lanes(
    placement.layout_input,
    placement.id_to_idx,
    placement.depths,
    placement.self_loop,
    direction,
    config,
    src_ports,
    dst_ports,
  )
  {
    patch: hierarchy.patch,
    layout_input: placement.layout_input,
    object_by_id: placement.object_by_id,
    parent_id_by_child_id: placement.parent_id_by_child_id,
    self_loop: placement.self_loop,
    id_to_idx: placement.id_to_idx,
    depths: placement.depths,
    rail_tracks,
    shift_by_edge: lane_plan.shift_by_edge,
    lane_by_edge: lane_plan.lane_by_edge,
    src_ports,
    dst_ports,
    boxes: hierarchy.boxes,
    direction,
    config,
    level_heights: placement.level_heights,
  }
}

///|
fn run_routing_stage(
  graph : @graph.GraphInput,
  problem : RailwayRoutingProblem,
) -> RailwayRoutingResult raise @engine_api.LayoutError {
  route_edges_railway(problem, [])
  recompute_container_label_boxes_railway(problem.patch, graph)
  let reserved_label_boxes = collect_reserved_container_label_boxes_railway(
    problem.patch,
    graph,
  )
  route_edges_railway(problem, reserved_label_boxes)
  recompute_container_label_boxes_railway(problem.patch, graph)
  let final_reserved_label_boxes = collect_reserved_container_label_boxes_railway(
    problem.patch,
    graph,
  )
  route_edges_railway(problem, final_reserved_label_boxes)
  recompute_edge_label_boxes(
    problem.patch,
    graph,
    problem.direction,
    problem.config,
    problem.lane_by_edge,
  )
  { patch: problem.patch }
}

///|
fn layout_sequence_with_engine_metrics(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
) -> @graph.LayoutPatch {
  let object_by_id : Map[String, @graph.ObjectInput] = Map([])
  object_by_id[graph.root.id] = graph.root
  for obj in graph.objects {
    object_by_id[obj.id] = obj
  }
  @layout_sequence.layout(graph, fn(obj) {
    object_size_with_objects(obj, config, object_by_id)
  })
}

///|
fn layout_hierarchy_railway(
  boxes : Map[String, @graph.Box],
  graph : @graph.GraphInput,
  object_by_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
  rank_by_id : Map[String, Int],
  direction : @engine_api.Direction,
  config : @engine_api.LayoutConfig,
  container_padding : Double,
  has_layout_container : Bool,
) -> Unit {
  let levels = if has_layout_container {
    levels_from_rank_only_railway(graph, rank_by_id)
  } else {
    []
  }
  fit_container_boxes_in_map_railway(
    boxes, graph, object_by_id, parent_id_by_child_id, container_padding,
  )
  if has_layout_container {
    spread_sibling_boxes_railway(
      boxes, graph, object_by_id, parent_id_by_child_id, direction, config,
    )
    repack_levels_left_to_right(
      graph, boxes, levels, object_by_id, direction, config,
    )
    fit_container_boxes_in_map_railway(
      boxes, graph, object_by_id, parent_id_by_child_id, container_padding,
    )
    spread_sibling_boxes_railway(
      boxes, graph, object_by_id, parent_id_by_child_id, direction, config,
    )
    fit_container_boxes_in_map_railway(
      boxes, graph, object_by_id, parent_id_by_child_id, container_padding,
    )
  }
}

///|
fn levels_from_rank_only_railway(
  graph : @graph.GraphInput,
  rank_by_id : Map[String, Int],
) -> Array[Level] {
  let mut max_rank = 0
  for entry in rank_by_id {
    if entry.1 > max_rank {
      max_rank = entry.1
    }
  }
  let levels : Array[Level] = Array::makei(max_rank + 1, _ => ([] : Level))
  for obj in graph.objects {
    levels[rank_by_id.get_or_default(obj.id, 0)].push(obj.id)
  }
  levels
}

///|
fn route_edges_railway(
  problem : RailwayRoutingProblem,
  reserved_label_boxes : Array[@graph.Box],
) -> Unit raise @engine_api.LayoutError {
  let patch = problem.patch
  let layout_input = problem.layout_input
  let self_loop = problem.self_loop
  let id_to_idx = problem.id_to_idx
  let depths = problem.depths
  let rail_tracks = problem.rail_tracks
  let shift_by_edge = problem.shift_by_edge
  let src_ports = problem.src_ports
  let dst_ports = problem.dst_ports
  let boxes = problem.boxes
  let object_by_id = problem.object_by_id
  let parent_id_by_child_id = problem.parent_id_by_child_id
  let direction = problem.direction
  let config = problem.config
  let level_heights = problem.level_heights
  let gap_rail_reservations = Ref(Map([]))
  let channel_reservations = Ref([])
  let ordered_edges = layout_input.edges.copy()
  ordered_edges.sort_by(fn(a, b) {
    let a_self = self_loop.contains(a.index)
    let b_self = self_loop.contains(b.index)
    let a_priority = if a_self {
      3
    } else {
      let su = id_to_idx.get_or_default(a.src_id, -1)
      let sv = id_to_idx.get_or_default(a.dst_id, -1)
      if su < 0 || sv < 0 {
        3
      } else {
        let span = Int::abs(depths[sv] - depths[su])
        if span > 1 {
          0
        } else if span == 1 {
          1
        } else {
          2
        }
      }
    }
    let b_priority = if b_self {
      3
    } else {
      let su = id_to_idx.get_or_default(b.src_id, -1)
      let sv = id_to_idx.get_or_default(b.dst_id, -1)
      if su < 0 || sv < 0 {
        3
      } else {
        let span = Int::abs(depths[sv] - depths[su])
        if span > 1 {
          0
        } else if span == 1 {
          1
        } else {
          2
        }
      }
    }
    if a_priority != b_priority {
      a_priority - b_priority
    } else {
      let a_span = if a_self {
        0
      } else {
        let su = id_to_idx.get_or_default(a.src_id, -1)
        let sv = id_to_idx.get_or_default(a.dst_id, -1)
        if su < 0 || sv < 0 {
          0
        } else {
          Int::abs(depths[sv] - depths[su])
        }
      }
      let b_span = if b_self {
        0
      } else {
        let su = id_to_idx.get_or_default(b.src_id, -1)
        let sv = id_to_idx.get_or_default(b.dst_id, -1)
        if su < 0 || sv < 0 {
          0
        } else {
          Int::abs(depths[sv] - depths[su])
        }
      }
      if a_span != b_span {
        b_span - a_span
      } else {
        a.index - b.index
      }
    }
  })
  for edge in ordered_edges {
    if self_loop.contains(edge.index) {
      let b = match boxes.get(edge.src_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{edge.src_id}")
      }
      patch.edges[edge.index] = self_loop_route(
        b,
        direction,
        config.edge_padding,
      )
      continue
    }
    let su = require_index(id_to_idx, edge.src_id)
    let sv = require_index(id_to_idx, edge.dst_id)
    let du = depths[su]
    let dv = depths[sv]
    if du == dv {
      let src_box = match boxes.get(edge.src_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{edge.src_id}")
      }
      let dst_box = match boxes.get(edge.dst_id) {
        Some(b) => b
        None => raise Unsupported("missing box for node: \{edge.dst_id}")
      }
      patch.edges[edge.index] = same_rank_route(
        src_box, dst_box, direction, config,
      )
      continue
    }
    let start = match src_ports.get(edge.index) {
      Some(p) => p
      None => raise Unsupported("missing src port for edge: \{edge.index}")
    }
    let end = match dst_ports.get(edge.index) {
      Some(p) => p
      None => raise Unsupported("missing dst port for edge: \{edge.index}")
    }
    patch.edges[edge.index] = route_edge(
      edge.index,
      edge.src_id,
      edge.dst_id,
      du,
      dv,
      rail_tracks.get(edge.index).unwrap_or(0),
      shift_by_edge.get(edge.index).unwrap_or(0.0),
      start,
      end,
      boxes,
      object_by_id,
      parent_id_by_child_id,
      direction,
      config,
      level_heights,
      reserved_label_boxes,
      gap_rail_reservations,
      channel_reservations,
    )
  }
}

///|
fn collect_reserved_container_label_boxes_railway(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Array[@graph.Box] {
  let reserved : Array[@graph.Box] = []
  for obj in graph.objects {
    if !is_layout_container_candidate(obj) {
      continue
    }
    match patch.node_labels.get(obj.id) {
      Some(label_box) => reserved.push(label_box)
      None => ()
    }
  }
  reserved
}

///|
fn sync_boxes_from_patch_railway(
  boxes : Map[String, @graph.Box],
  patch : @graph.LayoutPatch,
) -> Unit {
  for entry in patch.nodes {
    boxes[entry.0] = entry.1
  }
}

///|
fn keep_legacy_railway_symbols_alive() -> Unit {
  ignore(object_size)
  ignore(relax_layout_nodes_against_containers)
  ignore(spread_sibling_boxes_railway)
  ignore(place_nodes_grid)
  ignore(global_backward_rail_anchor)
  ignore(railway_readability_metrics)
  ignore(compute_depths)
  ignore(make_levels)
}
