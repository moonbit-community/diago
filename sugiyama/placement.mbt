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
/// Backend-independent layered placement produced by the Sugiyama pipeline.
pub(all) struct PlacementResult {
  boxes : Map[@layout_core.ObjectId, @graph.Box]
  rank_by_id : Map[@layout_core.ObjectId, Int]
  level_heights : Array[Double]
  virtual_node_count : Int
  reversed_edge_count : Int
}

///|
/// Run cycle breaking, layer assignment, virtual-node insertion, crossing
/// minimization, and coordinate assignment over a canonical layout problem.
pub fn place(
  problem : @layout_core.LayoutProblem,
  measure_object : (@graph.ObjectInput) -> (Double, Double),
  direction : @engine_api.Direction,
  horizontal_spacing : Double,
  vertical_spacing : Double,
) -> PlacementResult {
  let graph = problem.graph()
  let cycle = break_cycles(graph)
  let layers = assign_layers(graph, cycle)
  let virtual_result = insert_virtual_nodes(graph, layers, cycle)
  let crossing = minimize_crossings_with_virtual(
    graph,
    virtual_result.layer_assignment,
    cycle,
    virtual_result.virtual_nodes,
  )
  let widths : Map[String, Double] = Map([])
  let heights : Map[String, Double] = Map([])
  for obj in graph.objects {
    let id = obj.lookup_id()
    let (width, height) = measure_object(obj)
    widths[id] = positive_dimension(width)
    heights[id] = positive_dimension(height)
  }
  for virtual_id, _ in virtual_result.virtual_nodes {
    widths[virtual_id] = 1.0
    heights[virtual_id] = 1.0
  }
  let coordinates = assign_coordinates(
    graph, crossing, cycle, widths, heights, horizontal_spacing, vertical_spacing,
  )
  let down_boxes : Map[@layout_core.ObjectId, @graph.Box] = Map([])
  let rank_by_id : Map[@layout_core.ObjectId, Int] = Map([])
  for obj in graph.objects {
    let raw_id = obj.lookup_id()
    let id = @layout_core.ObjectId::new(raw_id)
    let width = widths.get(raw_id).unwrap_or(1.0)
    let height = heights.get(raw_id).unwrap_or(1.0)
    down_boxes[id] = @graph.Box::new(
      coordinates.x_coords.get(raw_id).unwrap_or(0.0),
      coordinates.y_coords.get(raw_id).unwrap_or(0.0),
      width,
      height,
    )
    rank_by_id[id] = virtual_result.layer_assignment.layers
      .get(raw_id)
      .unwrap_or(0)
  }
  let boxes = orient_placement_boxes(down_boxes, direction)
  let level_heights = placement_level_heights(
    boxes,
    rank_by_id,
    virtual_result.layer_assignment.layer_count,
    direction,
  )
  {
    boxes,
    rank_by_id,
    level_heights,
    virtual_node_count: virtual_result.virtual_nodes.length(),
    reversed_edge_count: cycle.reversed_edges.length(),
  }
}

///|
fn positive_dimension(value : Double) -> Double {
  if value > 0.0 {
    value
  } else {
    1.0
  }
}

///|
fn orient_placement_boxes(
  down_boxes : Map[@layout_core.ObjectId, @graph.Box],
  direction : @engine_api.Direction,
) -> Map[@layout_core.ObjectId, @graph.Box] {
  if direction == Down {
    return down_boxes
  }
  let oriented : Map[@layout_core.ObjectId, @graph.Box] = Map([])
  match direction {
    Down => ()
    Up => {
      let max_y = placement_max_y(down_boxes)
      for id, box in down_boxes {
        oriented[id] = @graph.Box::new(
          box.x,
          max_y - box.y - box.height,
          box.width,
          box.height,
        )
      }
    }
    Right =>
      for id, box in down_boxes {
        oriented[id] = @graph.Box::new(box.y, box.x, box.height, box.width)
      }
    Left => {
      let right_boxes : Map[@layout_core.ObjectId, @graph.Box] = Map([])
      for id, box in down_boxes {
        right_boxes[id] = @graph.Box::new(box.y, box.x, box.height, box.width)
      }
      let max_x = placement_max_x(right_boxes)
      for id, box in right_boxes {
        oriented[id] = @graph.Box::new(
          max_x - box.x - box.width,
          box.y,
          box.width,
          box.height,
        )
      }
    }
  }
  oriented
}

///|
fn placement_max_x(boxes : Map[@layout_core.ObjectId, @graph.Box]) -> Double {
  let mut max_x = 0.0
  for _, box in boxes {
    if box.x + box.width > max_x {
      max_x = box.x + box.width
    }
  }
  max_x
}

///|
fn placement_max_y(boxes : Map[@layout_core.ObjectId, @graph.Box]) -> Double {
  let mut max_y = 0.0
  for _, box in boxes {
    if box.y + box.height > max_y {
      max_y = box.y + box.height
    }
  }
  max_y
}

///|
fn placement_level_heights(
  boxes : Map[@layout_core.ObjectId, @graph.Box],
  rank_by_id : Map[@layout_core.ObjectId, Int],
  layer_count : Int,
  direction : @engine_api.Direction,
) -> Array[Double] {
  let count = if layer_count > 0 { layer_count } else { 1 }
  let heights = Array::make(count, 1.0)
  for id, box in boxes {
    let rank = rank_by_id.get(id).unwrap_or(0)
    if rank < 0 || rank >= heights.length() {
      continue
    }
    let main_size = match direction {
      Down | Up => box.height
      Right | Left => box.width
    }
    if main_size > heights[rank] {
      heights[rank] = main_size
    }
  }
  heights
}
