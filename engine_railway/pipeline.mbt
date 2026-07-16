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
fn copy_passthrough_layout_data(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  for fragment in graph.sequence_fragments_layout {
    patch.sequence_fragments.push(fragment)
  }
  for activation in graph.activation_boxes {
    patch.activation_boxes.push(activation)
  }
  for note in graph.sequence_notes {
    patch.sequence_notes.push(note)
  }
}

///|
const RAILWAY_CONTAINER_PADDING : Double = 30.0

///|
priv struct RailwayNodeLayout {
  boxes : Map[String, @graph.Box]
  level_heights : Array[Double]
  rank_by_id : Map[String, Int]
}

///|
priv struct RailwayPlacementResult {
  layout_input : @graph.GraphInput
  object_by_id : Map[String, @graph.ObjectInput]
  parent_id_by_child_id : Map[String, String]
  self_loop : @hashset.HashSet[Int]
  id_to_idx : Map[String, Int]
  boxes : Map[String, @graph.Box]
  rank_by_id : Map[String, Int]
  depths : Array[Int]
  level_heights : Array[Double]
}

///|
priv struct RailwayHierarchyLayout {
  patch : @graph.LayoutPatch
  boxes : Map[String, @graph.Box]
}

///|
priv struct RailwayRoutingProblem {
  patch : @graph.LayoutPatch
  layout_input : @graph.GraphInput
  object_by_id : Map[String, @graph.ObjectInput]
  parent_id_by_child_id : Map[String, String]
  self_loop : @hashset.HashSet[Int]
  id_to_idx : Map[String, Int]
  depths : Array[Int]
  rail_tracks : Map[Int, Int]
  shift_by_edge : Map[Int, Double]
  lane_by_edge : Map[Int, Int]
  src_ports : Map[Int, @graph.Point]
  dst_ports : Map[Int, @graph.Point]
  boxes : Map[String, @graph.Box]
  direction : @engine_api.Direction
  config : @engine_api.LayoutConfig
  level_heights : Array[Double]
}

///|
priv struct RailwayRoutingResult {
  patch : @graph.LayoutPatch
}

///|
fn rank_array_for_layout(
  graph : @graph.GraphInput,
  id_to_idx : Map[String, Int],
  rank_by_id : Map[String, Int],
) -> Array[Int] {
  let depth = Array::make(graph.objects.length(), 0)
  for obj in graph.objects {
    let idx = match id_to_idx.get(obj.id) {
      Some(v) => v
      None => continue
    }
    depth[idx] = rank_by_id.get_or_default(obj.id, 0)
  }
  depth
}
