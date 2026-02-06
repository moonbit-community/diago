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
/// Dagre-style engine implementation based on Sugiyama phases.

///|
pub struct DagreEngine {
  _marker : Unit
} derive(Show)

///|
pub fn DagreEngine::new() -> DagreEngine {
  { _marker: () }
}

///|
pub impl @engine_api.LayoutEngine for DagreEngine with layout(
  _self,
  graph,
  config,
  direction,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  if graph.objects.length() == 0 {
    return @graph.LayoutPatch::new()
  }
  let down_patch = layout_down(graph, config)
  transform_patch(down_patch, direction)
}

///|
fn layout_down(
  graph : @graph.GraphInput,
  config : @engine_api.LayoutConfig,
) -> @graph.LayoutPatch raise @engine_api.LayoutError {
  let sized_graph = @engine_elk.layout(
    graph,
    config,
    @engine_api.Direction::Down,
  )
  let sized_boxes : Map[String, @graph.Box] = {}
  for obj in sized_graph.objects {
    match obj.box {
      Some(b) => sized_boxes[obj.id] = b
      None => ()
    }
  }
  let sized_edge_labels : Map[Int, @graph.Box] = {}
  for edge in sized_graph.edges {
    match edge.label_box {
      Some(b) => sized_edge_labels[edge.index] = b
      None => ()
    }
  }
  let cycle_result = @sugiyama.break_cycles(graph)
  let layer_result = @sugiyama.assign_layers(graph, cycle_result)
  let crossing_result = @sugiyama.minimize_crossings(
    graph, layer_result, cycle_result,
  )
  let node_widths : Map[String, Double] = {}
  let node_heights : Map[String, Double] = {}
  for obj in graph.objects {
    let (w, h) = node_dimensions(obj, config, sized_boxes)
    node_widths[obj.id] = w
    node_heights[obj.id] = h
  }
  let coords = @sugiyama.assign_coordinates(
    graph,
    crossing_result,
    cycle_result,
    node_widths,
    node_heights,
    config.horizontal_spacing,
    config.vertical_spacing,
  )
  let container_ranks = @sugiyama.compute_container_ranks(
    graph,
    crossing_result.ordered_layers,
  )
  @sugiyama.expand_containers_to_fit(
    coords,
    graph,
    crossing_result.ordered_layers,
    container_ranks,
    config.container_padding,
  )
  let patch = @graph.LayoutPatch::new()
  let object_by_id : Map[String, @graph.ObjectInput] = {}
  for obj in graph.objects {
    object_by_id[obj.id] = obj
    let x = coords.x_coords.get(obj.id).unwrap_or(0.0)
    let y = coords.y_coords.get(obj.id).unwrap_or(0.0)
    let w = node_widths.get(obj.id).unwrap_or(config.default_width)
    let h = node_heights.get(obj.id).unwrap_or(config.default_height)
    patch.nodes[obj.id] = @graph.Box::new(x, y, w, h)
  }
  for obj in graph.objects {
    if obj.child_ids.length() > 0 {
      fit_container_box(
        obj.id,
        object_by_id,
        patch.nodes,
        config.container_padding,
      )
    }
  }
  let layer_by_id = layer_result.layers
  for edge in graph.edges {
    let route = route_edge_down(
      edge,
      patch.nodes,
      layer_by_id,
      config.edge_padding,
    )
    patch.edges[edge.index] = route
    match sized_edge_labels.get(edge.index) {
      Some(b) => patch.edge_labels[edge.index] = b
      None =>
        if edge.label != "" {
          patch.edge_labels[edge.index] = estimate_edge_label_box(
            edge.label,
            route,
          )
        }
    }
  }
  patch
}

///|
fn node_dimensions(
  obj : @graph.ObjectInput,
  config : @engine_api.LayoutConfig,
  sized_boxes : Map[String, @graph.Box],
) -> (Double, Double) {
  match sized_boxes.get(obj.id) {
    Some(b) => (b.width, b.height)
    None =>
      match obj.box {
        Some(b) => (b.width, b.height)
        None => (config.default_width, config.default_height)
      }
  }
}

///|
fn fit_container_box(
  container_id : String,
  object_by_id : Map[String, @graph.ObjectInput],
  boxes : Map[String, @graph.Box],
  padding : Double,
) -> Unit {
  let container = match object_by_id.get(container_id) {
    Some(v) => v
    None => return
  }
  if container.child_ids.length() == 0 {
    return
  }
  let mut min_x = 1.0e18
  let mut min_y = 1.0e18
  let mut max_x = -1.0e18
  let mut max_y = -1.0e18
  let mut has_child = false
  for child_id in container.child_ids {
    fit_container_box(child_id, object_by_id, boxes, padding)
    match boxes.get(child_id) {
      Some(cb) => {
        has_child = true
        if cb.x < min_x {
          min_x = cb.x
        }
        if cb.y < min_y {
          min_y = cb.y
        }
        if cb.x + cb.width > max_x {
          max_x = cb.x + cb.width
        }
        if cb.y + cb.height > max_y {
          max_y = cb.y + cb.height
        }
      }
      None => ()
    }
  }
  if !has_child {
    return
  }
  let base = boxes.get(container_id).unwrap_or(@graph.Box::zero())
  let target_x = min_x - padding
  let target_y = min_y - padding
  let target_w = max_x - min_x + 2.0 * padding
  let target_h = max_y - min_y + 2.0 * padding
  let x = target_x
  let y = target_y
  let width = @cmp.maximum(base.width, target_w)
  let height = @cmp.maximum(base.height, target_h)
  boxes[container_id] = @graph.Box::new(x, y, width, height)
}

///|
fn route_edge_down(
  edge : @graph.EdgeInput,
  node_boxes : Map[String, @graph.Box],
  layer_by_id : Map[String, Int],
  edge_padding : Double,
) -> Array[@graph.Point] {
  if edge.src_id == edge.dst_id {
    return self_loop_route(edge.src_id, node_boxes, edge_padding)
  }
  let src_box = match node_boxes.get(edge.src_id) {
    Some(b) => b
    None => return []
  }
  let dst_box = match node_boxes.get(edge.dst_id) {
    Some(b) => b
    None => return []
  }
  let src_layer = layer_by_id.get(edge.src_id).unwrap_or(0)
  let dst_layer = layer_by_id.get(edge.dst_id).unwrap_or(0)
  if src_layer == dst_layer {
    return route_same_layer(src_box, dst_box)
  }
  route_cross_layer(src_box, dst_box, src_layer < dst_layer)
}

///|
fn route_cross_layer(
  src_box : @graph.Box,
  dst_box : @graph.Box,
  forward : Bool,
) -> Array[@graph.Point] {
  let src_center = src_box.center()
  let dst_center = dst_box.center()
  let start = if forward {
    @graph.Point::new(src_center.x, src_box.y + src_box.height)
  } else {
    @graph.Point::new(src_center.x, src_box.y)
  }
  let end = if forward {
    @graph.Point::new(dst_center.x, dst_box.y)
  } else {
    @graph.Point::new(dst_center.x, dst_box.y + dst_box.height)
  }
  if (start.x - end.x).abs() <= 0.5 {
    [start, end]
  } else {
    let mid_y = (start.y + end.y) / 2.0
    [
      start,
      @graph.Point::new(start.x, mid_y),
      @graph.Point::new(end.x, mid_y),
      end,
    ]
  }
}

///|
fn route_same_layer(
  src_box : @graph.Box,
  dst_box : @graph.Box,
) -> Array[@graph.Point] {
  let src_center = src_box.center()
  let dst_center = dst_box.center()
  let to_right = dst_center.x >= src_center.x
  let start = if to_right {
    @graph.Point::new(src_box.x + src_box.width, src_center.y)
  } else {
    @graph.Point::new(src_box.x, src_center.y)
  }
  let end = if to_right {
    @graph.Point::new(dst_box.x, dst_center.y)
  } else {
    @graph.Point::new(dst_box.x + dst_box.width, dst_center.y)
  }
  if (start.y - end.y).abs() <= 0.5 {
    [start, end]
  } else {
    let mid_x = (start.x + end.x) / 2.0
    [
      start,
      @graph.Point::new(mid_x, start.y),
      @graph.Point::new(mid_x, end.y),
      end,
    ]
  }
}

///|
fn self_loop_route(
  node_id : String,
  node_boxes : Map[String, @graph.Box],
  edge_padding : Double,
) -> Array[@graph.Point] {
  let b = match node_boxes.get(node_id) {
    Some(v) => v
    None => return []
  }
  let offset = @cmp.maximum(20.0, edge_padding)
  let x0 = b.x + b.width
  let y0 = b.y + b.height / 2.0
  [
    @graph.Point::new(x0, y0),
    @graph.Point::new(x0 + offset, y0),
    @graph.Point::new(x0 + offset, y0 + offset),
    @graph.Point::new(x0, y0 + offset),
    @graph.Point::new(x0, y0),
  ]
}

///|
fn estimate_edge_label_box(
  label : String,
  route : Array[@graph.Point],
) -> @graph.Box {
  let char_width = 8.0
  let label_width = @cmp.maximum(24.0, label.length().to_double() * char_width)
  let label_height = 20.0
  let anchor = if route.length() == 0 {
    @graph.Point::new(0.0, 0.0)
  } else if route.length() == 1 {
    route[0]
  } else {
    route[route.length() / 2]
  }
  @graph.Box::new(
    anchor.x - label_width / 2.0,
    anchor.y - label_height / 2.0,
    label_width,
    label_height,
  )
}

///|
fn transform_patch(
  patch : @graph.LayoutPatch,
  direction : @engine_api.Direction,
) -> @graph.LayoutPatch {
  if direction == Down {
    return normalize_patch_origin(patch)
  }
  let bounds = patch_bounds(patch)
  let out = @graph.LayoutPatch::new()
  for pair in patch.nodes.iter() {
    let (id_view, b) = pair
    out.nodes[id_view.to_string()] = transform_box(b, direction, bounds)
  }
  for pair in patch.edges.iter() {
    let (edge_idx, points) = pair
    let transformed : Array[@graph.Point] = []
    for p in points {
      transformed.push(transform_point(p, direction, bounds))
    }
    out.edges[edge_idx] = transformed
  }
  for pair in patch.edge_labels.iter() {
    let (edge_idx, b) = pair
    out.edge_labels[edge_idx] = transform_box(b, direction, bounds)
  }
  for pair in patch.activation_boxes {
    out.activation_boxes.push(
      (pair.0, transform_box(pair.1, direction, bounds)),
    )
  }
  for pair in patch.sequence_notes {
    out.sequence_notes.push(
      (pair.0, pair.1, transform_box(pair.2, direction, bounds)),
    )
  }
  for fragment in patch.sequence_fragments {
    let bbox = match fragment.bbox {
      Some(b) => Some(transform_box(b, direction, bounds))
      None => None
    }
    let operands : Array[@graph.FragmentOperandLayout] = []
    for op in fragment.operands {
      operands.push(op)
    }
    out.sequence_fragments.push(
      @graph.SequenceFragmentLayout::new(
        fragment.fragment_type,
        fragment.condition,
        bbox,
        fragment.start_index,
        fragment.end_index,
        operands,
      ),
    )
  }
  normalize_patch_origin(out)
}

///|
fn transform_box(
  b : @graph.Box,
  direction : @engine_api.Direction,
  bounds : @graph.Box,
) -> @graph.Box {
  match direction {
    Down => b
    Up =>
      @graph.Box::new(
        b.x,
        bounds.y + bounds.height - (b.y + b.height),
        b.width,
        b.height,
      )
    Right => @graph.Box::new(b.y, b.x, b.height, b.width)
    Left =>
      @graph.Box::new(
        bounds.y + bounds.height - (b.y + b.height),
        b.x,
        b.height,
        b.width,
      )
  }
}

///|
fn transform_point(
  p : @graph.Point,
  direction : @engine_api.Direction,
  bounds : @graph.Box,
) -> @graph.Point {
  match direction {
    Down => p
    Up => @graph.Point::new(p.x, bounds.y + bounds.height - p.y)
    Right => @graph.Point::new(p.y, p.x)
    Left => @graph.Point::new(bounds.y + bounds.height - p.y, p.x)
  }
}

///|
fn patch_bounds(patch : @graph.LayoutPatch) -> @graph.Box {
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut first = true
  fn include_point(
    min_x : Double,
    min_y : Double,
    max_x : Double,
    max_y : Double,
    first : Bool,
    x : Double,
    y : Double,
  ) -> (Double, Double, Double, Double, Bool) {
    if first {
      (x, y, x, y, false)
    } else {
      let mut min_x = min_x
      let mut min_y = min_y
      let mut max_x = max_x
      let mut max_y = max_y
      if x < min_x {
        min_x = x
      }
      if y < min_y {
        min_y = y
      }
      if x > max_x {
        max_x = x
      }
      if y > max_y {
        max_y = y
      }
      (min_x, min_y, max_x, max_y, false)
    }
  }

  for pair in patch.nodes.iter() {
    let (_, b) = pair
    let r1 = include_point(min_x, min_y, max_x, max_y, first, b.x, b.y)
    min_x = r1.0
    min_y = r1.1
    max_x = r1.2
    max_y = r1.3
    first = r1.4
    let r2 = include_point(
      min_x,
      min_y,
      max_x,
      max_y,
      first,
      b.x + b.width,
      b.y + b.height,
    )
    min_x = r2.0
    min_y = r2.1
    max_x = r2.2
    max_y = r2.3
    first = r2.4
  }
  for pair in patch.edges.iter() {
    let (_, points) = pair
    for p in points {
      let r = include_point(min_x, min_y, max_x, max_y, first, p.x, p.y)
      min_x = r.0
      min_y = r.1
      max_x = r.2
      max_y = r.3
      first = r.4
    }
  }
  if first {
    @graph.Box::zero()
  } else {
    @graph.Box::new(min_x, min_y, max_x - min_x, max_y - min_y)
  }
}

///|
fn normalize_patch_origin(patch : @graph.LayoutPatch) -> @graph.LayoutPatch {
  let bounds = patch_bounds(patch)
  let dx = -bounds.x
  let dy = -bounds.y
  let out = @graph.LayoutPatch::new()
  for pair in patch.nodes.iter() {
    let (id_view, b) = pair
    out.nodes[id_view.to_string()] = @graph.Box::new(
      b.x + dx,
      b.y + dy,
      b.width,
      b.height,
    )
  }
  for pair in patch.edges.iter() {
    let (edge_idx, points) = pair
    let shifted : Array[@graph.Point] = []
    for p in points {
      shifted.push(@graph.Point::new(p.x + dx, p.y + dy))
    }
    out.edges[edge_idx] = shifted
  }
  for pair in patch.edge_labels.iter() {
    let (edge_idx, b) = pair
    out.edge_labels[edge_idx] = @graph.Box::new(
      b.x + dx,
      b.y + dy,
      b.width,
      b.height,
    )
  }
  for pair in patch.activation_boxes {
    out.activation_boxes.push(
      (
        pair.0,
        @graph.Box::new(
          pair.1.x + dx,
          pair.1.y + dy,
          pair.1.width,
          pair.1.height,
        ),
      ),
    )
  }
  for pair in patch.sequence_notes {
    out.sequence_notes.push(
      (
        pair.0,
        pair.1,
        @graph.Box::new(
          pair.2.x + dx,
          pair.2.y + dy,
          pair.2.width,
          pair.2.height,
        ),
      ),
    )
  }
  for fragment in patch.sequence_fragments {
    let bbox = match fragment.bbox {
      Some(b) => Some(@graph.Box::new(b.x + dx, b.y + dy, b.width, b.height))
      None => None
    }
    let operands : Array[@graph.FragmentOperandLayout] = []
    for op in fragment.operands {
      operands.push(op)
    }
    out.sequence_fragments.push(
      @graph.SequenceFragmentLayout::new(
        fragment.fragment_type,
        fragment.condition,
        bbox,
        fragment.start_index,
        fragment.end_index,
        operands,
      ),
    )
  }
  out
}
