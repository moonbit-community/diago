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
/// Import Resolution for diago IR
///
/// Handles file import statements.
/// Imports are resolved by a user-provided resolver function.

///|
/// Import resolver function type
/// Takes an import path and returns the file content, or None if not found
pub struct ImportResolver((String) -> String?)

///|
/// Create a new import resolver from a function
pub fn ImportResolver::new(f : (String) -> String?) -> ImportResolver {
  ImportResolver(f)
}

///|
/// Compile an AST Map with import resolution
pub fn compile_with_imports(
  ast : @ast.Map,
  resolver : ImportResolver,
) -> Map raise CompileError {
  let ir = Map::from_ast(ast)
  compile_map_non_glob_nodes_with_imports(ir, ast, ast.nodes, [], resolver, [])
  resolve_boards_with_imports(ir, resolver)
  compile_map_glob_nodes_with_imports(ir, ast, ast.nodes, [], resolver, [])
  // Resolve variable substitutions
  ir.resolve_substitutions()
  apply_suspensions(ir)
  ir.reindex_paths()
}

///|
fn compile_map_nodes_with_imports(
  ir : Map,
  scope_ast : @ast.Map,
  nodes : Array[@ast.MapNode],
  scope_frames : Array[CompileScopeFrame],
  resolver : ImportResolver,
  import_stack : Array[String],
  source_path? : String? = None,
) -> Unit raise CompileError {
  compile_map_non_glob_nodes_with_imports(
    ir,
    scope_ast,
    nodes,
    scope_frames,
    resolver,
    import_stack,
    source_path~,
  )
  compile_map_glob_nodes_with_imports(
    ir,
    scope_ast,
    nodes,
    scope_frames,
    resolver,
    import_stack,
    source_path~,
  )
}

///|
fn compile_map_non_glob_nodes_with_imports(
  ir : Map,
  scope_ast : @ast.Map,
  nodes : Array[@ast.MapNode],
  scope_frames : Array[CompileScopeFrame],
  resolver : ImportResolver,
  import_stack : Array[String],
  source_path? : String? = None,
) -> Unit raise CompileError {
  for node in nodes {
    match node {
      Comment(_, _) => ()
      BlockComment(_, _) => ()
      Substitution(sub) =>
        ir.add_field(
          Field::new("", Some(substitution_scalar(sub, source_path)), None, []),
        )
      Import(imp) => compile_import(ir, imp, resolver, import_stack)
      Key(key) =>
        if !key_uses_glob(key) {
          compile_key_with_imports(
            ir, key, scope_ast, scope_frames, resolver, import_stack, source_path,
          )
        }
    }
  }
}

///|
fn compile_map_glob_nodes_with_imports(
  ir : Map,
  scope_ast : @ast.Map,
  nodes : Array[@ast.MapNode],
  scope_frames : Array[CompileScopeFrame],
  resolver : ImportResolver,
  import_stack : Array[String],
  source_path? : String? = None,
) -> Unit raise CompileError {
  for node in nodes {
    match node {
      Key(key) =>
        if key_uses_glob(key) {
          compile_key_with_imports(
            ir, key, scope_ast, scope_frames, resolver, import_stack, source_path,
          )
        }
      _ => ()
    }
  }
}

///|
/// Compile an import statement
fn compile_import(
  ir : Map,
  imp : @ast.Import,
  resolver : ImportResolver,
  import_stack : Array[String],
) -> Unit raise CompileError {
  let (_, _, display) = split_import_file_and_selector(imp)
  let (import_ir, selector) = compile_import_target(imp, resolver, import_stack)
  if imp.spread {
    // Spread import in map context: only maps are allowed.
    let m2 = select_map_for_spread(import_ir, selector) catch {
      _ => raise ImportError("cannot spread import non map into map")
    }
    merge_into_map(ir, m2)
    return
  }

  // Non-spread import at map node level: create field named by the imported file key.
  let (primary, composite) = select_primary_and_composite(import_ir, selector)
  let field_name = extract_filename(display)
  let field0 = ir.ensure_field(field_name)
  ir.set_field(
    Field::new(
      field0.name,
      primary,
      composite,
      field0.references,
      name_syntax=field0.name_syntax(),
    ),
  )
}

///|
fn compile_import_target(
  imp : @ast.Import,
  resolver : ImportResolver,
  import_stack : Array[String],
) -> (Map, Array[@ast.StringValue]) raise CompileError {
  let (file_key, selector, display) = split_import_file_and_selector(imp)
  let (content, canonical) = resolve_import_content(resolver, file_key) catch {
    _ => raise ImportError("could not resolve import '\{display}'")
  }
  if contains(import_stack, canonical) {
    raise ImportError(
      "detected cyclic import chain: \{format_cycle(import_stack, canonical)}",
    )
  }
  let stack2 = import_stack.copy()
  stack2.push(canonical)
  let (import_ast, errors) = @parser.parse(content)
  if !errors.is_empty() {
    raise ImportError("parse error in imported file '\{display}': \{errors}")
  }
  let import_ir = Map::from_ast(import_ast, source_path=Some(canonical))
  compile_map_nodes_with_imports(
    import_ir,
    import_ast,
    import_ast.nodes,
    [],
    resolver,
    stack2,
    source_path=Some(canonical),
  )
  (with_import_ast_map(import_ir, Import(imp)), selector)
}

///|
fn split_import_file_and_selector(
  imp : @ast.Import,
) -> (String, Array[@ast.StringValue], String) {
  // `@a.b.c` means: import file "a", then select path ["b", "c"].
  // The resolver key is the file part only.
  let file = if imp.path.length() > 0 {
    join_import_pre(imp.pre, imp.path[0].content())
  } else {
    join_import_pre(imp.pre, "")
  }
  let selector : Array[@ast.StringValue] = []
  for i = 1; i < imp.path.length(); i = i + 1 {
    selector.push(imp.path[i])
  }
  let display = if selector.length() == 0 {
    file
  } else {
    let selector_parts : Array[String] = []
    for part in selector {
      selector_parts.push(part.content())
    }
    file + "." + selector_parts.join(".")
  }
  (file, selector, display)
}

///|
fn join_import_pre(pre : String, file : String) -> String {
  let combined = pre + file
  let is_abs = combined.length() > 0 && combined.to_array()[0] == '/'
  let parts : Array[String] = []
  for seg in combined.split("/").collect() {
    let s = seg.to_owned()
    if s == "" || s == "." {
      continue
    }
    if s == ".." {
      if parts.length() > 0 && parts[parts.length() - 1] != ".." {
        let _ = parts.pop()
      } else if !is_abs {
        parts.push("..")
      }
      continue
    }
    parts.push(s)
  }
  let joined = parts.join("/")
  if is_abs {
    if joined == "" {
      "/"
    } else {
      "/" + joined
    }
  } else {
    joined
  }
}

///|
fn resolve_import_content(
  resolver : ImportResolver,
  file_key : String,
) -> (String, String) raise CompileError {
  match (resolver.0)(file_key) {
    Some(content) => (content, file_key)
    None =>
      if file_key.has_suffix(".d2") {
        raise ImportError("missing import")
      } else {
        let k2 = file_key + ".d2"
        match (resolver.0)(k2) {
          Some(content) => (content, k2)
          None => raise ImportError("missing import")
        }
      }
  }
}

///|
fn contains(arr : Array[String], s : String) -> Bool {
  for x in arr {
    if x == s {
      return true
    }
  }
  false
}

///|
fn format_cycle(stack : Array[String], next : String) -> String {
  let parts = stack.copy()
  parts.push(next)
  parts.join(" -> ")
}

///|
fn select_primary_and_composite(
  root : Map,
  selector : Array[@ast.StringValue],
) -> (Scalar?, Composite?) raise CompileError {
  if selector.length() == 0 {
    return (None, Some(Map(root)))
  }
  let f = select_field(root, selector)
  (f.primary, f.composite)
}

///|
fn select_map_for_spread(
  root : Map,
  selector : Array[@ast.StringValue],
) -> Map raise CompileError {
  if selector.length() == 0 {
    return root
  }
  let f = select_field(root, selector)
  match f.composite {
    Some(Map(m)) => m
    _ => raise ImportError("not a map")
  }
}

///|
fn select_field(
  root : Map,
  selector : Array[@ast.StringValue],
) -> Field raise CompileError {
  let mut current = root
  for i = 0; i < selector.length(); i = i + 1 {
    match current.get_field_by_syntax(selector[i]) {
      Some(f) =>
        if i == selector.length() - 1 {
          return f
        } else {
          match f.composite {
            Some(Map(m)) => current = m
            _ => raise ImportError("not a map")
          }
        }
      None => raise ImportError("not found")
    }
  }
  raise ImportError("not found")
}

///|
fn merge_into_map(dst : Map, src : Map) -> Unit {
  for f in src.fields {
    dst.set_field(f)
  }
  for e in src.edges {
    dst.set_edge(e)
  }
}

///|
/// Extract filename without extension from path
fn extract_filename(path : String) -> String {
  // Find last /
  let mut last_slash = -1
  for i in 0..<path.length() {
    if path.code_unit_at(i) == '/'.to_int().to_uint16() {
      last_slash = i
    }
  }
  let start = last_slash + 1
  // Find last .
  let mut last_dot = path.length()
  for i in start..<path.length() {
    if path.code_unit_at(i) == '.'.to_int().to_uint16() {
      last_dot = i
    }
  }
  // Extract filename
  let buf = StringBuilder()
  for i in start..<last_dot {
    buf.write_char(path.code_unit_at(i).to_int().unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Compile a key with import handling for values
fn compile_key_with_imports(
  ir : Map,
  key : @ast.Key,
  scope_ast : @ast.Map,
  scope_frames : Array[CompileScopeFrame],
  resolver : ImportResolver,
  import_stack : Array[String],
  source_path : String?,
) -> Unit raise CompileError {
  // Handle ampersand filters
  if key.ampersand || key.not_ampersand {
    return
  }
  // Handle edges first
  if key.edges.length() > 0 {
    compile_edges_with_imports(
      ir, key, scope_ast, scope_frames, resolver, import_stack, source_path,
    )
    return
  }
  // Handle regular key
  guard key.key is Some(key_path) else { return }
  // Check for glob pattern
  if key_path.has_glob() {
    compile_glob_key_with_imports(
      ir, key_path, key, scope_ast, resolver, import_stack, source_path,
    )
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
  // Set value (with import handling)
  let field = match key.value {
    Some(value) =>
      compile_value_with_imports(
        field, value, current_map, current_frames, resolver, import_stack, source_path,
      )
    None => field
  }
  current_map.set_field(field)
}

///|
fn compile_glob_key_with_imports(
  ir : Map,
  key_path : @ast.KeyPath,
  key : @ast.Key,
  scope_ast : @ast.Map,
  resolver : ImportResolver,
  import_stack : Array[String],
  source_path : String?,
) -> Unit raise CompileError {
  let (pattern, glob_index) = extract_glob_and_path(key_path)
  if pattern.length() == 0 || glob_index < 0 {
    return
  }
  let filters = collect_filters_from_value(key)
  let suspension = key_suspension(key)
  let properties = if glob_index == key_path.path.length() - 1 {
    let properties = Map::new()
    match key.value {
      Some(Map(value_map)) =>
        for node in value_map.nodes {
          match node {
            Key(property_key) =>
              if !property_key.ampersand &&
                !property_key.not_ampersand &&
                !key_uses_glob(property_key) {
                compile_key_with_imports(
                  properties,
                  property_key,
                  value_map,
                  [],
                  resolver,
                  import_stack,
                  source_path,
                )
              }
            _ => ()
          }
        }
      _ => ()
    }
    properties
  } else {
    let context = RefContext::new(
      None,
      Some(key),
      Some(scope_ast),
      source_path~,
    )
    build_nested_properties(key_path, glob_index, key, context, source_path)
  }
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
  // Keep this ordering aligned with `compile_glob_key`: applying a parent
  // clones its composite map, so descendants must be updated first.
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
            let context = RefContext::new(
              None,
              Some(key),
              Some(scope_ast),
              source_path~,
            )
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
          apply_nested_globs_with_imports(
            updated,
            key.value,
            resolver,
            import_stack,
            source_path,
          )
        }
      }
    }
    target_index = target_index - 1
  }
}

///|
fn apply_nested_globs_with_imports(
  field : Field,
  value : @ast.Value?,
  resolver : ImportResolver,
  import_stack : Array[String],
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
          compile_key_with_imports(
            field_map,
            nested_key,
            ast_map,
            [],
            resolver,
            import_stack,
            source_path,
          )
        }
      _ => ()
    }
  }
}

///|
fn compile_value_with_imports(
  field : Field,
  value : @ast.Value,
  parent_map : Map,
  scope_frames : Array[CompileScopeFrame],
  resolver : ImportResolver,
  import_stack : Array[String],
  source_path : String?,
) -> Field raise CompileError {
  match value {
    Scalar(s) =>
      Field::new(
        field.name,
        Some(compile_scalar(s, source_path)),
        field.composite,
        field.references,
        name_syntax=field.name_syntax(),
      )
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
      compile_map_nodes_with_imports(
        ir_map,
        m,
        m.nodes,
        nested_frames,
        resolver,
        import_stack,
        source_path~,
      )
      Field::new(
        field.name,
        field.primary,
        Some(Map(ir_map)),
        field.references,
        name_syntax=field.name_syntax(),
      )
    }
    Array(a) => {
      let ir_array = compile_array_with_imports(
        a, resolver, import_stack, source_path,
      )
      Field::new(
        field.name,
        field.primary,
        Some(Array(ir_array)),
        field.references,
        name_syntax=field.name_syntax(),
      )
    }
    Import(imp) => {
      let (import_ir, selector) = compile_import_target(
        imp, resolver, import_stack,
      )
      let (primary, composite) = select_primary_and_composite(
        import_ir, selector,
      )
      Field::new(
        field.name,
        primary,
        composite,
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
      compile_map_nodes_with_imports(
        ir_map,
        m,
        m.nodes,
        nested_frames,
        resolver,
        import_stack,
        source_path~,
      )
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
fn compile_array_with_imports(
  arr : @ast.ArrayValue,
  resolver : ImportResolver,
  import_stack : Array[String],
  source_path : String?,
) -> IRArray raise CompileError {
  let values : Array[Value] = []
  for node in arr.nodes {
    match node {
      Comment(_, _) => ()
      BlockComment(_, _) => ()
      Substitution(sub) =>
        values.push(Scalar(substitution_scalar(sub, source_path)))
      Import(imp) => {
        let (import_ir, selector) = compile_import_target(
          imp, resolver, import_stack,
        )
        if imp.spread {
          // Only allow spreading arrays into arrays (reference behavior).
          let f = select_field(import_ir, selector)
          match f.composite {
            Some(Array(a)) =>
              for v in a.values {
                values.push(v)
              }
            _ => raise ImportError("can only spread import array into array")
          }
        } else {
          let (primary, composite) = select_primary_and_composite(
            import_ir, selector,
          )
          match (primary, composite) {
            (Some(p), _) => values.push(Scalar(p))
            (None, Some(Map(m))) => values.push(Map(m))
            (None, Some(Array(a))) => values.push(Array(a))
            (None, None) => ()
          }
        }
      }
      Value(v) => {
        let compiled = compile_ast_value_with_imports(
          v, resolver, import_stack, source_path,
        )
        values.push(compiled)
      }
    }
  }
  IRArray::from_ast(arr, values, source_path~)
}

///|
fn compile_ast_value_with_imports(
  value : @ast.Value,
  resolver : ImportResolver,
  import_stack : Array[String],
  source_path : String?,
) -> Value raise CompileError {
  match value {
    Scalar(s) => Scalar(compile_scalar(s, source_path))
    Map(m) => {
      let ir_map = Map::from_ast(m, source_path~)
      compile_map_nodes_with_imports(
        ir_map,
        m,
        m.nodes,
        [],
        resolver,
        import_stack,
        source_path~,
      )
      Map(ir_map)
    }
    Array(a) =>
      Array(compile_array_with_imports(a, resolver, import_stack, source_path))
    Import(imp) => {
      let (import_ir, selector) = compile_import_target(
        imp, resolver, import_stack,
      )
      let (primary, composite) = select_primary_and_composite(
        import_ir, selector,
      )
      match (primary, composite) {
        (Some(p), _) => Scalar(p)
        (None, Some(Map(m))) => Map(m)
        (None, Some(Array(a))) => Array(a)
        (None, None) => Scalar(Scalar::null())
      }
    }
    BlockScalar(_, m) => {
      let ir_map = Map::from_ast(m, source_path~)
      compile_map_nodes_with_imports(
        ir_map,
        m,
        m.nodes,
        [],
        resolver,
        import_stack,
        source_path~,
      )
      Map(ir_map)
    }
  }
}

///|
fn compile_edges_with_imports(
  scope_ir : Map,
  key : @ast.Key,
  scope_ast : @ast.Map,
  scope_frames : Array[CompileScopeFrame],
  resolver : ImportResolver,
  import_stack : Array[String],
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
      resolver : ImportResolver,
      import_stack : Array[String],
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
          compile_map_nodes_with_imports(
            ir_map,
            m,
            m.nodes,
            [],
            resolver,
            import_stack,
            source_path~,
          )
          (None, Some(ir_map))
        }
        Some(BlockScalar(label, m)) => {
          let primary = match label {
            Scalar(s) => Some(compile_scalar(s, source_path))
            _ => None
          }
          let ir_map = Map::from_ast(m, source_path~)
          compile_map_nodes_with_imports(
            ir_map,
            m,
            m.nodes,
            [],
            resolver,
            import_stack,
            source_path~,
          )
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
          resolver,
          import_stack,
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
        match key.edge_index {
          Some(ei) =>
            if ei.glob {
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
                let (primary, edge_map) = compile_edge_value(
                  Some(e),
                  key.value,
                  resolver,
                  import_stack,
                )
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
                    resolver,
                    import_stack,
                  )
                  ir.set_edge(Edge::new(e.id, primary, edge_map, e.references))
                }
                None => {
                  let (primary, edge_map) = compile_edge_value(
                    None,
                    key.value,
                    resolver,
                    import_stack,
                  )
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
            let (primary, edge_map) = compile_edge_value(
              None,
              key.value,
              resolver,
              import_stack,
            )
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
