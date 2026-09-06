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
const D2_LABEL_PADDING : Double = 5.0

///|
const D2_SEQUENCE_HORIZONTAL_PAD : Double = 40.0

///|
const D2_SEQUENCE_LABEL_HORIZONTAL_PAD : Double = 60.0

///|
const D2_SEQUENCE_VERTICAL_PAD : Double = 40.0

///|
const D2_SEQUENCE_MIN_ACTOR_DISTANCE : Double = 150.0

///|
const D2_SEQUENCE_MIN_ACTOR_WIDTH : Double = 100.0

///|
const D2_SEQUENCE_MIN_ACTOR_HEIGHT : Double = 66.0

///|
const D2_SEQUENCE_SELF_MESSAGE_HORIZONTAL_TRAVEL : Double = 80.0

///|
const D2_SEQUENCE_GROUP_CONTAINER_PADDING : Double = 12.0

///|
const D2_SEQUENCE_EDGE_GROUP_LABEL_PADDING : Double = 20.0

///|
const D2_SEQUENCE_MIN_MESSAGE_DISTANCE : Double = 30.0

///|
const D2_SEQUENCE_SPAN_BASE_WIDTH : Double = 12.0

///|
const D2_SEQUENCE_SPAN_DEPTH_GROWTH : Double = 8.0

///|
const D2_SEQUENCE_MIN_SPAN_HEIGHT : Double = 30.0

///|
const D2_SEQUENCE_SPAN_MESSAGE_PAD : Double = 10.0

///|
pub fn layout(
  graph : @graph.GraphInput,
  measure_object : (@graph.ObjectInput) -> (Double, Double),
) -> @graph.LayoutPatch {
  let patch = @graph.LayoutPatch::new()
  copy_passthrough_layout_data(patch, graph)

  let object_by_abs_id : Map[String, @graph.ObjectInput] = Map([])
  object_by_abs_id[graph.root.abs_id_syntax] = graph.root
  for obj in graph.objects {
    object_by_abs_id[obj.abs_id_syntax] = obj
  }
  let participant_ids = sequence_participant_ids(graph)
  if participant_ids.is_empty() {
    return patch
  }
  let parent_id_by_child_id = sequence_parent_id_by_child_id(graph)
  let participant_alias_by_abs_id = sequence_participant_alias_by_abs_id(
    graph, participant_ids, object_by_abs_id,
  )

  let participant_rank_by_id : Map[String, Int] = Map([])
  let participant_exists : Map[String, Bool] = Map([])
  let raw_widths : Array[Double] = []
  let widths : Array[Double] = []
  let heights : Array[Double] = []
  let mut max_actor_height = 0.0
  for id in participant_ids {
    let rank = widths.length()
    participant_rank_by_id[id] = rank
    participant_exists[id] = true
    match object_by_abs_id.get(id) {
      Some(obj) => {
        let (w0, h0) = measure_object(obj)
        raw_widths.push(w0)
        let (width, height) = sequence_actor_size(obj.shape_type, w0, h0)
        widths.push(width)
        heights.push(height)
        if height > max_actor_height {
          max_actor_height = height
        }
      }
      None => {
        raw_widths.push(D2_SEQUENCE_MIN_ACTOR_WIDTH)
        widths.push(D2_SEQUENCE_MIN_ACTOR_WIDTH)
        heights.push(D2_SEQUENCE_MIN_ACTOR_HEIGHT)
        if D2_SEQUENCE_MIN_ACTOR_HEIGHT > max_actor_height {
          max_actor_height = D2_SEQUENCE_MIN_ACTOR_HEIGHT
        }
      }
    }
  }
  let (sequence_notes_for_layout, _, note_line_by_id_for_layout) = sequence_collect_notes_and_spans_like_d2(
    graph, participant_exists, parent_id_by_child_id, participant_alias_by_abs_id,
  )
  let note_height_by_id_for_layout : Map[String, Double] = Map([])
  for note in sequence_notes_for_layout {
    let (_, height) = sequence_note_size_like_d2(note, measure_object)
    note_height_by_id_for_layout[note.abs_id_syntax] = height
  }

  let actor_x_step : Array[Double] = []
  if participant_ids.length() >= 2 {
    for i = 0; i < participant_ids.length() - 1; i = i + 1 {
      let actor_hw = widths[i] / 2.0
      let next_actor_hw = raw_widths[i + 1] / 2.0
      let base_step = actor_hw + next_actor_hw + D2_SEQUENCE_HORIZONTAL_PAD
      let step = if base_step < D2_SEQUENCE_MIN_ACTOR_DISTANCE {
        D2_SEQUENCE_MIN_ACTOR_DISTANCE
      } else {
        base_step
      }
      actor_x_step.push(step)
    }
  }
  let max_note_width_by_participant_id = sequence_max_note_width_by_participant_id_like_d2(
    graph, participant_exists, parent_id_by_child_id, participant_alias_by_abs_id,
    measure_object,
  )
  for i, participant_id in participant_ids {
    let max_note_width = max_note_width_by_participant_id.get_or_default(
      participant_id, 0.0,
    )
    if max_note_width <= 0.0 {
      continue
    }
    let required = max_note_width / 2.0 + D2_SEQUENCE_HORIZONTAL_PAD
    if i < actor_x_step.length() {
      if required > actor_x_step[i] {
        actor_x_step[i] = required
      }
      if i > 0 && required > actor_x_step[i - 1] {
        actor_x_step[i - 1] = required
      }
    }
  }

  let ordered_edges = sequence_edges_in_render_order(graph)
  for edge in ordered_edges {
    let src_rank = match
      participant_rank_by_id.get(
        sequence_top_participant_id(
          edge.src_id_syntax,
          participant_exists,
          parent_id_by_child_id,
          participant_alias_by_abs_id,
        ),
      ) {
      Some(v) => v
      None => continue
    }
    let dst_rank = match
      participant_rank_by_id.get(
        sequence_top_participant_id(
          edge.dst_id_syntax,
          participant_exists,
          parent_id_by_child_id,
          participant_alias_by_abs_id,
        ),
      ) {
      Some(v) => v
      None => continue
    }
    let (label_width, _) = sequence_edge_text_size(edge)
    let rank_diff = if src_rank > dst_rank {
      src_rank - dst_rank
    } else {
      dst_rank - src_rank
    }
    if rank_diff != 0 {
      let distributed_label_width = label_width / rank_diff.to_double()
      let left = if src_rank < dst_rank { src_rank } else { dst_rank }
      let right = if src_rank < dst_rank { dst_rank } else { src_rank }
      for rank = left; rank < right; rank = rank + 1 {
        let required = distributed_label_width +
          D2_SEQUENCE_LABEL_HORIZONTAL_PAD
        if required > actor_x_step[rank] {
          actor_x_step[rank] = required
        }
      }
    } else if src_rank < actor_x_step.length() {
      let label_adjust = label_width + D2_LABEL_PADDING * 4.0
      if label_adjust > actor_x_step[src_rank] {
        actor_x_step[src_rank] = label_adjust
      }
    }
  }

  let centers : Array[Double] = []
  if !widths.is_empty() {
    centers.push(D2_SEQUENCE_GROUP_CONTAINER_PADDING + widths[0] / 2.0)
    for i = 1; i < widths.length(); i = i + 1 {
      centers.push(centers[i - 1] + actor_x_step[i - 1])
    }
  }

  let max_actor_height = max_actor_height +
    D2_SEQUENCE_VERTICAL_PAD +
    sequence_root_label_height(graph)
  let y_shift = D2_SEQUENCE_GROUP_CONTAINER_PADDING
  for i, id in participant_ids {
    let width = widths[i]
    let height = heights[i]
    let mut y = max_actor_height - height + y_shift
    match object_by_abs_id.get(id) {
      Some(obj) =>
        if has_outside_bottom_label(obj.shape_type) {
          y = y - sequence_label_height(obj)
        }
      None => ()
    }
    let actor_box = @graph.Box::new(
      (centers[i] - width / 2.0).round(),
      y,
      width,
      height,
    )
    patch.nodes[id] = actor_box
    match object_by_abs_id.get(id) {
      Some(obj) => {
        let font_size = match obj.style.font_size {
          Some(value) => value.as_int().unwrap_or(16)
          None => 16
        }
        let dims = measure_object_label_dims(
          obj,
          font_size,
          style_is_mono(obj.style.font),
          style_bool(obj.style.bold, false),
          style_bool(obj.style.italic, false),
        )
        if dims.width > 0.0 && dims.height > 0.0 {
          patch.node_labels[id] = @graph.Box::new(
            actor_box.x,
            actor_box.y + actor_box.height,
            dims.width,
            dims.height,
          )
        }
      }
      None => ()
    }
  }

  let y_step = D2_SEQUENCE_MIN_MESSAGE_DISTANCE + D2_SEQUENCE_VERTICAL_PAD
  let mut message_offset = max_actor_height + y_step + y_shift
  for edge in ordered_edges {
    let note_offset = sequence_note_vertical_offset_before_edge_like_d2(
      edge, sequence_notes_for_layout, note_line_by_id_for_layout, note_height_by_id_for_layout,
      y_step,
    )
    let (_, text_height) = sequence_edge_text_size(edge)
    let src_x = match
      sequence_center_x_for_object(
        edge.src_id_syntax,
        patch,
        parent_id_by_child_id,
        participant_alias_by_abs_id,
      ) {
      Some(v) => v
      None => continue
    }
    let dst_x = match
      sequence_center_x_for_object(
        edge.dst_id_syntax,
        patch,
        parent_id_by_child_id,
        participant_alias_by_abs_id,
      ) {
      Some(v) => v
      None => continue
    }
    let src_top = sequence_top_participant_id(
      edge.src_id_syntax,
      participant_exists,
      parent_id_by_child_id,
      participant_alias_by_abs_id,
    )
    let dst_top = sequence_top_participant_id(
      edge.dst_id_syntax,
      participant_exists,
      parent_id_by_child_id,
      participant_alias_by_abs_id,
    )
    let is_to_descendant = is_descendant_of(
      edge.dst_id_syntax,
      edge.src_id_syntax,
      parent_id_by_child_id,
    )
    let is_from_descendant = is_descendant_of(
      edge.src_id_syntax,
      edge.dst_id_syntax,
      parent_id_by_child_id,
    )
    let is_self_message = edge.src_id_syntax == edge.dst_id_syntax
    let is_to_sibling = src_top == dst_top

    if is_self_message ||
      is_to_descendant ||
      is_from_descendant ||
      is_to_sibling {
      let (label_width, _) = sequence_edge_text_size(edge)
      let mid_x = src_x +
        (if D2_SEQUENCE_SELF_MESSAGE_HORIZONTAL_TRAVEL >
          label_width / 2.0 + D2_LABEL_PADDING * 2.0 {
          D2_SEQUENCE_SELF_MESSAGE_HORIZONTAL_TRAVEL
        } else {
          label_width / 2.0 + D2_LABEL_PADDING * 2.0
        })
      let start_y = message_offset + note_offset
      let end_y = start_y +
        (if text_height > D2_SEQUENCE_MIN_MESSAGE_DISTANCE {
          text_height * 1.5
        } else {
          D2_SEQUENCE_MIN_MESSAGE_DISTANCE * 1.5
        })
      patch.edges[edge.index] = [
        @graph.Point::new(src_x, start_y),
        @graph.Point::new(mid_x, start_y),
        @graph.Point::new(mid_x, end_y),
        @graph.Point::new(dst_x, end_y),
      ]
      message_offset = end_y + y_step - note_offset
    } else {
      let start_y = message_offset + note_offset + text_height / 2.0
      patch.edges[edge.index] = [
        @graph.Point::new(src_x, start_y),
        @graph.Point::new(dst_x, start_y),
      ]
      message_offset = start_y + text_height / 2.0 + y_step - note_offset
    }
  }

  sequence_place_nested_objects_like_d2(
    patch, graph, ordered_edges, participant_exists, parent_id_by_child_id, object_by_abs_id,
    participant_alias_by_abs_id, measure_object, max_actor_height, y_step,
  )

  for edge in ordered_edges {
    let route = match patch.edges.get(edge.index) {
      Some(v) => v
      None => continue
    }
    if route.is_empty() {
      continue
    }
    let src_top = sequence_top_participant_id(
      edge.src_id_syntax,
      participant_exists,
      parent_id_by_child_id,
      participant_alias_by_abs_id,
    )
    let dst_top = sequence_top_participant_id(
      edge.dst_id_syntax,
      participant_exists,
      parent_id_by_child_id,
      participant_alias_by_abs_id,
    )
    let src_rank = match participant_rank_by_id.get(src_top) {
      Some(v) => v
      None => continue
    }
    let dst_rank = match participant_rank_by_id.get(dst_top) {
      Some(v) => v
      None => continue
    }
    if !sequence_uses_participant_lane(
        edge.src_id_syntax,
        participant_exists,
        participant_alias_by_abs_id,
      ) {
      let src_width = sequence_object_width(
        edge.src_id_syntax,
        patch,
        object_by_abs_id,
        measure_object,
      )
      let first = route[0]
      if src_rank <= dst_rank {
        route[0] = @graph.Point::new(first.x + src_width / 2.0, first.y)
      } else {
        route[0] = @graph.Point::new(first.x - src_width / 2.0, first.y)
      }
    }
    if !sequence_uses_participant_lane(
        edge.dst_id_syntax,
        participant_exists,
        participant_alias_by_abs_id,
      ) {
      let dst_width = sequence_object_width(
        edge.dst_id_syntax,
        patch,
        object_by_abs_id,
        measure_object,
      )
      let last = route.length() - 1
      let last_point = route[last]
      if src_rank < dst_rank {
        route[last] = @graph.Point::new(
          last_point.x - dst_width / 2.0,
          last_point.y,
        )
      } else {
        route[last] = @graph.Point::new(
          last_point.x + dst_width / 2.0,
          last_point.y,
        )
      }
    }
  }

  recompute_edge_label_boxes(patch, graph)
  patch
}

///|
fn sequence_parent_id_by_child_id(
  graph : @graph.GraphInput,
) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  for child_id in graph.root.child_ids {
    out[child_id] = graph.root.abs_id_syntax
  }
  for obj in graph.objects {
    for child_id in obj.child_ids {
      out[child_id] = obj.abs_id_syntax
    }
  }
  for obj in graph.objects {
    match sequence_parent_abs_id_syntax_of(obj.abs_id_syntax) {
      Some(parent_id) =>
        if !out.contains(obj.abs_id_syntax) {
          out[obj.abs_id_syntax] = parent_id
        }
      None => ()
    }
  }
  out
}

///|
fn sequence_parent_abs_id_syntax_of(abs_id_syntax : String) -> String? {
  let segments = @graph.split_syntax_path(abs_id_syntax)
  if segments.length() <= 1 {
    return None
  }
  let parent = StringBuilder()
  for i = 0; i < segments.length() - 1; i = i + 1 {
    if i > 0 {
      parent.write_string(".")
    }
    parent.write_string(segments[i])
  }
  Some(parent.to_string())
}

///|
fn sequence_edges_in_render_order(
  graph : @graph.GraphInput,
) -> Array[@graph.EdgeInput] {
  let out : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    out.push(edge)
  }
  out.sort_by(fn(a, b) {
    let cmp = sequence_edge_earliest_line_like_d2(a).compare(
      sequence_edge_earliest_line_like_d2(b),
    )
    if cmp != 0 {
      cmp
    } else {
      a.index.compare(b.index)
    }
  })
  out
}

///|
fn sequence_participant_alias_by_abs_id(
  graph : @graph.GraphInput,
  participant_ids : Array[String],
  object_by_abs_id : Map[String, @graph.ObjectInput],
) -> Map[String, String] {
  let participant_by_local_id : Map[String, String] = Map([])
  for participant_id in participant_ids {
    match object_by_abs_id.get(participant_id) {
      Some(obj) => {
        participant_by_local_id[obj.id_val] = obj.abs_id_syntax
        participant_by_local_id[obj.id_syntax] = obj.abs_id_syntax
      }
      None => participant_by_local_id[participant_id] = participant_id
    }
  }
  let out : Map[String, String] = Map([])
  for participant_id in participant_ids {
    out[participant_id] = participant_id
  }
  for obj in graph.objects {
    if out.contains(obj.abs_id_syntax) {
      continue
    }
    match participant_by_local_id.get(obj.id_val) {
      Some(participant_id) => out[obj.abs_id_syntax] = participant_id
      None =>
        match participant_by_local_id.get(obj.id_syntax) {
          Some(participant_id) => out[obj.abs_id_syntax] = participant_id
          None => ()
        }
    }
  }
  out
}

///|
fn sequence_uses_participant_lane(
  id : String,
  participant_exists : Map[String, Bool],
  participant_alias_by_abs_id : Map[String, String],
) -> Bool {
  participant_exists.contains(id) || participant_alias_by_abs_id.contains(id)
}

///|
fn sequence_max_note_width_by_participant_id_like_d2(
  graph : @graph.GraphInput,
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  participant_alias_by_abs_id : Map[String, String],
  measure_object : (@graph.ObjectInput) -> (Double, Double),
) -> Map[String, Double] {
  let out : Map[String, Double] = Map([])
  for obj in graph.objects {
    if !sequence_is_note_like_d2(obj, graph) {
      continue
    }
    let participant_id = sequence_top_participant_id(
      obj.abs_id_syntax,
      participant_exists,
      parent_id_by_child_id,
      participant_alias_by_abs_id,
    )
    if !participant_exists.contains(participant_id) {
      continue
    }
    let (width, _) = measure_object(obj)
    if width > out.get_or_default(participant_id, 0.0) {
      out[participant_id] = width
    }
  }
  out
}

///|
fn sequence_actor_size(
  shape_type : @graph.ShapeType,
  width : Double,
  height : Double,
) -> (Double, Double) {
  let mut w = width
  let mut h = height
  if w < D2_SEQUENCE_MIN_ACTOR_WIDTH {
    match shape_type {
      Person | Oval | Square | Circle =>
        if w > 0.0 {
          h = h * D2_SEQUENCE_MIN_ACTOR_WIDTH / w
        }
      _ => ()
    }
    w = D2_SEQUENCE_MIN_ACTOR_WIDTH
  }
  if h < D2_SEQUENCE_MIN_ACTOR_HEIGHT {
    h = D2_SEQUENCE_MIN_ACTOR_HEIGHT
  }
  (w, h)
}

///|
fn sequence_label_height(obj : @graph.ObjectInput) -> Double {
  match obj.label_box {
    Some(box) =>
      if box.height > 0.0 {
        box.height
      } else {
        sequence_measured_label_height(obj)
      }
    None => sequence_measured_label_height(obj)
  }
}

///|
fn sequence_measured_label_height(obj : @graph.ObjectInput) -> Double {
  if obj.label == "" {
    return 0.0
  }
  let font_size = match obj.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = false
  let is_italic = style_bool(obj.style.italic, false)
  let is_mono = style_is_mono(obj.style.font)
  let dims = measure_object_label_dims(
    obj, font_size, is_mono, is_bold, is_italic,
  )
  if dims.height > 0.0 {
    dims.height
  } else {
    font_size.to_double() + 5.0
  }
}

///|
fn sequence_root_label_height(graph : @graph.GraphInput) -> Double {
  if graph.root.label == "" {
    0.0
  } else {
    sequence_label_height(graph.root)
  }
}

///|
fn sequence_center_x_for_object(
  id : String,
  patch : @graph.LayoutPatch,
  parent_id_by_child_id : Map[String, String],
  participant_alias_by_abs_id : Map[String, String],
) -> Double? {
  let mut current = id
  let visited : Map[String, Bool] = Map([])
  while !visited.contains(current) {
    visited[current] = true
    match patch.nodes.get(current) {
      Some(box) => return Some(box.x + box.width / 2.0)
      None => ()
    }
    match participant_alias_by_abs_id.get(current) {
      Some(participant_id) =>
        match patch.nodes.get(participant_id) {
          Some(box) => return Some(box.x + box.width / 2.0)
          None => ()
        }
      None => ()
    }
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => current = parent_id
      None => return None
    }
  }
  None
}

///|
fn sequence_top_participant_id(
  id : String,
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  participant_alias_by_abs_id : Map[String, String],
) -> String {
  if participant_exists.contains(id) {
    return id
  }
  let mut current = id
  let visited : Map[String, Bool] = Map([])
  while !visited.contains(current) {
    visited[current] = true
    match participant_alias_by_abs_id.get(current) {
      Some(participant_id) => return participant_id
      None => ()
    }
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => {
        if participant_exists.contains(parent_id) {
          return parent_id
        }
        current = parent_id
      }
      None => return id
    }
  }
  id
}

///|
fn sequence_edge_text_size(edge : @graph.EdgeInput) -> (Double, Double) {
  let (label_width, label_height) = sequence_edge_label_size(edge)
  if label_width <= 0.0 || label_height <= 0.0 {
    return (0.0, 0.0)
  }
  let width = if label_width > 4.0 { label_width - 4.0 } else { label_width }
  let height = if label_height > 1.0 {
    label_height - 1.0
  } else {
    label_height
  }
  (width, height)
}

///|
fn sequence_object_width(
  id : String,
  patch : @graph.LayoutPatch,
  object_by_abs_id : Map[String, @graph.ObjectInput],
  measure_object : (@graph.ObjectInput) -> (Double, Double),
) -> Double {
  match patch.nodes.get(id) {
    Some(box) => box.width
    None =>
      match object_by_abs_id.get(id) {
        Some(obj) => {
          let (width, _) = measure_object(obj)
          width
        }
        None => D2_SEQUENCE_MIN_ACTOR_WIDTH
      }
  }
}

///|
fn sequence_place_nested_objects_like_d2(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  ordered_edges : Array[@graph.EdgeInput],
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  object_by_abs_id : Map[String, @graph.ObjectInput],
  participant_alias_by_abs_id : Map[String, String],
  measure_object : (@graph.ObjectInput) -> (Double, Double),
  max_actor_height : Double,
  y_step : Double,
) -> Unit {
  let (notes, spans, note_line_by_id) = sequence_collect_notes_and_spans_like_d2(
    graph, participant_exists, parent_id_by_child_id, participant_alias_by_abs_id,
  )
  sequence_place_notes_like_d2(
    patch, notes, ordered_edges, note_line_by_id, participant_exists, parent_id_by_child_id,
    participant_alias_by_abs_id, measure_object, max_actor_height, y_step,
  )
  sequence_place_spans_like_d2(
    patch, spans, ordered_edges, participant_exists, parent_id_by_child_id, participant_alias_by_abs_id,
    max_actor_height, y_step,
  )
  sequence_place_groups_like_d2(
    patch, graph, ordered_edges, parent_id_by_child_id, object_by_abs_id, notes,
    spans,
  )
}

///|
fn sequence_collect_notes_and_spans_like_d2(
  graph : @graph.GraphInput,
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  participant_alias_by_abs_id : Map[String, String],
) -> (Array[@graph.ObjectInput], Array[@graph.ObjectInput], Map[String, Int]) {
  let notes : Array[@graph.ObjectInput] = []
  let spans : Array[@graph.ObjectInput] = []
  let note_line_by_id : Map[String, Int] = Map([])
  for obj in graph.objects {
    if participant_exists.contains(obj.abs_id_syntax) ||
      participant_alias_by_abs_id.contains(obj.abs_id_syntax) ||
      sequence_is_group_like_d2(obj, graph) {
      continue
    }
    let participant_id = sequence_top_participant_id(
      obj.abs_id_syntax,
      participant_exists,
      parent_id_by_child_id,
      participant_alias_by_abs_id,
    )
    if !participant_exists.contains(participant_id) {
      continue
    }
    if sequence_is_note_like_d2(obj, graph) {
      notes.push(obj)
      note_line_by_id[obj.abs_id_syntax] = sequence_object_earliest_line_like_d2(
        obj,
      )
    } else {
      spans.push(obj)
    }
  }
  notes.sort_by(fn(a, b) {
    sequence_object_earliest_line_like_d2(a).compare(
      sequence_object_earliest_line_like_d2(b),
    )
  })
  spans.sort_by(fn(a, b) {
    sequence_object_earliest_line_like_d2(a).compare(
      sequence_object_earliest_line_like_d2(b),
    )
  })
  (notes, spans, note_line_by_id)
}

///|
fn sequence_place_notes_like_d2(
  patch : @graph.LayoutPatch,
  notes : Array[@graph.ObjectInput],
  ordered_edges : Array[@graph.EdgeInput],
  note_line_by_id : Map[String, Int],
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  participant_alias_by_abs_id : Map[String, String],
  measure_object : (@graph.ObjectInput) -> (Double, Double),
  max_actor_height : Double,
  y_step : Double,
) -> Unit {
  for note in notes {
    let vertical_index = note_line_by_id.get_or_default(
      note.abs_id_syntax,
      sequence_object_earliest_line_like_d2(note),
    )
    let mut y = max_actor_height + y_step + D2_SEQUENCE_GROUP_CONTAINER_PADDING
    for edge in ordered_edges {
      if sequence_edge_earliest_line_like_d2(edge) >= vertical_index {
        continue
      }
      let (_, text_height) = sequence_edge_text_size(edge)
      let extra = if sequence_message_has_vertical_turn_like_d2(
          edge, participant_exists, parent_id_by_child_id, participant_alias_by_abs_id,
        ) {
        if text_height > D2_SEQUENCE_MIN_MESSAGE_DISTANCE {
          text_height * 1.5
        } else {
          D2_SEQUENCE_MIN_MESSAGE_DISTANCE * 1.5
        }
      } else {
        text_height
      }
      y = y + extra + y_step
    }
    for other_note in notes {
      if other_note.abs_id_syntax == note.abs_id_syntax {
        continue
      }
      if note_line_by_id.get_or_default(
          other_note.abs_id_syntax,
          sequence_object_earliest_line_like_d2(other_note),
        ) >=
        vertical_index {
        continue
      }
      let (_, note_height) = sequence_note_size_like_d2(
        other_note, measure_object,
      )
      y = y + note_height + y_step
    }
    let center_x = match
      sequence_center_x_for_object(
        note.abs_id_syntax,
        patch,
        parent_id_by_child_id,
        participant_alias_by_abs_id,
      ) {
      Some(value) => value
      None => continue
    }
    let (width, height) = sequence_note_size_like_d2(note, measure_object)
    let note_box = @graph.Box::new(center_x - width / 2.0, y, width, height)
    patch.nodes[note.abs_id_syntax] = note_box
    patch.sequence_notes.push((note.abs_id_syntax, note.label, note_box))
  }
}

///|
fn sequence_note_size_like_d2(
  note : @graph.ObjectInput,
  measure_object : (@graph.ObjectInput) -> (Double, Double),
) -> (Double, Double) {
  let (width, measured_height) = measure_object(note)
  let font_size = match note.style.font_size {
    Some(value) => value.as_int().unwrap_or(16)
    None => 16
  }
  let outside_label_line_height = font_size.to_double() + 5.0
  let height = if measured_height > outside_label_line_height {
    measured_height - outside_label_line_height
  } else {
    measured_height
  }
  (width, height)
}

///|
fn sequence_place_spans_like_d2(
  patch : @graph.LayoutPatch,
  spans : Array[@graph.ObjectInput],
  ordered_edges : Array[@graph.EdgeInput],
  _participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  participant_alias_by_abs_id : Map[String, String],
  _max_actor_height : Double,
  _y_step : Double,
) -> Unit {
  let first_message_by_id : Map[String, @graph.EdgeInput] = Map([])
  let last_message_by_id : Map[String, @graph.EdgeInput] = Map([])
  for edge in ordered_edges {
    if !first_message_by_id.contains(edge.src_id_syntax) {
      first_message_by_id[edge.src_id_syntax] = edge
    }
    if !first_message_by_id.contains(edge.dst_id_syntax) {
      first_message_by_id[edge.dst_id_syntax] = edge
    }
    last_message_by_id[edge.src_id_syntax] = edge
    last_message_by_id[edge.dst_id_syntax] = edge
  }

  let sorted_spans = sequence_sort_spans_most_nested(
    spans, parent_id_by_child_id,
  )
  for span in sorted_spans {
    let mut min_child_y = 1000000000.0
    let mut max_child_y = -1000000000.0
    let mut saw_child = false
    for child_id in span.child_ids {
      match patch.nodes.get(child_id) {
        Some(box) => {
          saw_child = true
          if box.y < min_child_y {
            min_child_y = box.y
          }
          if box.y + box.height > max_child_y {
            max_child_y = box.y + box.height
          }
        }
        None => ()
      }
    }

    let mut min_message_y = 1000000000.0
    match first_message_by_id.get(span.abs_id_syntax) {
      Some(first_message) =>
        match patch.edges.get(first_message.index) {
          Some(route) if !route.is_empty() =>
            if first_message.src_id_syntax == first_message.dst_id_syntax ||
              first_message.src_id_syntax == span.abs_id_syntax {
              min_message_y = route[0].y
            } else {
              min_message_y = route[route.length() - 1].y
            }
          _ => ()
        }
      None => ()
    }

    let mut max_message_y = -1000000000.0
    match last_message_by_id.get(span.abs_id_syntax) {
      Some(last_message) =>
        match patch.edges.get(last_message.index) {
          Some(route) if !route.is_empty() =>
            if last_message.src_id_syntax == last_message.dst_id_syntax ||
              last_message.dst_id_syntax == span.abs_id_syntax {
              max_message_y = route[route.length() - 1].y
            } else {
              max_message_y = route[0].y
            }
          _ => ()
        }
      None => ()
    }

    let min_y = if saw_child || min_message_y < 1000000000.0 {
      if min_child_y < min_message_y {
        min_child_y
      } else {
        min_message_y
      }
    } else {
      continue
    }
    let max_y = if saw_child || max_message_y > -1000000000.0 {
      if max_child_y > max_message_y {
        max_child_y
      } else {
        max_message_y
      }
    } else {
      continue
    }

    let mut padded_min_y = min_y
    if approx_eq(min_y, min_child_y) || approx_eq(min_y, min_message_y) {
      padded_min_y = padded_min_y - D2_SEQUENCE_SPAN_MESSAGE_PAD
    }
    let mut padded_max_y = max_y
    if approx_eq(max_y, max_child_y) || approx_eq(max_y, max_message_y) {
      padded_max_y = padded_max_y + D2_SEQUENCE_SPAN_MESSAGE_PAD
    }

    let mut height = padded_max_y - padded_min_y
    if height < D2_SEQUENCE_MIN_SPAN_HEIGHT {
      height = D2_SEQUENCE_MIN_SPAN_HEIGHT
    }
    let width = D2_SEQUENCE_SPAN_BASE_WIDTH +
      sequence_span_depth_like_d2(span, parent_id_by_child_id).to_double() *
      D2_SEQUENCE_SPAN_DEPTH_GROWTH
    let center_x = match
      sequence_center_x_for_object(
        span.abs_id_syntax,
        patch,
        parent_id_by_child_id,
        participant_alias_by_abs_id,
      ) {
      Some(value) => value
      None => continue
    }
    let span_box = @graph.Box::new(
      center_x - width / 2.0,
      padded_min_y,
      width,
      height,
    )
    patch.nodes[span.abs_id_syntax] = span_box
    patch.activation_boxes.push((span.abs_id_syntax, span_box))
  }
}

///|
fn sequence_place_groups_like_d2(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
  ordered_edges : Array[@graph.EdgeInput],
  parent_id_by_child_id : Map[String, String],
  object_by_abs_id : Map[String, @graph.ObjectInput],
  notes : Array[@graph.ObjectInput],
  spans : Array[@graph.ObjectInput],
) -> Unit {
  let groups = sequence_group_objects_like_d2(
    graph, object_by_abs_id, parent_id_by_child_id,
  )
  if groups.is_empty() {
    return
  }
  let group_ids : Map[String, Bool] = Map([])
  for group in groups {
    group_ids[group.abs_id_syntax] = true
  }
  let groups_most_nested : Array[@graph.ObjectInput] = []
  for group in groups {
    groups_most_nested.push(group)
  }
  groups_most_nested.sort_by(fn(a, b) {
    sequence_object_depth_like_d2(b.abs_id_syntax, parent_id_by_child_id).compare(
      sequence_object_depth_like_d2(a.abs_id_syntax, parent_id_by_child_id),
    )
  })

  for group in groups_most_nested {
    let mut min_x = 1.0e15
    let mut min_y = 1.0e15
    let mut max_x = -1.0e15
    let mut max_y = -1.0e15
    let mut saw_content = false

    for edge in ordered_edges {
      if !sequence_edge_contained_by_like_d2(edge, group.abs_id_syntax) {
        continue
      }
      let route = match patch.edges.get(edge.index) {
        Some(route) => route
        None => continue
      }
      if route.is_empty() {
        continue
      }
      saw_content = true
      // D2's routing uses a compacted message height, but group bounds are
      // expanded around the rendered label box itself.
      let (_, text_height) = sequence_edge_label_size(edge)
      let label_height = text_height / 2.0
      let edge_pad = if label_height + D2_SEQUENCE_GROUP_CONTAINER_PADDING >
        D2_SEQUENCE_MIN_MESSAGE_DISTANCE / 2.0 {
        label_height + D2_SEQUENCE_GROUP_CONTAINER_PADDING
      } else {
        D2_SEQUENCE_MIN_MESSAGE_DISTANCE / 2.0
      }
      for point in route {
        if point.x - D2_SEQUENCE_HORIZONTAL_PAD < min_x {
          min_x = point.x - D2_SEQUENCE_HORIZONTAL_PAD
        }
        if point.y - edge_pad < min_y {
          min_y = point.y - edge_pad
        }
        if point.x + D2_SEQUENCE_HORIZONTAL_PAD > max_x {
          max_x = point.x + D2_SEQUENCE_HORIZONTAL_PAD
        }
        if point.y + edge_pad > max_y {
          max_y = point.y + edge_pad
        }
      }
    }

    for note in notes {
      if !sequence_object_contained_by_like_d2(note, group.abs_id_syntax) {
        continue
      }
      let box = match patch.nodes.get(note.abs_id_syntax) {
        Some(box) => box
        None => continue
      }
      saw_content = true
      if box.x - D2_SEQUENCE_HORIZONTAL_PAD < min_x {
        min_x = box.x - D2_SEQUENCE_HORIZONTAL_PAD
      }
      if box.y - D2_SEQUENCE_MIN_MESSAGE_DISTANCE / 2.0 < min_y {
        min_y = box.y - D2_SEQUENCE_MIN_MESSAGE_DISTANCE / 2.0
      }
      if box.x + box.width + D2_SEQUENCE_HORIZONTAL_PAD > max_x {
        max_x = box.x + box.width + D2_SEQUENCE_HORIZONTAL_PAD
      }
      if box.y + box.height + D2_SEQUENCE_MIN_MESSAGE_DISTANCE / 2.0 > max_y {
        max_y = box.y + box.height + D2_SEQUENCE_MIN_MESSAGE_DISTANCE / 2.0
      }
    }

    for child_id in group.child_ids {
      if !group_ids.contains(child_id) {
        continue
      }
      let child_box = match patch.nodes.get(child_id) {
        Some(box) => box
        None => continue
      }
      saw_content = true
      if child_box.x - D2_SEQUENCE_GROUP_CONTAINER_PADDING < min_x {
        min_x = child_box.x - D2_SEQUENCE_GROUP_CONTAINER_PADDING
      }
      if child_box.y - D2_SEQUENCE_GROUP_CONTAINER_PADDING < min_y {
        min_y = child_box.y - D2_SEQUENCE_GROUP_CONTAINER_PADDING
      }
      if child_box.x + child_box.width + D2_SEQUENCE_GROUP_CONTAINER_PADDING >
        max_x {
        max_x = child_box.x +
          child_box.width +
          D2_SEQUENCE_GROUP_CONTAINER_PADDING
      }
      if child_box.y + child_box.height + D2_SEQUENCE_GROUP_CONTAINER_PADDING >
        max_y {
        max_y = child_box.y +
          child_box.height +
          D2_SEQUENCE_GROUP_CONTAINER_PADDING
      }
    }

    if saw_content {
      patch.nodes[group.abs_id_syntax] = @graph.Box::new(
        min_x,
        min_y,
        max_x - min_x,
        max_y - min_y,
      )
    }
  }

  for group in groups {
    sequence_adjust_group_label_like_d2(
      patch, group, groups, spans, notes, ordered_edges,
    )
  }
}

///|
fn sequence_adjust_group_label_like_d2(
  patch : @graph.LayoutPatch,
  group : @graph.ObjectInput,
  groups : Array[@graph.ObjectInput],
  spans : Array[@graph.ObjectInput],
  notes : Array[@graph.ObjectInput],
  ordered_edges : Array[@graph.EdgeInput],
) -> Unit {
  if group.label == "" {
    return
  }
  let group_box = match patch.nodes.get(group.abs_id_syntax) {
    Some(box) => box
    None => return
  }
  let label_height = sequence_label_height(group)
  let height_add = label_height + D2_SEQUENCE_EDGE_GROUP_LABEL_PADDING / 2.0
  if height_add < D2_SEQUENCE_GROUP_CONTAINER_PADDING {
    return
  }

  patch.nodes[group.abs_id_syntax] = @graph.Box::new(
    group_box.x,
    group_box.y,
    group_box.width,
    group_box.height + height_add,
  )

  for other_group in groups {
    if other_group.abs_id_syntax == group.abs_id_syntax {
      continue
    }
    match patch.nodes.get(other_group.abs_id_syntax) {
      Some(box) =>
        if box.y < group_box.y && box.y + box.height > group_box.y {
          patch.nodes[other_group.abs_id_syntax] = @graph.Box::new(
            box.x,
            box.y,
            box.width,
            box.height + height_add,
          )
        }
      None => ()
    }
  }
  for span in spans {
    match patch.nodes.get(span.abs_id_syntax) {
      Some(box) =>
        if box.y < group_box.y && box.y + box.height > group_box.y {
          patch.nodes[span.abs_id_syntax] = @graph.Box::new(
            box.x,
            box.y,
            box.width,
            box.height + height_add,
          )
        }
      None => ()
    }
  }

  for edge in ordered_edges {
    let route = match patch.edges.get(edge.index) {
      Some(route) => route
      None => continue
    }
    if route.is_empty() {
      continue
    }
    let start_y = route[0].y
    let end_y = route[route.length() - 1].y
    let min_y = if start_y < end_y { start_y } else { end_y }
    if min_y > group_box.y {
      for i = 0; i < route.length(); i = i + 1 {
        route[i] = @graph.Point::new(route[i].x, route[i].y + height_add)
      }
    }
  }

  for span in spans {
    match patch.nodes.get(span.abs_id_syntax) {
      Some(box) =>
        if box.y > group_box.y {
          patch.nodes[span.abs_id_syntax] = @graph.Box::new(
            box.x,
            box.y + height_add,
            box.width,
            box.height,
          )
        }
      None => ()
    }
  }
  for other_group in groups {
    if other_group.abs_id_syntax == group.abs_id_syntax {
      continue
    }
    match patch.nodes.get(other_group.abs_id_syntax) {
      Some(box) =>
        if box.y > group_box.y {
          patch.nodes[other_group.abs_id_syntax] = @graph.Box::new(
            box.x,
            box.y + height_add,
            box.width,
            box.height,
          )
        }
      None => ()
    }
  }
  for note in notes {
    match patch.nodes.get(note.abs_id_syntax) {
      Some(box) =>
        if box.y > group_box.y {
          patch.nodes[note.abs_id_syntax] = @graph.Box::new(
            box.x,
            box.y + height_add,
            box.width,
            box.height,
          )
        }
      None => ()
    }
  }
}

///|
fn sequence_group_objects_like_d2(
  graph : @graph.GraphInput,
  object_by_abs_id : Map[String, @graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> Array[@graph.ObjectInput] {
  let groups : Array[@graph.ObjectInput] = []
  let participant_ids : Map[String, Bool] = Map([])
  let participant_id_list = sequence_participant_ids(graph)
  for participant_id in participant_id_list {
    participant_ids[participant_id] = true
  }
  let participant_aliases = sequence_participant_alias_by_abs_id(
    graph, participant_id_list, object_by_abs_id,
  )
  for obj in graph.objects {
    if participant_ids.contains(obj.abs_id_syntax) ||
      participant_aliases.contains(obj.abs_id_syntax) {
      continue
    }
    if sequence_is_group_like_d2(obj, graph) {
      groups.push(obj)
    }
  }
  groups.sort_by(fn(a, b) {
    let cmp = sequence_object_earliest_line_like_d2(a).compare(
      sequence_object_earliest_line_like_d2(b),
    )
    if cmp != 0 {
      cmp
    } else {
      sequence_object_depth_like_d2(a.abs_id_syntax, parent_id_by_child_id).compare(
        sequence_object_depth_like_d2(b.abs_id_syntax, parent_id_by_child_id),
      )
    }
  })
  groups
}

///|
fn sequence_sort_spans_most_nested(
  spans : Array[@graph.ObjectInput],
  parent_id_by_child_id : Map[String, String],
) -> Array[@graph.ObjectInput] {
  let sorted : Array[@graph.ObjectInput] = []
  for span in spans {
    sorted.push(span)
  }
  for i in 0..<sorted.length() {
    for j in (i + 1)..<sorted.length() {
      if sequence_span_depth_like_d2(sorted[j], parent_id_by_child_id) >
        sequence_span_depth_like_d2(sorted[i], parent_id_by_child_id) {
        let tmp = sorted[i]
        sorted[i] = sorted[j]
        sorted[j] = tmp
      }
    }
  }
  sorted
}

///|
fn sequence_span_depth_like_d2(
  span : @graph.ObjectInput,
  parent_id_by_child_id : Map[String, String],
) -> Int {
  let mut depth = 0
  let mut current = span.abs_id_syntax
  while true {
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => {
        depth += 1
        current = parent_id
      }
      None => break
    }
  }
  if depth > 2 {
    depth - 2
  } else {
    0
  }
}

///|
fn sequence_message_has_vertical_turn_like_d2(
  edge : @graph.EdgeInput,
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  participant_alias_by_abs_id : Map[String, String],
) -> Bool {
  let src_top = sequence_top_participant_id(
    edge.src_id_syntax,
    participant_exists,
    parent_id_by_child_id,
    participant_alias_by_abs_id,
  )
  let dst_top = sequence_top_participant_id(
    edge.dst_id_syntax,
    participant_exists,
    parent_id_by_child_id,
    participant_alias_by_abs_id,
  )
  edge.src_id_syntax == edge.dst_id_syntax ||
  is_descendant_of(
    edge.dst_id_syntax,
    edge.src_id_syntax,
    parent_id_by_child_id,
  ) ||
  is_descendant_of(
    edge.src_id_syntax,
    edge.dst_id_syntax,
    parent_id_by_child_id,
  ) ||
  src_top == dst_top
}

///|
fn sequence_note_vertical_offset_before_edge_like_d2(
  edge : @graph.EdgeInput,
  notes : Array[@graph.ObjectInput],
  note_line_by_id : Map[String, Int],
  note_height_by_id : Map[String, Double],
  y_step : Double,
) -> Double {
  let edge_line = sequence_edge_earliest_line_like_d2(edge)
  let mut offset = 0.0
  for note in notes {
    if note_line_by_id.get_or_default(
        note.abs_id_syntax,
        sequence_object_earliest_line_like_d2(note),
      ) <
      edge_line {
      offset = offset +
        note_height_by_id.get_or_default(note.abs_id_syntax, 0.0) +
        y_step
    }
  }
  offset
}

///|
fn sequence_is_note_like_d2(
  obj : @graph.ObjectInput,
  graph : @graph.GraphInput,
) -> Bool {
  sequence_object_has_non_edge_reference_like_d2(obj) &&
  !sequence_object_has_incident_edge_like_d2(obj, graph) &&
  !sequence_object_contains_any_edge_like_d2(obj, graph) &&
  obj.child_ids.is_empty() &&
  !sequence_object_contains_any_object_like_d2(obj, graph)
}

///|
fn sequence_is_group_like_d2(
  obj : @graph.ObjectInput,
  graph : @graph.GraphInput,
) -> Bool {
  (
    sequence_object_has_non_edge_reference_like_d2(obj) &&
    !sequence_object_has_incident_edge_like_d2(obj, graph) &&
    sequence_object_contains_any_object_like_d2(obj, graph)
  ) ||
  (
    sequence_object_has_non_edge_reference_like_d2(obj) &&
    !sequence_object_has_incident_edge_like_d2(obj, graph) &&
    sequence_object_contains_any_edge_like_d2(obj, graph)
  )
}

///|
fn sequence_object_contained_by_like_d2(
  obj : @graph.ObjectInput,
  abs_id_syntax : String,
) -> Bool {
  for reference in obj.references {
    if reference.contained_by(abs_id_syntax) {
      return true
    }
  }
  false
}

///|
fn sequence_object_has_incident_edge_like_d2(
  obj : @graph.ObjectInput,
  graph : @graph.GraphInput,
) -> Bool {
  for edge in graph.edges {
    if edge.src_id_syntax == obj.abs_id_syntax ||
      edge.dst_id_syntax == obj.abs_id_syntax ||
      edge.src_id == obj.id ||
      edge.dst_id == obj.id {
      return true
    }
  }
  false
}

///|
fn sequence_object_has_non_edge_reference_like_d2(
  obj : @graph.ObjectInput,
) -> Bool {
  for reference in obj.references {
    if !reference.in_edge &&
      !reference.due_to_glob &&
      !reference.due_to_lazy_glob {
      return true
    }
  }
  false
}

///|
fn sequence_object_contains_any_object_like_d2(
  obj : @graph.ObjectInput,
  graph : @graph.GraphInput,
) -> Bool {
  for other in graph.objects {
    if other.abs_id_syntax != obj.abs_id_syntax &&
      sequence_object_contained_by_like_d2(other, obj.abs_id_syntax) {
      return true
    }
  }
  false
}

///|
fn sequence_object_contains_any_edge_like_d2(
  obj : @graph.ObjectInput,
  graph : @graph.GraphInput,
) -> Bool {
  for edge in graph.edges {
    if sequence_edge_contained_by_like_d2(edge, obj.abs_id_syntax) {
      return true
    }
  }
  false
}

///|
fn sequence_edge_contained_by_like_d2(
  edge : @graph.EdgeInput,
  abs_id_syntax : String,
) -> Bool {
  for reference in edge.references {
    if reference.contained_by(abs_id_syntax) {
      return true
    }
  }
  false
}

///|
fn sequence_object_depth_like_d2(
  abs_id_syntax : String,
  parent_id_by_child_id : Map[String, String],
) -> Int {
  let mut depth = 0
  let mut current = abs_id_syntax
  while true {
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => {
        depth += 1
        current = parent_id
      }
      None => break
    }
  }
  depth
}

///|
fn sequence_object_earliest_line_like_d2(obj : @graph.ObjectInput) -> Int {
  let mut min_line = 1073741824
  for reference in obj.references {
    if reference.due_to_glob || reference.due_to_lazy_glob {
      continue
    }
    if reference.range.start.line < min_line {
      min_line = reference.range.start.line
    }
  }
  min_line
}

///|
fn sequence_edge_earliest_line_like_d2(edge : @graph.EdgeInput) -> Int {
  let mut min_line = 1073741824
  for reference in edge.references {
    if reference.due_to_glob || reference.due_to_lazy_glob {
      continue
    }
    if reference.range.start.line < min_line {
      min_line = reference.range.start.line
    }
  }
  min_line
}

///|
fn sequence_participant_ids(graph : @graph.GraphInput) -> Array[String] {
  let object_by_abs_id : Map[String, @graph.ObjectInput] = Map([])
  for obj in graph.objects {
    object_by_abs_id[obj.abs_id_syntax] = obj
  }
  if !graph.root.child_ids.is_empty() {
    let ids : Array[String] = []
    let root_children : Array[@graph.ObjectInput] = []
    for child_id in graph.root.child_ids {
      match graph.find_object(child_id) {
        Some(obj) => root_children.push(obj)
        None => ()
      }
    }
    root_children.sort_by(fn(a, b) {
      sequence_object_earliest_line_like_d2(a).compare(
        sequence_object_earliest_line_like_d2(b),
      )
    })
    for obj in root_children {
      let has_non_edge_ref = sequence_object_has_non_edge_reference_like_d2(obj)
      let contains_any_edge = sequence_object_contains_any_edge_like_d2(
        obj, graph,
      )
      let has_incident_edge = sequence_object_has_incident_edge_like_d2(
        obj, graph,
      )
      let has_descendant_endpoint = sequence_has_descendant_endpoint_like_d2(
        obj, graph,
      )
      let children_are_only_notes = sequence_children_are_only_notes(
        obj, object_by_abs_id,
      )
      let is_explicit_actor = has_non_edge_ref &&
        (
          (
            !contains_any_edge &&
            (obj.child_ids.is_empty() || children_are_only_notes)
          ) ||
          has_incident_edge ||
          (has_descendant_endpoint && !contains_any_edge)
        )
      let is_implicit_actor = !has_non_edge_ref &&
        (has_incident_edge || has_descendant_endpoint)
      if is_explicit_actor || is_implicit_actor {
        ids.push(obj.abs_id_syntax)
      }
    }
    if !ids.is_empty() {
      return ids
    }
  }
  let child_ids : Map[String, Bool] = Map([])
  for obj in graph.objects {
    for child_id in obj.child_ids {
      child_ids[child_id] = true
    }
  }
  let ids : Array[String] = []
  for obj in graph.objects {
    if !child_ids.contains(obj.abs_id_syntax) {
      ids.push(obj.abs_id_syntax)
    }
  }
  ids
}

///|
fn sequence_children_are_only_notes(
  obj : @graph.ObjectInput,
  object_by_abs_id : Map[String, @graph.ObjectInput],
) -> Bool {
  if obj.child_ids.is_empty() {
    return false
  }
  for child_id in obj.child_ids {
    match object_by_abs_id.get(child_id) {
      Some(child) =>
        if !child.classes.contains("__diago_sequence_note") {
          return false
        }
      None => return false
    }
  }
  true
}

///|
fn sequence_has_descendant_endpoint_like_d2(
  obj : @graph.ObjectInput,
  graph : @graph.GraphInput,
) -> Bool {
  let prefix = obj.abs_id_syntax + "."
  for edge in graph.edges {
    if edge.src_id_syntax.has_prefix(prefix) ||
      edge.dst_id_syntax.has_prefix(prefix) {
      return true
    }
  }
  false
}

///|
fn sequence_edge_label_size(edge : @graph.EdgeInput) -> (Double, Double) {
  match edge.label_box {
    Some(box) =>
      if box.width > 0.0 && box.height > 0.0 {
        (box.width, box.height)
      } else {
        fallback_sequence_edge_label_size(edge)
      }
    None => fallback_sequence_edge_label_size(edge)
  }
}

///|
fn fallback_sequence_edge_label_size(
  edge : @graph.EdgeInput,
) -> (Double, Double) {
  if edge.label.is_empty() {
    return (0.0, 0.0)
  }
  let font_size = match edge.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(edge.style.bold, false)
  let is_italic = style_bool(edge.style.italic, true)
  let is_mono = style_is_mono(edge.style.font)
  let dims = @text_metrics.measure_label(
    edge.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  let width = if dims.width > 0.0 {
    dims.width + 4.0
  } else {
    edge.label.length().to_double() * 7.0 + 12.0
  }
  let text_height = if dims.height > 0.0 {
    dims.height
  } else {
    font_size.to_double() + 5.0
  }
  let min_height = font_size.to_double() + 5.0
  let height = if text_height < min_height { min_height } else { text_height }
  (width, height)
}

///|
fn is_descendant_of(
  obj_id : String,
  ancestor_id : String,
  parent_id_by_child_id : Map[String, String],
) -> Bool {
  let mut current = obj_id
  while true {
    if current == ancestor_id {
      return true
    }
    match parent_id_by_child_id.get(current) {
      Some(parent_id) => current = parent_id
      None => break
    }
  }
  false
}

///|
fn approx_eq(a : Double, b : Double) -> Bool {
  (a - b).abs() < 0.000001
}

///|
fn has_outside_bottom_label(shape_type : @graph.ShapeType) -> Bool {
  shape_type == Person || shape_type == Image
}

///|
fn style_bool(value : @graph.StyleValue?, default : Bool) -> Bool {
  match value {
    Some(v) => v.as_bool().unwrap_or(default)
    None => default
  }
}

///|
fn style_is_mono(value : @graph.StyleValue?) -> Bool {
  match value {
    Some(v) =>
      match v.get_value().to_lower() {
        "mono" | "monospace" | "code" => true
        _ => false
      }
    None => false
  }
}

///|
fn object_is_markdown(obj : @graph.ObjectInput) -> Bool {
  match obj.language {
    Some(language) => language == "markdown"
    None => false
  }
}

///|
fn measure_object_label_dims(
  obj : @graph.ObjectInput,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> @text_metrics.TextDimensions {
  if obj.shape_type == Code {
    return @text_metrics.measure_label_code(
      obj.label,
      font_size,
      is_bold,
      is_italic,
    )
  }
  if object_is_markdown(obj) {
    return @text_metrics.measure_label_markdown(obj.label, font_size)
  }
  @text_metrics.measure_label(obj.label, font_size, is_mono, is_bold, is_italic)
}

///|
fn recompute_edge_label_boxes(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  for edge in graph.edges {
    if edge.label == "" {
      continue
    }
    let route = match patch.edges.get(edge.index) {
      Some(v) => v
      None => continue
    }
    if route.is_empty() {
      continue
    }
    let (width, height) = match rendered_edge_label_size(edge) {
      Some(v) => v
      None => continue
    }
    let center = d2_target_route_point_at_percent(route, 0.5)
    patch.edge_labels[edge.index] = @graph.Box::new(
      d2_chop_precision(center.x - width / 2.0),
      d2_chop_precision(center.y - height / 2.0),
      width,
      height,
    )
  }
}

///|
fn d2_chop_precision(value : Double) -> Double {
  let rounded = (Float::from_double(value * 10000.0).to_double() / 10000.0).round()
  if rounded == 0.0 {
    0.0
  } else {
    rounded
  }
}

///|
fn rendered_edge_label_size(edge : @graph.EdgeInput) -> (Double, Double)? {
  match edge.label_box {
    Some(box) => {
      let width = if box.width > 0.0 { box.width } else { 0.0 }
      let height = if box.height > 0.0 { box.height } else { 0.0 }
      if width > 0.0 && height > 0.0 {
        Some((width, height))
      } else {
        fallback_rendered_edge_label_size(edge)
      }
    }
    None => fallback_rendered_edge_label_size(edge)
  }
}

///|
fn fallback_rendered_edge_label_size(
  edge : @graph.EdgeInput,
) -> (Double, Double)? {
  if edge.label.is_empty() {
    return None
  }
  let font_size = match edge.style.font_size {
    Some(v) => v.as_int().unwrap_or(16)
    None => 16
  }
  let is_bold = style_bool(edge.style.bold, false)
  let is_italic = style_bool(edge.style.italic, true)
  let is_mono = style_is_mono(edge.style.font)
  let dims = @text_metrics.measure_label(
    edge.label,
    font_size,
    is_mono,
    is_bold,
    is_italic,
  )
  let width = if dims.width > 0.0 {
    dims.width
  } else {
    edge.label.length().to_double() * 7.0
  }
  let height = if dims.height > 0.0 {
    dims.height
  } else {
    font_size.to_double() + 5.0
  }
  Some((width, height))
}

///|
fn route_point_at_percent(
  route : Array[@graph.Point],
  percent : Double,
) -> @graph.Point {
  if route.is_empty() {
    return @graph.Point::new(0.0, 0.0)
  }
  if route.length() == 1 {
    return route[0]
  }
  let clamped = if percent < 0.0 {
    0.0
  } else if percent > 1.0 {
    1.0
  } else {
    percent
  }
  let total = route_total_length(route)
  if total <= 0.000001 {
    return route[0]
  }
  let target = total * clamped
  let mut walked = 0.0
  for i in 1..<route.length() {
    let p0 = route[i - 1]
    let p1 = route[i]
    let segment = point_distance(p0, p1)
    if segment <= 0.000001 {
      continue
    }
    if walked + segment >= target {
      let t = (target - walked) / segment
      return @graph.Point::new(
        p0.x + (p1.x - p0.x) * t,
        p0.y + (p1.y - p0.y) * t,
      )
    }
    walked = walked + segment
  }
  route[route.length() - 1]
}

///|
fn d2_target_route_point_at_percent(
  route : Array[@graph.Point],
  percent : Double,
) -> @graph.Point {
  let target_route : Array[@graph.Point] = []
  for point in route {
    target_route.push(
      @graph.Point::new(
        Float::from_double((point.x * 1000.0).to_int().to_double() / 1000.0).to_double(),
        Float::from_double((point.y * 1000.0).to_int().to_double() / 1000.0).to_double(),
      ),
    )
  }
  route_point_at_percent(target_route, percent)
}

///|
fn route_total_length(route : Array[@graph.Point]) -> Double {
  let mut total = 0.0
  for i in 1..<route.length() {
    total = total + point_distance(route[i - 1], route[i])
  }
  total
}

///|
fn point_distance(a : @graph.Point, b : @graph.Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  (dx * dx + dy * dy).sqrt()
}

///|
fn copy_passthrough_layout_data(
  patch : @graph.LayoutPatch,
  graph : @graph.GraphInput,
) -> Unit {
  for ab in graph.activation_boxes {
    patch.activation_boxes.push(ab)
  }
  for note in graph.sequence_notes {
    patch.sequence_notes.push(note)
  }
  for fragment in graph.sequence_fragments_layout {
    patch.sequence_fragments.push(fragment)
  }
}
