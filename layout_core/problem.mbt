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
/// A graph or layout result violated the layout-core identity contract.
pub(all) suberror LayoutProblemError {
  DuplicateObjectId(String)
  DuplicateEdgeIndex(Int)
  MissingChild(parent_id~ : String, child_id~ : String)
  MissingEdgeEndpoint(edge_index~ : Int, endpoint_id~ : String)
  UnknownPatchNode(String)
  UnknownPatchEdge(Int)
} derive(Eq, Debug)

///|
pub fn LayoutProblemError::message(self : LayoutProblemError) -> String {
  match self {
    DuplicateObjectId(id) => "duplicate layout object identity: \{id}"
    DuplicateEdgeIndex(index) => "duplicate layout edge index: \{index}"
    MissingChild(parent_id~, child_id~) =>
      "layout child \"\{child_id}\" referenced by \"\{parent_id}\" does not exist"
    MissingEdgeEndpoint(edge_index~, endpoint_id~) =>
      "layout edge \{edge_index} references missing endpoint \"\{endpoint_id}\""
    UnknownPatchNode(id) =>
      "layout patch contains unknown object identity: \{id}"
    UnknownPatchEdge(index) =>
      "layout patch contains unknown edge index: \{index}"
  }
}

///|
/// A validated graph prepared for a layout engine.
///
/// Object and edge lookup fields use canonical absolute source syntax. Internal
/// identity indexes are retained so engine results can be validated through the
/// same interface.
pub struct LayoutProblem {
  priv graph : @graph.GraphInput
  priv object_ids : Map[String, Bool]
  priv edge_indices : Map[Int, Bool]
}

///|
/// Compile a graph into the canonical layout identity model.
pub fn compile(
  graph : @graph.GraphInput,
) -> LayoutProblem raise LayoutProblemError {
  let object_ids : Map[String, Bool] = Map([])
  register_object_id(object_ids, graph.root.abs_id_syntax)
  for obj in graph.objects {
    register_object_id(object_ids, obj.abs_id_syntax)
  }
  validate_children(graph, object_ids)
  let edge_indices : Map[Int, Bool] = Map([])
  for edge in graph.edges {
    if edge_indices.contains(edge.index) {
      raise DuplicateEdgeIndex(edge.index)
    }
    edge_indices[edge.index] = true
    let src_id = edge.lookup_src_id()
    let dst_id = edge.lookup_dst_id()
    if !object_ids.contains(src_id) {
      raise MissingEdgeEndpoint(edge_index=edge.index, endpoint_id=src_id)
    }
    if !object_ids.contains(dst_id) {
      raise MissingEdgeEndpoint(edge_index=edge.index, endpoint_id=dst_id)
    }
  }
  { graph: canonicalize_graph(graph), object_ids, edge_indices }
}

///|
/// Return the canonical graph consumed by layout-engine adapters.
pub fn LayoutProblem::graph(self : LayoutProblem) -> @graph.GraphInput {
  self.graph
}

///|
/// Validate that a patch only refers to identities owned by this problem.
pub fn LayoutProblem::validate_patch(
  self : LayoutProblem,
  patch : @graph.LayoutPatch,
) -> Unit raise LayoutProblemError {
  for id, _ in patch.nodes {
    if !self.object_ids.contains(id) {
      raise UnknownPatchNode(id)
    }
  }
  for id, _ in patch.node_labels {
    if !self.object_ids.contains(id) {
      raise UnknownPatchNode(id)
    }
  }
  validate_patch_edge_map(self.edge_indices, patch.edges)
  validate_patch_edge_map(self.edge_indices, patch.edge_bend_points)
  validate_patch_edge_map(self.edge_indices, patch.edge_curves)
  validate_patch_edge_map(self.edge_indices, patch.edge_labels)
}

///|
fn register_object_id(
  object_ids : Map[String, Bool],
  id : String,
) -> Unit raise LayoutProblemError {
  if object_ids.contains(id) {
    raise DuplicateObjectId(id)
  }
  object_ids[id] = true
}

///|
fn validate_children(
  graph : @graph.GraphInput,
  object_ids : Map[String, Bool],
) -> Unit raise LayoutProblemError {
  validate_parent_children(graph.root, object_ids)
  for obj in graph.objects {
    validate_parent_children(obj, object_ids)
  }
}

///|
fn validate_parent_children(
  parent : @graph.ObjectInput,
  object_ids : Map[String, Bool],
) -> Unit raise LayoutProblemError {
  for child_id in parent.child_ids {
    if !object_ids.contains(child_id) {
      raise MissingChild(parent_id=parent.abs_id_syntax, child_id~)
    }
  }
}

///|
fn[V] validate_patch_edge_map(
  edge_indices : Map[Int, Bool],
  values : Map[Int, V],
) -> Unit raise LayoutProblemError {
  for index, _ in values {
    if !edge_indices.contains(index) {
      raise UnknownPatchEdge(index)
    }
  }
}

///|
fn canonicalize_graph(graph : @graph.GraphInput) -> @graph.GraphInput {
  let objects : Array[@graph.ObjectInput] = []
  for obj in graph.objects {
    objects.push(canonicalize_object(obj))
  }
  let edges : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    edges.push(canonicalize_edge(edge))
  }
  @graph.GraphInput::from_parts(
    graph.name,
    canonicalize_object(graph.root),
    objects,
    edges,
    graph.sequence_fragments,
    graph.activation_boxes,
    graph.sequence_notes,
    graph.sequence_fragments_layout,
    graph.layers,
    graph.scenarios,
    graph.steps,
    graph.legend,
    is_folder_only=graph.is_folder_only,
    data=graph.data,
  )
}

///|
fn canonicalize_object(obj : @graph.ObjectInput) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    obj.abs_id_syntax,
    obj.label,
    obj.shape_type,
    obj.style,
    obj.box,
    obj.label_box,
    obj.child_ids,
    obj.z_index,
    obj.icon,
    obj.tooltip,
    obj.link,
    obj.classes,
    obj.grid_rows,
    obj.grid_columns,
    obj.grid_gap,
    obj.horizontal_gap,
    obj.vertical_gap,
    obj.grid_column_span,
    obj.grid_row_span,
    obj.near,
    obj.top,
    obj.left,
    direction=obj.direction,
    language=obj.language,
    sql_constraints=obj.sql_constraints,
    id_val=obj.id_val,
    id_syntax=obj.id_syntax,
    abs_id_syntax=obj.abs_id_syntax,
    references=obj.references,
    icon_position=obj.icon_position,
    tooltip_position=obj.tooltip_position,
    label_position=obj.label_position,
  )
}

///|
fn canonicalize_edge(edge : @graph.EdgeInput) -> @graph.EdgeInput {
  let src_id = edge.lookup_src_id()
  let dst_id = edge.lookup_dst_id()
  @graph.EdgeInput::from_parts(
    edge.index,
    src_id,
    dst_id,
    edge.src_arrow,
    edge.dst_arrow,
    edge.src_arrowhead,
    edge.dst_arrowhead,
    edge.src_arrowhead_label,
    edge.dst_arrowhead_label,
    edge.src_arrowhead_label_color,
    edge.dst_arrowhead_label_color,
    edge.src_anchor,
    edge.dst_anchor,
    edge.label,
    edge.style,
    edge.route,
    edge.bend_points,
    edge.is_curve,
    edge.z_index,
    edge.reference_count,
    edge.label_box,
    edge.src_column_index,
    edge.dst_column_index,
    src_id_syntax=src_id,
    dst_id_syntax=dst_id,
    references=edge.references,
  )
}
