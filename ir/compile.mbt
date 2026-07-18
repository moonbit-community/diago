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
/// Compile AST to IR
///
/// This module converts the parsed AST into IR, resolving:
/// - Variable substitutions
/// - Import statements
/// - Glob patterns

///|
/// Compilation error
pub(all) suberror CompileError {
  InvalidKey(String)
  InvalidValue(String)
  DuplicateField(String)
  InvalidSubstitution(String)
  ImportError(String)
} derive(Eq, Debug)

///|
pub impl Show for CompileError with fn output(self, logger) {
  match self {
    InvalidKey(message) => {
      logger.write_string("InvalidKey(")
      logger.write_object(message)
      logger.write_char(')')
    }
    InvalidValue(message) => {
      logger.write_string("InvalidValue(")
      logger.write_object(message)
      logger.write_char(')')
    }
    DuplicateField(message) => {
      logger.write_string("DuplicateField(")
      logger.write_object(message)
      logger.write_char(')')
    }
    InvalidSubstitution(message) => {
      logger.write_string("InvalidSubstitution(")
      logger.write_object(message)
      logger.write_char(')')
    }
    ImportError(message) => {
      logger.write_string("ImportError(")
      logger.write_object(message)
      logger.write_char(')')
    }
  }
}

///|
priv struct ResolvedPath {
  names : Array[String]
  syntax : Array[@ast.StringValue]
}

///|
priv struct RecursiveEdgeTarget {
  parent : Map
  edge : Edge
  src_path : ResolvedPath
  dst_path : ResolvedPath
}

///|
/// One lexical object scope between the map currently being compiled and its
/// parent. `parent` is the map reached by one leading `_`; `child_syntax` is the
/// object path segment that must be restored on an endpoint which does not
/// climb while the other endpoint does.
priv struct CompileScopeFrame {
  parent : Map
  child_syntax : @ast.StringValue
}

///|
fn CompileScopeFrame::new(
  parent : Map,
  child_syntax : @ast.StringValue,
) -> CompileScopeFrame {
  { parent, child_syntax }
}

///|
fn ResolvedPath::new(
  names : Array[String],
  syntax : Array[@ast.StringValue],
) -> ResolvedPath {
  { names, syntax }
}

///|
fn path_is_recursive_glob(path : @ast.KeyPath) -> Bool {
  if path.path.length() != 1 {
    return false
  }
  match path.path[0] {
    Unquoted(value) =>
      is_double_glob(value.pattern) || is_triple_glob(value.pattern)
    _ => false
  }
}

///|
fn append_resolved_paths(
  prefix : ResolvedPath,
  suffix_names : Array[String],
  suffix_syntax : Array[@ast.StringValue],
) -> ResolvedPath {
  let result = ResolvedPath::new(prefix.names.copy(), prefix.syntax.copy())
  for i = 0; i < suffix_names.length(); i = i + 1 {
    result.names.push(suffix_names[i])
    result.syntax.push(suffix_syntax[i])
  }
  result
}

///|
fn collect_recursive_edge_targets(
  ir : Map,
  prefix : ResolvedPath,
  include_boards : Bool,
  targets : Array[RecursiveEdgeTarget],
) -> Unit {
  for edge in ir.edges {
    targets.push({
      parent: ir,
      edge,
      src_path: append_resolved_paths(
        prefix,
        edge.id.src_path,
        edge.id.src_path_syntax,
      ),
      dst_path: append_resolved_paths(
        prefix,
        edge.id.dst_path,
        edge.id.dst_path_syntax,
      ),
    })
  }
  for field in ir.fields {
    guard field.composite is Some(Map(child)) else { continue }
    if field.is_board_keyword_name() {
      if include_boards {
        for board in child.fields {
          match board.composite {
            Some(Map(board_map)) =>
              collect_recursive_edge_targets(
                board_map,
                ResolvedPath::new([], []),
                include_boards,
                targets,
              )
            _ => ()
          }
        }
      }
      continue
    }
    if field.is_reserved_keyword_name() {
      continue
    }
    let syntax = match field.name_syntax() {
      Some(syntax) => syntax
      None => synthetic_unquoted_string(field.name)
    }
    collect_recursive_edge_targets(
      child,
      append_path_segment(prefix, field.name, syntax),
      include_boards,
      targets,
    )
  }
}

///|
/// Compile an AST Map to IR Map
pub fn compile(ast : @ast.Map) -> Map raise CompileError {
  let ir = Map::from_ast(ast)
  compile_map_non_glob_nodes(ir, ast, ast.nodes, [], None)
  resolve_boards(ir)
  // Root *** globs must run against materialized boards. Board resolution
  // recompiles each board patch, so applying them earlier loses the defaults.
  compile_map_glob_nodes(ir, ast, ast.nodes, [], None)
  // Resolve variable substitutions
  ir.resolve_substitutions()
  apply_suspensions(ir)
  ir.reindex_paths()
}

///|
fn compile_map_nodes(
  ir : Map,
  scope_ast : @ast.Map,
  nodes : Array[@ast.MapNode],
  source_path? : String? = None,
) -> Unit raise CompileError {
  compile_map_nodes_in_scope(ir, scope_ast, nodes, [], source_path)
}

///|
fn compile_map_nodes_in_scope(
  ir : Map,
  scope_ast : @ast.Map,
  nodes : Array[@ast.MapNode],
  scope_frames : Array[CompileScopeFrame],
  source_path : String?,
) -> Unit raise CompileError {
  compile_map_non_glob_nodes(ir, scope_ast, nodes, scope_frames, source_path)
  compile_map_glob_nodes(ir, scope_ast, nodes, scope_frames, source_path)
}

///|
fn compile_map_non_glob_nodes(
  ir : Map,
  scope_ast : @ast.Map,
  nodes : Array[@ast.MapNode],
  scope_frames : Array[CompileScopeFrame],
  source_path : String?,
) -> Unit raise CompileError {
  for node in nodes {
    match node {
      Key(key) =>
        if !key_uses_glob(key) {
          compile_key(ir, key, scope_ast, scope_frames, source_path)
        }
      Comment(_, _) => ()
      BlockComment(_, _) => ()
      Substitution(sub) =>
        ir.add_field(
          Field::new("", Some(substitution_scalar(sub, source_path)), None, []),
        )
      Import(_) =>
        raise ImportError(
          "imports require a resolver; use compile_with_imports",
        )
    }
  }
}

///|
fn compile_map_glob_nodes(
  ir : Map,
  scope_ast : @ast.Map,
  nodes : Array[@ast.MapNode],
  scope_frames : Array[CompileScopeFrame],
  source_path : String?,
) -> Unit raise CompileError {
  for node in nodes {
    match node {
      Key(key) =>
        if key_uses_glob(key) {
          compile_key(ir, key, scope_ast, scope_frames, source_path)
        }
      _ => ()
    }
  }
}

///|
fn key_uses_glob(key : @ast.Key) -> Bool {
  match key.key {
    Some(path) => if path.has_glob() { return true }
    None => ()
  }
  match key.edge_index {
    Some(index) => if index.glob { return true }
    None => ()
  }
  for edge in key.edges {
    if edge.src.has_glob() || edge.dst.has_glob() {
      return true
    }
  }
  false
}

///|
fn is_parent_segment(segment : @ast.StringValue) -> Bool {
  match segment {
    Unquoted(value) => value.pattern.is_empty() && value.to_string() == "_"
    _ => false
  }
}

///|
fn leading_parent_count(path : @ast.KeyPath) -> Int {
  let mut count = 0
  for segment in path.path {
    if !is_parent_segment(segment) {
      break
    }
    count = count + 1
  }
  count
}

///|
fn scalar_suspension(scalar : @ast.Scalar) -> Bool? {
  match scalar {
    String(Unquoted(value)) =>
      if value.pattern.is_empty() {
        match value.to_string() {
          "suspend" => Some(true)
          "unsuspend" => Some(false)
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn key_suspension(key : @ast.Key) -> Bool? {
  match key.primary {
    Some(scalar) =>
      match scalar_suspension(scalar) {
        Some(value) => return Some(value)
        None => ()
      }
    None => ()
  }
  match key.value {
    Some(Scalar(scalar)) => scalar_suspension(scalar)
    Some(BlockScalar(Scalar(scalar), _)) => scalar_suspension(scalar)
    _ => None
  }
}

///|
fn record_field_reference(
  m : Map,
  f : Field,
  elem : @ast.StringValue,
  key_path : @ast.KeyPath,
  context : RefContext,
  key_path_index : Int,
  primary : Bool,
  due_to_glob? : Bool = false,
  due_to_lazy_glob? : Bool = false,
) -> Field {
  let refs = f.references.copy()
  refs.push(
    FieldReference::from_ast(
      elem,
      key_path,
      key_path_index,
      primary,
      context,
      due_to_glob~,
      due_to_lazy_glob~,
    ),
  )
  let updated = Field::new(
    f.name,
    f.primary,
    f.composite,
    refs,
    name_syntax=f.name_syntax(),
  )
  m.set_field(updated)
  updated
}

///|
fn compile_key(
  ir : Map,
  key : @ast.Key,
  scope_ast : @ast.Map,
  scope_frames : Array[CompileScopeFrame],
  source_path : String?,
) -> Unit raise CompileError {
  // Handle ampersand filters (they are evaluated during glob expansion)
  if key.ampersand || key.not_ampersand {
    // Filters are collected and applied during glob expansion
    // They don't create fields themselves
    return
  }
  // Handle edges first
  if key.edges.length() > 0 {
    compile_edges(ir, key, scope_ast, scope_frames, source_path)
    return
  }
  // Handle regular key
  guard key.key is Some(key_path) else { return }
  // Check for glob pattern
  if key_path.has_glob() {
    compile_glob_key(ir, key_path, key, scope_ast, source_path)
    return
  }
  let context = RefContext::new(None, Some(key), Some(scope_ast), source_path~)
  let path = key_path.to_strings()
  if path.length() == 0 {
    return
  }
  let parent_count = leading_parent_count(key_path)
  if parent_count > scope_frames.length() {
    raise InvalidKey("invalid underscore: no parent")
  }
  if parent_count == path.length() {
    raise InvalidKey("field key must contain more than underscores")
  }
  // Navigate/create the field path
  let mut current_map = if parent_count == 0 {
    ir
  } else {
    scope_frames[scope_frames.length() - parent_count].parent
  }
  let current_frames : Array[CompileScopeFrame] = []
  for i = 0; i < scope_frames.length() - parent_count; i = i + 1 {
    current_frames.push(scope_frames[i])
  }
  for i = parent_count; i < path.length() - 1; i = i + 1 {
    let elem = key_path.path[i]
    let field = record_field_reference(
      current_map,
      current_map.ensure_field_by_syntax(elem),
      elem,
      key_path,
      context,
      i,
      false,
    )
    // Ensure field has a map composite
    current_frames.push(CompileScopeFrame::new(current_map, elem))
    match field.composite {
      Some(Map(m)) => current_map = m
      None => {
        let new_map = Map::new()
        let field = Field::new(
          field.name,
          field.primary,
          Some(Map(new_map)),
          field.references,
          name_syntax=field.name_syntax(),
        )
        current_map.set_field(field)
        current_map = new_map
      }
      Some(_) => raise InvalidKey("field already has non-map value")
    }
  }
  // Set the final field
  let last_index = path.length() - 1
  let last_elem = key_path.path[last_index]
  let field0 = current_map.ensure_field_by_syntax(last_elem)
  let field1 = if key.primary is Some(_) || key.value is None {
    record_field_reference(
      current_map,
      field0,
      last_elem,
      key_path,
      context,
      last_index,
      key.primary is Some(_),
    )
  } else {
    field0
  }
  let field = if key.value is Some(_) {
    record_field_reference(
      current_map, field1, last_elem, key_path, context, last_index, true,
    )
  } else {
    field1
  }
  if key_suspension(key) is Some(_) {
    current_map.set_field(field)
    return
  }
  // Set primary value
  let field = match key.primary {
    Some(scalar) =>
      Field::new(
        field.name,
        Some(compile_scalar(scalar, source_path)),
        field.composite,
        field.references,
        name_syntax=field.name_syntax(),
      )
    None => field
  }
  // Set value
  let field = match key.value {
    Some(value) =>
      compile_value_in_scope(
        field, value, current_map, current_frames, source_path,
      )
    None => field
  }
  current_map.set_field(field)
}

///|
/// Compile a key with glob pattern
fn compile_glob_key(
  ir : Map,
  key_path : @ast.KeyPath,
  key : @ast.Key,
  scope_ast : @ast.Map,
  source_path : String?,
) -> Unit raise CompileError {
  // Find the glob element and extract pattern
  let (pattern, glob_index) = extract_glob_and_path(key_path)
  if pattern.length() == 0 || glob_index < 0 {
    return // No valid glob pattern
  }
  // Collect filters from the value map if present
  let filters = collect_filters_from_value(key)
  // Build properties map from the remaining path and value
  let context = RefContext::new(None, Some(key), Some(scope_ast), source_path~)
  let suspension = key_suspension(key)
  let properties = build_nested_properties(
    key_path, glob_index, key, context, source_path,
  )
  // A glob may be qualified by a literal path, for example
  // `cluster.services.pod*.class`. Match the glob in that path's map instead
  // of silently treating it as a root-level pattern.
  let mut target_map = ir
  for i = 0; i < glob_index; i = i + 1 {
    guard target_map.get_field_by_syntax(key_path.path[i]) is Some(field) else {
      return
    }
    match field.composite {
      Some(Map(next)) => target_map = next
      _ => return
    }
  }
  let targets = target_map.glob_targets(pattern)
  // Apply descendants before ancestors. Applying a property clones a field's
  // composite map, so parent-first updates would detach the child maps captured
  // by `glob_targets` (most visibly for *** defaults inside boards).
  let mut target_index = targets.length() - 1
  while target_index >= 0 {
    let target = targets[target_index]
    let field = target.field
    let parent_map = target.parent_map
    let live_field = parent_map.get_field(field.name).unwrap_or(field)
    let filter_context = FilterContext::new(live_field, parent_map)
    let mut passes = true
    for filter in filters {
      let (negated, filter_key, filter_value) = filter
      let matched = evaluate_filter_at_level(
        filter_context,
        filter_key,
        filter_value,
        target.level,
      )
      if (if negated { matched } else { !matched }) {
        passes = false
        break
      }
    }
    if passes {
      match suspension {
        Some(_) =>
          if glob_operation_follows_field(live_field, key, source_path) {
            let syntax = match live_field.name_syntax() {
              Some(syntax) => syntax
              None => synthetic_unquoted_string(live_field.name)
            }
            let _ = record_field_reference(
              parent_map,
              live_field,
              syntax,
              key_path,
              context,
              glob_index,
              true,
              due_to_glob=true,
            )
          }
        None => {
          let updated = apply_properties_to_field(live_field, properties)
          parent_map.set_field(updated)
          apply_nested_globs(updated, key.value, source_path)
        }
      }
    }
    target_index = target_index - 1
  }
}

///|
fn glob_operation_follows_field(
  field : Field,
  key : @ast.Key,
  source_path : String?,
) -> Bool {
  guard field.last_ref() is Some(reference) else { return true }
  match reference.context() {
    Some(existing_context) =>
      if existing_context.source_path != source_path {
        return true
      }
    None => return true
  }
  key.range.start.offset >= reference_operation_range(reference).start.offset
}

///|
fn apply_nested_globs(
  field : Field,
  value : @ast.Value?,
  source_path : String?,
) -> Unit raise CompileError {
  guard value is Some(Map(ast_map)) else { return }
  guard field.composite is Some(Map(field_map)) else { return }
  for node in ast_map.nodes {
    match node {
      Key(nested_key) =>
        if !nested_key.ampersand &&
          !nested_key.not_ampersand &&
          key_uses_glob(nested_key) {
          compile_key(field_map, nested_key, ast_map, [], source_path)
        }
      _ => ()
    }
  }
}

///|
/// Extract glob pattern and remaining path from key path
/// Returns (pattern, remaining_path) where pattern is from the glob element
/// and remaining_path is the rest of the key path after the glob
fn extract_glob_and_path(key_path : @ast.KeyPath) -> (Array[String], Int) {
  let path = key_path.path
  let mut glob_index = -1
  let mut pattern : Array[String] = []
  // Find the first element with a glob pattern
  for i, elem in path {
    match elem {
      Unquoted(us) =>
        if us.pattern.length() > 0 {
          pattern = us.pattern
          glob_index = i
          break
        }
      _ => ()
    }
  }
  if glob_index < 0 {
    return ([], -1)
  }
  (pattern, glob_index)
}

///|
/// Build nested properties map from remaining path and key value
fn build_nested_properties(
  key_path : @ast.KeyPath,
  glob_index : Int,
  key : @ast.Key,
  context : RefContext,
  source_path : String?,
) -> Map raise CompileError {
  let props = Map::new()
  let remaining_path : Array[@ast.StringValue] = []
  for i = glob_index + 1; i < key_path.path.length(); i = i + 1 {
    remaining_path.push(key_path.path[i])
  }
  if remaining_path.length() == 0 {
    // Compile non-glob properties exactly as ordinary keys so dotted paths,
    // maps, and arrays retain their normal semantics. Nested globs are applied
    // separately to each matched field.
    match key.value {
      Some(Map(m)) =>
        for node in m.nodes {
          match node {
            Key(prop_key) =>
              if !prop_key.ampersand &&
                !prop_key.not_ampersand &&
                !key_uses_glob(prop_key) {
                compile_key(props, prop_key, m, [], source_path)
              }
            _ => ()
          }
        }
      _ => ()
    }
  } else {
    // Build nested structure: style.fill: red -> { style: { fill: red } }
    let mut current = props
    for i = 0; i < remaining_path.length() - 1; i = i + 1 {
      let elem = remaining_path[i]
      let name = elem.content()
      let field = Field::new(
        name,
        None,
        None,
        [
          FieldReference::from_ast(
            elem,
            key_path,
            glob_index + 1 + i,
            false,
            context,
            due_to_glob=true,
          ),
        ],
        name_syntax=Some(elem),
      )
      let inner = Map::new()
      let field = Field::new(
        field.name,
        field.primary,
        Some(Map(inner)),
        field.references,
        name_syntax=field.name_syntax(),
      )
      current.add_field(field)
      current = inner
    }
    // Set the final value
    let final_elem = remaining_path[remaining_path.length() - 1]
    let final_name = final_elem.content()
    let final_index = glob_index + remaining_path.length()
    let final_field = Field::new(
      final_name,
      None,
      None,
      [
        FieldReference::from_ast(
          final_elem,
          key_path,
          final_index,
          true,
          context,
          due_to_glob=true,
        ),
      ],
      name_syntax=Some(final_elem),
    )
    // Compile glob properties through the same value path as ordinary keys so
    // arrays and maps retain their full IR representation.
    let final_field = match key.primary {
      Some(scalar) =>
        Field::new(
          final_field.name,
          Some(compile_scalar(scalar, source_path)),
          final_field.composite,
          {
            let refs = final_field.references.copy()
            refs.push(
              FieldReference::from_ast(
                final_elem,
                key_path,
                final_index,
                true,
                context,
                due_to_glob=true,
              ),
            )
            refs
          },
          name_syntax=final_field.name_syntax(),
        )
      None => final_field
    }
    let final_field = match key.value {
      Some(value) => compile_value(final_field, value, source_path)
      None => final_field
    }
    current.add_field(final_field)
  }
  props
}

///|
/// Collect filter conditions from the key's value map
fn collect_filters_from_value(key : @ast.Key) -> Array[(Bool, String, String)] {
  let filters : Array[(Bool, String, String)] = []
  match key.value {
    Some(Map(m)) | Some(BlockScalar(_, m)) =>
      for node in m.nodes {
        match node {
          Key(filter_key) =>
            if filter_key.ampersand || filter_key.not_ampersand {
              // This is a filter
              match (filter_key.key, filter_key.value) {
                (Some(fk), Some(Scalar(sv))) => {
                  let filter_name = fk.to_strings().join(".")
                  let filter_value = compile_scalar(sv, None).to_string()
                  filters.push(
                    (filter_key.not_ampersand, filter_name, filter_value),
                  )
                }
                _ => ()
              }
            }
          _ => ()
        }
      }
    _ => ()
  }
  filters
}

///|
fn edge_endpoint_paths(
  ir : Map,
  key_path : @ast.KeyPath,
) -> Array[ResolvedPath] {
  if !key_path.has_glob() {
    return [ResolvedPath::new(key_path.to_strings(), key_path.path.copy())]
  }
  let out : Array[ResolvedPath] = []
  expand_edge_endpoint_paths(
    ir,
    key_path.path,
    0,
    ResolvedPath::new([], []),
    out,
  )
  out
}

///|
fn expand_edge_endpoint_paths(
  current_map : Map,
  segments : Array[@ast.StringValue],
  index : Int,
  current_path : ResolvedPath,
  out : Array[ResolvedPath],
) -> Unit {
  if index >= segments.length() {
    out.push(current_path)
    return
  }
  let segment = segments[index]
  let is_last = index == segments.length() - 1
  match segment {
    Unquoted(us) =>
      if is_double_glob(us.pattern) || is_triple_glob(us.pattern) {
        expand_multi_glob_edge_endpoint_paths(
          current_map,
          segments,
          index,
          current_path,
          out,
          is_triple_glob(us.pattern),
        )
      } else if us.pattern.length() > 0 {
        let candidates = current_map.single_glob(us.pattern)
        for field in candidates {
          let next_path = append_path_segment(
            current_path,
            field.name,
            match field.name_syntax() {
              Some(name_syntax) => name_syntax
              None => synthetic_unquoted_string(field.name)
            },
          )
          if is_last {
            out.push(next_path)
          } else {
            match field.composite {
              Some(Map(m)) =>
                expand_edge_endpoint_paths(
                  m,
                  segments,
                  index + 1,
                  next_path,
                  out,
                )
              _ => ()
            }
          }
        }
      } else {
        let segment_name = segment.content()
        match current_map.get_field_by_syntax(segment) {
          Some(field) => {
            let next_path = append_path_segment(
              current_path, segment_name, segment,
            )
            if is_last {
              out.push(next_path)
            } else {
              match field.composite {
                Some(Map(m)) =>
                  expand_edge_endpoint_paths(
                    m,
                    segments,
                    index + 1,
                    next_path,
                    out,
                  )
                _ => ()
              }
            }
          }
          None => ()
        }
      }
    _ => {
      let segment_name = segment.content()
      match current_map.get_field_by_syntax(segment) {
        Some(field) => {
          let next_path = append_path_segment(
            current_path, segment_name, segment,
          )
          if is_last {
            out.push(next_path)
          } else {
            match field.composite {
              Some(Map(m)) =>
                expand_edge_endpoint_paths(
                  m,
                  segments,
                  index + 1,
                  next_path,
                  out,
                )
              _ => ()
            }
          }
        }
        None => ()
      }
    }
  }
}

///|
fn expand_multi_glob_edge_endpoint_paths(
  current_map : Map,
  segments : Array[@ast.StringValue],
  index : Int,
  current_path : ResolvedPath,
  out : Array[ResolvedPath],
  include_boards : Bool,
) -> Unit {
  let is_last = index == segments.length() - 1
  for field in current_map.fields {
    let child_map = match field.composite {
      Some(Map(map)) => Some(map)
      _ => None
    }
    if field.is_board_keyword_name() {
      if include_boards {
        match child_map {
          Some(boards) =>
            for board in boards.fields {
              match board.composite {
                Some(Map(board_map)) =>
                  expand_multi_glob_edge_endpoint_paths(
                    board_map,
                    segments,
                    index,
                    ResolvedPath::new([], []),
                    out,
                    include_boards,
                  )
                _ => ()
              }
            }
          None => ()
        }
      }
      continue
    }
    if field.is_reserved_keyword_name() {
      continue
    }
    let syntax = match field.name_syntax() {
      Some(name_syntax) => name_syntax
      None => synthetic_unquoted_string(field.name)
    }
    let next_path = append_path_segment(current_path, field.name, syntax)
    if is_last {
      if field_is_leaf(field) {
        out.push(next_path)
      }
    } else {
      match child_map {
        Some(map) =>
          expand_edge_endpoint_paths(map, segments, index + 1, next_path, out)
        None => ()
      }
    }
    match child_map {
      Some(map) =>
        expand_multi_glob_edge_endpoint_paths(
          map, segments, index, next_path, out, include_boards,
        )
      None => ()
    }
  }
}

///|
fn append_path_segment(
  path : ResolvedPath,
  segment : String,
  syntax : @ast.StringValue,
) -> ResolvedPath {
  let names : Array[String] = []
  for p in path.names {
    names.push(p)
  }
  names.push(segment)
  let syntax_path : Array[@ast.StringValue] = []
  for part in path.syntax {
    syntax_path.push(part)
  }
  syntax_path.push(syntax)
  ResolvedPath::new(names, syntax_path)
}

///|
fn string_path_equal(a : ResolvedPath, b : ResolvedPath) -> Bool {
  if a.names.length() != b.names.length() {
    return false
  }
  for i = 0; i < a.names.length(); i = i + 1 {
    if a.names[i] != b.names[i] {
      return false
    }
  }
  true
}

///|
fn edge_path_after_parent_resolution(
  path : @ast.KeyPath,
  scope_frames : Array[CompileScopeFrame],
  climb : Int,
) -> @ast.KeyPath {
  let resolved : Array[@ast.StringValue] = []
  let mut consumed = 0
  for step = 0; step < climb; step = step + 1 {
    if consumed < path.path.length() && is_parent_segment(path.path[consumed]) {
      consumed = consumed + 1
    } else {
      let frame = scope_frames[scope_frames.length() - 1 - step]
      resolved.insert(0, frame.child_syntax)
    }
  }
  for i = consumed; i < path.path.length(); i = i + 1 {
    resolved.push(path.path[i])
  }
  @ast.KeyPath::new(path.range, resolved)
}

///|
fn parent_edge_scope(
  ir : Map,
  scope_frames : Array[CompileScopeFrame],
  climb : Int,
) -> Map raise CompileError {
  if climb == 0 {
    return ir
  }
  if climb > scope_frames.length() {
    raise InvalidKey("invalid underscore: no parent")
  }
  scope_frames[scope_frames.length() - climb].parent
}

///|
fn compile_edges(
  scope_ir : Map,
  key : @ast.Key,
  scope_ast : @ast.Map,
  scope_frames : Array[CompileScopeFrame],
  source_path : String?,
) -> Unit raise CompileError {
  for edge in key.edges {
    let src_parent_count = leading_parent_count(edge.src)
    let dst_parent_count = leading_parent_count(edge.dst)
    let climb = if src_parent_count > dst_parent_count {
      src_parent_count
    } else {
      dst_parent_count
    }
    let ir = parent_edge_scope(scope_ir, scope_frames, climb)
    let src = edge_path_after_parent_resolution(edge.src, scope_frames, climb)
    let dst = edge_path_after_parent_resolution(edge.dst, scope_frames, climb)
    let edge_context = RefContext::new(
      Some(edge),
      Some(key),
      Some(scope_ast),
      source_path~,
    )
    let src_paths = edge_endpoint_paths(ir, src)
    let dst_paths = edge_endpoint_paths(ir, dst)
    let filters = collect_filters_from_value(key)
    let src_has_glob = edge.src.has_glob()
    let dst_has_glob = edge.dst.has_glob()
    if src_paths.is_empty() || dst_paths.is_empty() {
      continue
    }
    fn next_index_for_group(ir : Map, base_id : EdgeID) -> Int {
      let existing = ir.find_edges(base_id)
      let mut max_idx = -1
      for e in existing {
        match e.id.index {
          Some(i) => if i > max_idx { max_idx = i }
          None => if max_idx < 0 { max_idx = 0 }
        }
      }
      max_idx + 1
    }

    fn find_exact_edge(ir : Map, id : EdgeID) -> Edge? {
      for e in ir.edges {
        if e.id.matches(id) {
          return Some(e)
        }
      }
      None
    }

    fn compile_edge_value(
      existing : Edge?,
      value : @ast.Value?,
    ) -> (Scalar?, Map?) raise CompileError {
      if key_suspension(key) is Some(_) {
        return match existing {
          Some(edge) => (edge.primary, edge.map)
          None => (None, None)
        }
      }
      let (patch_primary, patch_map) = match value {
        Some(Scalar(s)) => (Some(compile_scalar(s, source_path)), None)
        Some(Map(m)) => {
          let ir_map = Map::from_ast(m, source_path~)
          compile_map_nodes(ir_map, m, m.nodes, source_path~)
          (None, Some(ir_map))
        }
        Some(BlockScalar(label, m)) => {
          let primary = match label {
            Scalar(s) => Some(compile_scalar(s, source_path))
            _ => None
          }
          let ir_map = Map::from_ast(m, source_path~)
          compile_map_nodes(ir_map, m, m.nodes, source_path~)
          (primary, Some(ir_map))
        }
        _ => (None, None)
      }
      let index_glob = match key.edge_index {
        Some(index) => index.glob
        None => false
      }
      let is_glob_update = src_has_glob || dst_has_glob || index_glob
      let patch_overrides = !is_glob_update ||
        glob_edge_patch_follows_existing(existing, key.range.start.offset)
      apply_edge_value(
        existing,
        key.edge_key,
        patch_primary,
        patch_map,
        patch_overrides~,
      )
    }

    if path_is_recursive_glob(src) &&
      path_is_recursive_glob(dst) &&
      key.edge_index.map(fn(index) { index.glob }).unwrap_or(false) {
      let targets : Array[RecursiveEdgeTarget] = []
      let include_boards = match (src.path[0], dst.path[0]) {
        (Unquoted(a), Unquoted(b)) =>
          is_triple_glob(a.pattern) || is_triple_glob(b.pattern)
        _ => false
      }
      collect_recursive_edge_targets(
        ir,
        ResolvedPath::new([], []),
        include_boards,
        targets,
      )
      for target in targets {
        if target.edge.id.src_arrow != (edge.src_arrow == "<") ||
          target.edge.id.dst_arrow != (edge.dst_arrow == ">") {
          continue
        }
        if key_suspension(key) is Some(_) &&
          !glob_edge_patch_follows_existing(
            Some(target.edge),
            key.range.start.offset,
          ) {
          continue
        }
        if !edge_glob_filters_pass(
            ir,
            Some(target.edge),
            target.src_path,
            target.dst_path,
            filters,
          ) {
          continue
        }
        let references = target.edge.references.copy()
        references.push(
          EdgeReference::from_ast(
            edge,
            target.edge.id.index.unwrap_or(0),
            true,
            edge_context,
            due_to_glob=true,
          ),
        )
        let (primary, edge_map) = compile_edge_value(
          Some(target.edge),
          key.value,
        )
        target.parent.set_edge(
          Edge::new(target.edge.id, primary, edge_map, references),
        )
      }
      continue
    }

    for src_path in src_paths {
      for dst_path in dst_paths {
        if !edge_glob_filters_pass(ir, None, src_path, dst_path, filters) {
          continue
        }
        if (src_has_glob || dst_has_glob) &&
          string_path_equal(src_path, dst_path) {
          continue
        }
        let base_id = EdgeID::new(
          src_path.names,
          dst_path.names,
          edge.src_arrow == "<",
          edge.dst_arrow == ">",
          src_path_syntax=Some(src_path.syntax),
          dst_path_syntax=Some(dst_path.syntax),
        )
        // The reference preserves multiple edges between the same endpoints. When no explicit
        // `[index]` is given, allocate the next index and create a new edge.
        // When `[index]` is provided, update that edge if it exists; otherwise
        // create it at that index.
        match key.edge_index {
          Some(ei) =>
            if ei.glob {
              // Apply the value block to all edges in the group.
              let existing = ir.find_edges(base_id)
              for e in existing {
                if key_suspension(key) is Some(_) &&
                  !glob_edge_patch_follows_existing(
                    Some(e),
                    key.range.start.offset,
                  ) {
                  continue
                }
                if !edge_glob_filters_pass(
                    ir,
                    Some(e),
                    src_path,
                    dst_path,
                    filters,
                  ) {
                  continue
                }
                e.references.push(
                  EdgeReference::from_ast(
                    edge,
                    e.id.index.unwrap_or(0),
                    true,
                    edge_context,
                    due_to_glob=true,
                  ),
                )
                ensure_field_path(ir, src_path)
                ensure_field_path(ir, dst_path)
                append_field_references_for_path(
                  ir, src_path, edge_context, true,
                )
                append_field_references_for_path(
                  ir, dst_path, edge_context, true,
                )
                let (primary, edge_map) = compile_edge_value(Some(e), key.value)
                ir.set_edge(Edge::new(e.id, primary, edge_map, e.references))
              }
            } else {
              let idx = ei.index.unwrap_or(0)
              let edge_id = EdgeID::with_index(
                base_id.src_path,
                base_id.dst_path,
                base_id.src_arrow,
                base_id.dst_arrow,
                idx,
                src_path_syntax=Some(base_id.src_path_syntax),
                dst_path_syntax=Some(base_id.dst_path_syntax),
              )
              match find_exact_edge(ir, edge_id) {
                Some(e) => {
                  e.references.push(
                    EdgeReference::from_ast(
                      edge,
                      idx,
                      true,
                      edge_context,
                      due_to_glob=src_has_glob || dst_has_glob,
                    ),
                  )
                  ensure_field_path(ir, src_path)
                  ensure_field_path(ir, dst_path)
                  append_field_references_for_path(
                    ir,
                    src_path,
                    edge_context,
                    src_has_glob || dst_has_glob,
                  )
                  append_field_references_for_path(
                    ir,
                    dst_path,
                    edge_context,
                    src_has_glob || dst_has_glob,
                  )
                  let (primary, edge_map) = compile_edge_value(
                    Some(e),
                    key.value,
                  )
                  ir.set_edge(Edge::new(e.id, primary, edge_map, e.references))
                }
                None => {
                  let (primary, edge_map) = compile_edge_value(None, key.value)
                  let new_edge = Edge::new(edge_id, primary, edge_map, [
                    EdgeReference::from_ast(
                      edge,
                      idx,
                      true,
                      edge_context,
                      due_to_glob=src_has_glob || dst_has_glob,
                    ),
                  ])
                  ir.add_edge(new_edge)
                  ensure_field_path(ir, src_path)
                  ensure_field_path(ir, dst_path)
                  append_field_references_for_path(
                    ir,
                    src_path,
                    edge_context,
                    src_has_glob || dst_has_glob,
                  )
                  append_field_references_for_path(
                    ir,
                    dst_path,
                    edge_context,
                    src_has_glob || dst_has_glob,
                  )
                }
              }
            }
          None => {
            let idx = next_index_for_group(ir, base_id)
            let edge_id = EdgeID::with_index(
              base_id.src_path,
              base_id.dst_path,
              base_id.src_arrow,
              base_id.dst_arrow,
              idx,
              src_path_syntax=Some(base_id.src_path_syntax),
              dst_path_syntax=Some(base_id.dst_path_syntax),
            )
            let (primary, edge_map) = compile_edge_value(None, key.value)
            let new_edge = Edge::new(edge_id, primary, edge_map, [
              EdgeReference::from_ast(
                edge,
                idx,
                true,
                edge_context,
                due_to_glob=src_has_glob || dst_has_glob,
              ),
            ])
            ir.add_edge(new_edge)
            ensure_field_path(ir, src_path)
            ensure_field_path(ir, dst_path)
            append_field_references_for_path(
              ir,
              src_path,
              edge_context,
              src_has_glob || dst_has_glob,
            )
            append_field_references_for_path(
              ir,
              dst_path,
              edge_context,
              src_has_glob || dst_has_glob,
            )
          }
        }
      }
    }
  }
}

///|
fn field_at_resolved_path(ir : Map, path : ResolvedPath) -> (Field, Map)? {
  let mut current = ir
  for i, syntax in path.syntax {
    guard current.get_field_by_syntax(syntax) is Some(field) else {
      return None
    }
    if i == path.syntax.length() - 1 {
      return Some((field, current))
    }
    match field.composite {
      Some(Map(next)) => current = next
      _ => return None
    }
  }
  None
}

///|
fn edge_glob_filters_pass(
  ir : Map,
  edge : Edge?,
  src_path : ResolvedPath,
  dst_path : ResolvedPath,
  filters : Array[(Bool, String, String)],
) -> Bool {
  for filter in filters {
    let (negated, key, value) = filter
    let parts = key.split(".").collect()
    let mut result = false
    if !parts.is_empty() &&
      (parts[0].to_owned() == "src" || parts[0].to_owned() == "dst") {
      let endpoint_path = if parts[0].to_owned() == "src" {
        src_path
      } else {
        dst_path
      }
      if parts.length() == 1 {
        result = filter_value_matches(endpoint_path.names.join("."), value)
      } else {
        let property_parts : Array[String] = []
        for i = 1; i < parts.length(); i = i + 1 {
          property_parts.push(parts[i].to_owned())
        }
        match field_at_resolved_path(ir, endpoint_path) {
          Some((field, parent_map)) =>
            result = evaluate_filter_at_level(
              FilterContext::new(field, parent_map),
              property_parts.join("."),
              value,
              endpoint_path.names.length() - 1,
            )
          None => ()
        }
      }
    } else {
      match edge {
        Some(edge) => result = edge_filter_property_matches(edge, key, value)
        None => result = true
      }
    }
    let passes = if negated { !result } else { result }
    if !passes {
      return false
    }
  }
  true
}

///|
fn edge_filter_property_matches(
  edge : Edge,
  key : String,
  value : String,
) -> Bool {
  if key == "label" {
    return match edge.primary {
      Some(label) => filter_value_matches(label.to_string(), value)
      None => filter_value_matches("", value)
    }
  }
  guard edge.map is Some(edge_map) else { return false }
  let parts = key.split(".").collect()
  let mut current = edge_map
  for i = 0; i < parts.length(); i = i + 1 {
    guard current.get_field(parts[i].to_owned()) is Some(field) else {
      return false
    }
    if i == parts.length() - 1 {
      return match field.primary {
        Some(property) => filter_value_matches(property.to_string(), value)
        None => false
      }
    }
    match field.composite {
      Some(Map(next)) => current = next
      _ => return false
    }
  }
  false
}

///|
fn ensure_field_path(ir : Map, path : ResolvedPath) -> Unit {
  let mut current = ir
  for i, _ in path.names {
    let field = current.ensure_field_by_syntax(path.syntax[i])
    match field.composite {
      Some(Map(m)) => current = m
      None => {
        let new_map = Map::new()
        let field = Field::new(
          field.name,
          field.primary,
          Some(Map(new_map)),
          field.references,
          name_syntax=field.name_syntax(),
        )
        current.set_field(field)
        current = new_map
      }
      Some(_) => break // Field has non-map composite, stop
    }
  }
}

///|
fn append_field_references_for_path(
  ir : Map,
  path : ResolvedPath,
  context : RefContext,
  due_to_glob : Bool,
) -> Unit {
  if path.syntax.is_empty() {
    return
  }
  let key_path = @ast.KeyPath::new(path.syntax[0].range(), path.syntax.copy())
  append_field_references_for_path_at(
    ir, path, key_path, context, 0, due_to_glob,
  )
}

///|
fn append_field_references_for_path_at(
  current : Map,
  path : ResolvedPath,
  key_path : @ast.KeyPath,
  context : RefContext,
  index : Int,
  due_to_glob : Bool,
) -> Unit {
  if index >= path.syntax.length() {
    return
  }
  let field = match current.get_field_by_syntax(path.syntax[index]) {
    Some(field) => field
    None => return
  }
  let updated = record_field_reference(
    current,
    field,
    path.syntax[index],
    key_path,
    context,
    index,
    false,
    due_to_glob~,
  )
  if index + 1 >= path.syntax.length() {
    return
  }
  match updated.composite {
    Some(Map(next)) =>
      append_field_references_for_path_at(
        next,
        path,
        key_path,
        context,
        index + 1,
        due_to_glob,
      )
    _ => ()
  }
}

///|
fn compile_value(
  field : Field,
  value : @ast.Value,
  source_path : String?,
) -> Field raise CompileError {
  compile_value_detached(field, value, source_path)
}

///|
fn compile_value_in_scope(
  field : Field,
  value : @ast.Value,
  parent_map : Map,
  scope_frames : Array[CompileScopeFrame],
  source_path : String?,
) -> Field raise CompileError {
  match value {
    Map(m) => {
      let ir_map = match field.composite {
        Some(Map(existing)) => existing
        _ => Map::from_ast(m, source_path~)
      }
      let nested_frames = scope_frames.copy()
      let child_syntax = match field.name_syntax() {
        Some(syntax) => syntax
        None => synthetic_unquoted_string(field.name)
      }
      nested_frames.push(CompileScopeFrame::new(parent_map, child_syntax))
      compile_map_nodes_in_scope(ir_map, m, m.nodes, nested_frames, source_path)
      Field::new(
        field.name,
        field.primary,
        Some(Map(ir_map)),
        field.references,
        name_syntax=field.name_syntax(),
      )
    }
    BlockScalar(label, m) => {
      let field = match label {
        Scalar(s) =>
          Field::new(
            field.name,
            Some(compile_scalar(s, source_path)),
            field.composite,
            field.references,
            name_syntax=field.name_syntax(),
          )
        _ => field
      }
      let ir_map = match field.composite {
        Some(Map(existing)) => existing
        _ => Map::from_ast(m, source_path~)
      }
      let nested_frames = scope_frames.copy()
      let child_syntax = match field.name_syntax() {
        Some(syntax) => syntax
        None => synthetic_unquoted_string(field.name)
      }
      nested_frames.push(CompileScopeFrame::new(parent_map, child_syntax))
      compile_map_nodes_in_scope(ir_map, m, m.nodes, nested_frames, source_path)
      Field::new(
        field.name,
        field.primary,
        Some(Map(ir_map)),
        field.references,
        name_syntax=field.name_syntax(),
      )
    }
    _ => compile_value_detached(field, value, source_path)
  }
}

///|
fn compile_value_detached(
  field : Field,
  value : @ast.Value,
  source_path : String?,
) -> Field raise CompileError {
  match value {
    Scalar(s) =>
      Field::new(
        field.name,
        Some(compile_scalar(s, source_path)),
        match field.composite {
          Some(Array(_)) => None
          other => other
        },
        field.references,
        name_syntax=field.name_syntax(),
      )
    Map(m) => {
      let ir_map = match field.composite {
        Some(Map(existing)) => existing
        _ => Map::from_ast(m, source_path~)
      }
      compile_map_nodes(ir_map, m, m.nodes, source_path~)
      Field::new(
        field.name,
        field.primary,
        Some(Map(ir_map)),
        field.references,
        name_syntax=field.name_syntax(),
      )
    }
    Array(a) => {
      let ir_array = compile_array(a, source_path)
      Field::new(
        field.name,
        None,
        Some(Array(ir_array)),
        field.references,
        name_syntax=field.name_syntax(),
      )
    }
    Import(_) =>
      raise ImportError("imports require a resolver; use compile_with_imports")
    BlockScalar(label, m) => {
      // "name: Label { props }" - Label is primary, props is composite
      let field = match label {
        Scalar(s) =>
          Field::new(
            field.name,
            Some(compile_scalar(s, source_path)),
            field.composite,
            field.references,
            name_syntax=field.name_syntax(),
          )
        _ => field
      }
      let ir_map = match field.composite {
        Some(Map(existing)) => existing
        _ => Map::from_ast(m, source_path~)
      }
      compile_map_nodes(ir_map, m, m.nodes, source_path~)
      Field::new(
        field.name,
        field.primary,
        Some(Map(ir_map)),
        field.references,
        name_syntax=field.name_syntax(),
      )
    }
  }
}

///|
fn compile_array(
  arr : @ast.ArrayValue,
  source_path : String?,
) -> IRArray raise CompileError {
  let values : Array[Value] = []
  for node in arr.nodes {
    match node {
      Comment(_, _) => ()
      BlockComment(_, _) => ()
      Substitution(sub) =>
        values.push(Scalar(substitution_scalar(sub, source_path)))
      Import(_) =>
        raise ImportError(
          "imports require a resolver; use compile_with_imports",
        )
      Value(v) => values.push(compile_ast_value(v, source_path))
    }
  }
  IRArray::from_ast(arr, values, source_path~)
}

///|
fn substitution_scalar(
  sub : @ast.Substitution,
  source_path : String?,
) -> Scalar {
  Scalar::from_ast(
    Substitution(sub),
    String(Unquoted(@ast.UnquotedString::new(sub.range, [Sub(sub)], []))),
    source_path~,
  )
}

///|
fn compile_ast_value(
  value : @ast.Value,
  source_path : String?,
) -> Value raise CompileError {
  match value {
    Scalar(s) => Scalar(compile_scalar(s, source_path))
    Map(m) => {
      let ir_map = Map::from_ast(m, source_path~)
      compile_map_nodes(ir_map, m, m.nodes, source_path~)
      Map(ir_map)
    }
    Array(a) => Array(compile_array(a, source_path))
    Import(_) =>
      raise ImportError("imports require a resolver; use compile_with_imports")
    BlockScalar(_, m) => {
      // For arrays, just use the map part (label is ignored in array context)
      let ir_map = Map::from_ast(m, source_path~)
      compile_map_nodes(ir_map, m, m.nodes, source_path~)
      Map(ir_map)
    }
  }
}

///|
fn compile_scalar(scalar : @ast.Scalar, source_path : String?) -> Scalar {
  match scalar {
    Null(_r) => Scalar::from_ast(Scalar(scalar), Null, source_path~)
    Boolean(_r, b) =>
      Scalar::from_ast(
        Scalar(scalar),
        Bool(if b { "true" } else { "false" }),
        source_path~,
      )
    Number(_r, n) => Scalar::from_ast(Scalar(scalar), Number(n), source_path~)
    String(sv) => Scalar::from_ast(StringValue(sv), String(sv), source_path~)
  }
}
