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
priv enum BoardCompiler {
  PlainCompiler
  ImportCompiler(ImportResolver)
}

///|
fn compile_board_patch(
  compiler : BoardCompiler,
  target : Map,
  patch : Map,
) -> Bool raise CompileError {
  guard patch.ast is Some(Map(ast)) else { return false }
  match compiler {
    PlainCompiler =>
      compile_map_nodes(target, ast, ast.nodes, source_path=patch.source_path)
    ImportCompiler(resolver) =>
      compile_map_nodes_with_imports(
        target,
        ast,
        ast.nodes,
        resolver,
        [],
        source_path=patch.source_path,
      )
  }
  true
}

///|
fn is_unresolved_indexed_edge(edge : Edge) -> Bool {
  guard edge.references.get(0) is Some(reference) else { return false }
  guard reference.context is Some(context) else { return false }
  guard context.key is Some(key) else { return false }
  match key.edge_index {
    Some(index) => !index.glob
    None => false
  }
}

///|
fn inheritable_board_map(map : Map) -> Map {
  let inherited = map.copy()
  let _ = inherited.delete_field("label")
  let _ = inherited.delete_field("layers")
  let _ = inherited.delete_field("scenarios")
  let _ = inherited.delete_field("steps")
  inherited
}

///|
fn field_with_map(field : Field, map : Map) -> Field {
  {
    name: field.name,
    name_syntax: field.name_syntax(),
    primary: field.primary,
    composite: Some(Map(map)),
    references: field.references,
    import_ast: field.import_ast,
    path: field.path,
  }
}

///|
fn materialize_board(
  compiler : BoardCompiler,
  base : Map,
  field : Field,
  inherits_base : Bool,
) -> Field raise CompileError {
  let patch = match field.composite {
    Some(Map(map)) => map
    _ => Map::new()
  }
  let materialized = if inherits_base {
    inheritable_board_map(base)
  } else {
    Map::new()
  }
  let materialized = if compile_board_patch(compiler, materialized, patch) {
    materialized
  } else {
    materialized.overlay(patch)
  }
  resolve_boards_in_map(compiler, materialized)
  field_with_map(field, materialized)
}

///|
fn materialize_board_field(
  compiler : BoardCompiler,
  board : Map,
  field_name : String,
  inherits_base : Bool,
  sequential : Bool,
) -> Unit raise CompileError {
  guard board.get_field(field_name) is Some(container_field) else { return }
  guard container_field.composite is Some(Map(container)) else { return }
  let resolved_container = clone_map(container)
  let mut previous = board
  for i, field in container.fields {
    let base = if sequential { previous } else { board }
    let resolved = materialize_board(compiler, base, field, inherits_base)
    resolved_container.fields[i] = resolved
    if sequential {
      previous = resolved.map().unwrap()
    }
  }
  board.set_field(field_with_map(container_field, resolved_container))
}

///|
fn resolve_boards_in_map(
  compiler : BoardCompiler,
  board : Map,
) -> Unit raise CompileError {
  materialize_board_field(compiler, board, "layers", false, false)
  materialize_board_field(compiler, board, "scenarios", true, false)
  materialize_board_field(compiler, board, "steps", true, true)
}

///|
fn validate_indexed_edges(map : Map) -> Unit raise CompileError {
  for edge in map.edges {
    if is_unresolved_indexed_edge(edge) {
      raise InvalidKey("indexed edge does not exist")
    }
    match edge.map {
      Some(child) => validate_indexed_edges(child)
      None => ()
    }
  }
  for field in map.fields {
    match field.composite {
      Some(Map(child)) => validate_indexed_edges(child)
      _ => ()
    }
  }
}

///|
fn resolve_boards(map : Map) -> Unit raise CompileError {
  resolve_boards_in_map(PlainCompiler, map)
  validate_indexed_edges(map)
}

///|
fn resolve_boards_with_imports(
  map : Map,
  resolver : ImportResolver,
) -> Unit raise CompileError {
  resolve_boards_in_map(ImportCompiler(resolver), map)
  validate_indexed_edges(map)
}
