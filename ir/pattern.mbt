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
/// Glob patterns and filters for diago IR
///
/// Supports:
/// - Single glob (*): matches any characters at one level
/// - Double glob (**): matches all descendants recursively
/// - Triple glob (***): matches all descendants including boards
/// - Filters (&key: value): conditionally apply properties

///|
/// Reserved keywords that shouldn't be matched by globs
let reserved_keywords : Array[String] = [
  "label", "shape", "icon", "style", "width", "height", "top", "left", "near", "tooltip",
  "link", "class", "classes", "vars", "source-arrowhead", "target-arrowhead", "direction",
  "grid-rows", "grid-columns", "grid-gap", "horizontal-gap", "vertical-gap", "grid-column-span",
  "grid-row-span", "constraint", "layers", "scenarios", "steps",
]

///|
/// Board keywords (for triple glob)
let board_keywords : Array[String] = ["layers", "scenarios", "steps"]

///|
/// Check if a keyword is reserved
pub fn is_reserved_keyword(name : String) -> Bool {
  let lower = name.to_lower()
  for kw in reserved_keywords {
    if kw == lower {
      return true
    }
  }
  false
}

///|
/// Check if a keyword is a board keyword
pub fn is_board_keyword(name : String) -> Bool {
  let lower = name.to_lower()
  for kw in board_keywords {
    if kw == lower {
      return true
    }
  }
  false
}

///|
/// Check if pattern represents a double glob (**)
/// Parser stores ** as ["*", "", "*"]
pub fn is_double_glob(pattern : Array[String]) -> Bool {
  if pattern.length() == 1 && pattern[0] == "**" {
    return true
  }
  // Parser format: ["*", "", "*"]
  if pattern.length() == 3 &&
    pattern[0] == "*" &&
    pattern[1] == "" &&
    pattern[2] == "*" {
    return true
  }
  false
}

///|
/// Check if pattern represents a triple glob (***)
/// Parser stores *** as ["*", "", "*", "", "*"]
pub fn is_triple_glob(pattern : Array[String]) -> Bool {
  if pattern.length() == 1 && pattern[0] == "***" {
    return true
  }
  // Parser format: ["*", "", "*", "", "*"]
  if pattern.length() == 5 &&
    pattern[0] == "*" &&
    pattern[1] == "" &&
    pattern[2] == "*" &&
    pattern[3] == "" &&
    pattern[4] == "*" {
    return true
  }
  false
}

///|
/// Collect all fields matching a double glob (**) pattern
/// This recursively collects all descendant fields except board keywords
pub fn Map::double_glob(self : Map) -> Array[Field] {
  let result : Array[Field] = []
  self.double_glob_helper(result)
  result
}

///|
fn Map::double_glob_helper(self : Map, result : Array[Field]) -> Unit {
  for f in self.fields {
    // Skip reserved keywords (but check if it's a board keyword)
    if f.is_reserved_keyword_name() {
      if f.is_board_keyword_name() {
        // Skip board keywords entirely for double glob
        continue
      }
      // For other reserved keywords, descend but don't add
      match f.composite {
        Some(Map(m)) => m.double_glob_helper(result)
        _ => ()
      }
      continue
    }
    // Add this field
    result.push(f)
    // Recursively collect from children
    match f.composite {
      Some(Map(m)) => m.double_glob_helper(result)
      _ => ()
    }
  }
}

///|
/// Collect all fields matching a triple glob (***) pattern
/// This recursively collects all descendant fields including boards
pub fn Map::triple_glob(self : Map) -> Array[Field] {
  let result : Array[Field] = []
  self.triple_glob_helper(result)
  result
}

///|
fn Map::triple_glob_helper(self : Map, result : Array[Field]) -> Unit {
  for f in self.fields {
    if f.is_board_keyword_name() {
      match f.composite {
        Some(Map(boards)) =>
          for board in boards.fields {
            match board.composite {
              Some(Map(board_map)) => board_map.triple_glob_helper(result)
              _ => ()
            }
          }
        _ => ()
      }
      continue
    }
    // Skip non-board reserved keywords
    if f.is_reserved_keyword_name() {
      match f.composite {
        Some(Map(m)) => m.triple_glob_helper(result)
        _ => ()
      }
      continue
    }
    result.push(f)
    // Recursively collect from children
    match f.composite {
      Some(Map(m)) => m.triple_glob_helper(result)
      _ => ()
    }
  }
}

///|
/// Collect fields matching a multi-glob pattern (** or ***)
/// Returns (fields, is_glob_pattern)
pub fn Map::multi_glob(
  self : Map,
  pattern : Array[String],
) -> (Array[Field], Bool) {
  if is_double_glob(pattern) {
    (self.double_glob(), true)
  } else if is_triple_glob(pattern) {
    (self.triple_glob(), true)
  } else {
    ([], false)
  }
}

///|
/// Match a string against a glob pattern
/// Pattern is an array where elements are either:
/// - literal text to match
/// - "*" to match any characters
pub fn match_pattern(s : String, pattern : Array[String]) -> Bool {
  match_pattern_inner(s, pattern, false)
}

///|
fn match_pattern_inner(
  s : String,
  pattern : Array[String],
  allow_reserved : Bool,
) -> Bool {
  if !allow_reserved && is_reserved_keyword(s) {
    return false
  }
  if pattern.length() == 0 {
    return true
  }
  let s_lower = s.to_lower()
  let mut remaining = s_lower
  let mut i = 0
  while i < pattern.length() {
    if pattern[i] == "*" {
      // Wildcard: match next literal if there is one
      if i != pattern.length() - 1 {
        let next_pattern = pattern[i + 1].to_lower()
        match string_index_of(remaining, next_pattern) {
          Some(j) => {
            remaining = string_substring(remaining, j + next_pattern.length())
            i = i + 2
          }
          None => return false
        }
      } else {
        // Trailing *, matches everything remaining
        i = i + 1
      }
    } else {
      // Literal match at start of remaining
      let pattern_lower = pattern[i].to_lower()
      if !remaining.has_prefix(pattern_lower) {
        return false
      }
      remaining = string_substring(remaining, pattern_lower.length())
      i = i + 1
    }
  }
  true
}

///|
/// Find index of substring in string (case-sensitive)
fn string_index_of(s : String, sub : String) -> Int? {
  if sub.length() == 0 {
    return Some(0)
  }
  if s.length() < sub.length() {
    return None
  }
  for i in 0..<(s.length() - sub.length() + 1) {
    let mut matches = true
    for j in 0..<sub.length() {
      if s.code_unit_at(i + j) != sub.code_unit_at(j) {
        matches = false
        break
      }
    }
    if matches {
      return Some(i)
    }
  }
  None
}

///|
/// Get substring from start index
fn string_substring(s : String, start : Int) -> String {
  if start >= s.length() {
    return ""
  }
  let buf = StringBuilder::new()
  for i in start..<s.length() {
    let code = s.code_unit_at(i).to_int()
    buf.write_char(code.unsafe_to_char())
  }
  buf.to_string()
}

///|
/// Collect fields at one level matching a single glob pattern
pub fn Map::single_glob(self : Map, pattern : Array[String]) -> Array[Field] {
  let result : Array[Field] = []
  for f in self.fields {
    if f.is_reserved_keyword_name() {
      continue
    }
    if match_pattern_inner(f.name, pattern, true) {
      result.push(f)
    }
  }
  result
}

///|
priv struct GlobTarget {
  field : Field
  parent_map : Map
  level : Int
}

///|
fn Map::glob_targets(self : Map, pattern : Array[String]) -> Array[GlobTarget] {
  let targets : Array[GlobTarget] = []
  if is_double_glob(pattern) {
    self.collect_multi_glob_targets(targets, false, 0)
  } else if is_triple_glob(pattern) {
    self.collect_multi_glob_targets(targets, true, 0)
  } else {
    for field in self.single_glob(pattern) {
      targets.push({ field, parent_map: self, level: 0 })
    }
  }
  targets
}

///|
fn Map::collect_multi_glob_targets(
  self : Map,
  targets : Array[GlobTarget],
  include_boards : Bool,
  level : Int,
) -> Unit {
  let snapshot = self.fields.copy()
  for field in snapshot {
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
                  board_map.collect_multi_glob_targets(
                    targets, include_boards, 0,
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
      if field.name == "vars" && !include_boards {
        match child_map {
          Some(map) =>
            map.collect_multi_glob_targets(targets, include_boards, level)
          None => ()
        }
      }
      continue
    }
    targets.push({ field, parent_map: self, level })
    match child_map {
      Some(map) =>
        map.collect_multi_glob_targets(targets, include_boards, level + 1)
      None => ()
    }
  }
}

///|
/// Filter context for evaluating ampersand filters
pub struct FilterContext {
  /// Current field being filtered
  field : Field
  /// Parent map containing the field
  parent_map : Map
}

///|
pub fn FilterContext::new(field : Field, parent_map : Map) -> FilterContext {
  { field, parent_map }
}

///|
/// Evaluate a filter condition against a field
/// Returns true if the field passes the filter
pub fn evaluate_filter(
  ctx : FilterContext,
  filter_key : String,
  filter_value : String,
) -> Bool {
  evaluate_filter_at_level(ctx, filter_key, filter_value, 0)
}

///|
fn evaluate_filter_at_level(
  ctx : FilterContext,
  filter_key : String,
  filter_value : String,
  level : Int,
) -> Bool {
  // Check simple property filters
  match filter_key.to_lower() {
    "level" => filter_value_matches(level.to_string(), filter_value)
    "shape" =>
      // Match against shape property
      match get_field_property(ctx.field, "shape") {
        Some(v) => filter_value_matches(v, filter_value)
        None => filter_value_matches("rectangle", filter_value) // default shape
      }
    "label" =>
      // Match against primary value (label)
      match ctx.field.primary {
        Some(s) => filter_value_matches(s.to_string(), filter_value)
        None =>
          filter_value == "" ||
          filter_value_matches(ctx.field.name, filter_value)
      }
    "class" =>
      match field_property(ctx.field, "class") {
        Some(class_field) =>
          field_contains_filter_value(class_field, filter_value)
        None => false
      }
    "connected" =>
      filter_value_matches(
        if field_is_connected(ctx.field, ctx.parent_map) {
          "true"
        } else {
          "false"
        },
        filter_value,
      )
    "leaf" =>
      filter_value_matches(
        if field_is_leaf(ctx.field) {
          "true"
        } else {
          "false"
        },
        filter_value,
      )
    "opacity" =>
      match get_field_property(ctx.field, "opacity") {
        Some(v) => filter_value_matches(v, filter_value)
        None => filter_value_matches("1", filter_value) // default opacity
      }
    "stroke-width" =>
      match get_field_property(ctx.field, "stroke-width") {
        Some(v) => filter_value_matches(v, filter_value)
        None => filter_value_matches("2", filter_value) // default stroke-width
      }
    "border-radius" | "stroke-dash" =>
      match get_field_property(ctx.field, filter_key) {
        Some(v) => filter_value_matches(v, filter_value)
        None => filter_value_matches("0", filter_value) // default
      }
    "shadow" | "multiple" | "3d" | "animated" | "filled" =>
      match get_field_property(ctx.field, filter_key) {
        Some(v) => filter_value_matches(v, filter_value)
        None => filter_value_matches("false", filter_value) // default
      }
    "icon" | "tooltip" | "link" =>
      match get_field_property(ctx.field, filter_key) {
        Some(v) => filter_value_matches(v, filter_value)
        None => filter_value == "" // absent properties do not satisfy wildcards
      }
    _ =>
      // Try to find the property in the field's map
      match get_field_property(ctx.field, filter_key) {
        Some(v) => filter_value_matches(v, filter_value)
        None => false
      }
  }
}

///|
pub fn filter_value_matches(actual : String, pattern : String) -> Bool {
  let actual = actual.to_lower()
  let pattern = pattern.to_lower()
  let mut actual_index = 0
  let mut pattern_index = 0
  let mut star_index = -1
  let mut star_match_index = 0
  while actual_index < actual.length() {
    if pattern_index < pattern.length() &&
      pattern.code_unit_at(pattern_index) != '*'.to_int().to_uint16() &&
      pattern.code_unit_at(pattern_index) == actual.code_unit_at(actual_index) {
      actual_index = actual_index + 1
      pattern_index = pattern_index + 1
    } else if pattern_index < pattern.length() &&
      pattern.code_unit_at(pattern_index) == '*'.to_int().to_uint16() {
      star_index = pattern_index
      star_match_index = actual_index
      pattern_index = pattern_index + 1
    } else if star_index >= 0 {
      pattern_index = star_index + 1
      star_match_index = star_match_index + 1
      actual_index = star_match_index
    } else {
      return false
    }
  }
  while pattern_index < pattern.length() &&
        pattern.code_unit_at(pattern_index) == '*'.to_int().to_uint16() {
    pattern_index = pattern_index + 1
  }
  pattern_index == pattern.length()
}

///|
fn field_contains_filter_value(field : Field, filter_value : String) -> Bool {
  match field.primary {
    Some(value) =>
      if filter_value_matches(value.to_string(), filter_value) {
        return true
      }
    None => ()
  }
  match field.composite {
    Some(Array(array)) =>
      for value in array.values {
        match value {
          Scalar(scalar) =>
            if filter_value_matches(scalar.to_string(), filter_value) {
              return true
            }
          _ => ()
        }
      }
    _ => ()
  }
  false
}

///|
fn field_is_connected(field : Field, parent_map : Map) -> Bool {
  for edge in parent_map.edges {
    if (
        !edge.id.src_path.is_empty() &&
        edge.id.src_path[0].to_lower() == field.name.to_lower()
      ) ||
      (
        !edge.id.dst_path.is_empty() &&
        edge.id.dst_path[0].to_lower() == field.name.to_lower()
      ) {
      return true
    }
  }
  false
}

///|
fn field_is_leaf(field : Field) -> Bool {
  match field.composite {
    Some(Map(map)) =>
      for child in map.fields {
        if !child.is_reserved_keyword_name() {
          return false
        }
      }
    _ => ()
  }
  true
}

///|
fn field_property(field : Field, key : String) -> Field? {
  match field.composite {
    Some(Map(map)) => field_property_in_map(map, key)
    _ => None
  }
}

///|
fn field_property_in_map(map : Map, key : String) -> Field? {
  let parts = key.split(".").collect()
  let mut current = map
  for i, part in parts {
    guard current.get_field(part.to_owned()) is Some(field) else {
      if parts.length() == 1 {
        guard current.get_field("style") is Some(style_field) else {
          return None
        }
        guard style_field.composite is Some(Map(style_map)) else { return None }
        return style_map.get_field(part.to_owned())
      }
      return None
    }
    if i == parts.length() - 1 {
      return Some(field)
    }
    match field.composite {
      Some(Map(next)) => current = next
      _ => return None
    }
  }
  None
}

///|
/// Get a scalar property value from a field's composite map.
fn get_field_property(field : Field, key : String) -> String? {
  match field_property(field, key) {
    Some(property) =>
      match property.primary {
        Some(value) => Some(value.to_string())
        None => None
      }
    None => None
  }
}

///|
/// Apply properties to fields matching a glob pattern
/// If filters are provided, only apply to fields that pass all filters
pub fn Map::apply_glob_properties(
  self : Map,
  pattern : Array[String],
  properties : Map,
  filters : Array[(Bool, String, String)],
) -> Unit {
  if is_double_glob(pattern) {
    self.apply_multi_glob_properties(properties, filters, false)
    return
  }
  if is_triple_glob(pattern) {
    self.apply_multi_glob_properties(properties, filters, true)
    return
  }

  // Single-level glob: apply only within this map
  let fields = self.single_glob(pattern)
  for f in fields {
    let ctx = FilterContext::new(f, self)
    let mut passes_all = true
    for filter in filters {
      let (negated, key, value) = filter
      let result = evaluate_filter(ctx, key, value)
      let passes = if negated { !result } else { result }
      if !passes {
        passes_all = false
        break
      }
    }
    if passes_all {
      let updated = apply_properties_to_field(f, properties)
      self.set_field(updated)
    }
  }
}

///|
/// Apply properties recursively for **/*** patterns.
/// `include_boards` matches the *** behavior: descend into boards but do not
/// apply to reserved keywords, and do not apply to the board field itself.
fn Map::apply_multi_glob_properties(
  self : Map,
  properties : Map,
  filters : Array[(Bool, String, String)],
  include_boards : Bool,
) -> Unit {
  // Snapshot fields so newly added properties (like `style`) aren't re-visited.
  let snapshot : Array[Field] = []
  for f in self.fields {
    snapshot.push(f)
  }
  for f in snapshot {
    // Capture original children before any mutation.
    let child_map = match f.composite {
      Some(Map(m)) => Some(m)
      _ => None
    }
    if include_boards {
      // Triple glob (***): descend into boards, but don't apply to reserved keywords.
      if f.is_board_keyword_name() {
        match child_map {
          Some(boards) =>
            for board in boards.fields {
              match board.composite {
                Some(Map(board_map)) =>
                  board_map.apply_multi_glob_properties(
                    properties, filters, include_boards,
                  )
                _ => ()
              }
            }
          None => ()
        }
        continue
      }
      if f.is_reserved_keyword_name() {
        continue
      }
      // Double glob (**): don't apply to reserved keywords (including `style`).
    } else if f.is_reserved_keyword_name() {
      match child_map {
        Some(m) =>
          m.apply_multi_glob_properties(properties, filters, include_boards)
        None => ()
      }
      continue
    }

    // Apply properties to this field if it passes filters.
    let ctx = FilterContext::new(f, self)
    let mut passes_all = true
    for filter in filters {
      let (negated, key, value) = filter
      let result = evaluate_filter(ctx, key, value)
      let passes = if negated { !result } else { result }
      if !passes {
        passes_all = false
        break
      }
    }
    if passes_all {
      let updated = apply_properties_to_field(f, properties)
      self.set_field(updated)
    }

    // Descend into original children (not newly added properties).
    match child_map {
      Some(m) =>
        m.apply_multi_glob_properties(properties, filters, include_boards)
      None => ()
    }
  }
}

///|
fn clone_value_for_properties(v : Value) -> Value {
  match v {
    Scalar(s) => Scalar(s)
    Array(a) => Array(clone_irarray_for_properties(a))
    Map(m) => Map(clone_map_for_properties(m))
  }
}

///|
fn clone_irarray_for_properties(a : IRArray) -> IRArray {
  let values : Array[Value] = []
  for v in a.values {
    values.push(clone_value_for_properties(v))
  }
  { values, ast: a.ast, source_path: a.source_path, path: a.path }
}

///|
fn clone_composite_for_properties(c : Composite) -> Composite {
  match c {
    Array(a) => Array(clone_irarray_for_properties(a))
    Map(m) => Map(clone_map_for_properties(m))
  }
}

///|
fn clone_field_for_properties(f : Field) -> Field {
  let composite = match f.composite {
    Some(c) => Some(clone_composite_for_properties(c))
    None => None
  }
  {
    name: f.name,
    name_syntax: f.name_syntax(),
    primary: f.primary,
    composite,
    references: f.references.copy(),
    import_ast: f.import_ast,
    path: f.path,
  }
}

///|
fn clone_map_for_properties(m : Map) -> Map {
  let out : Map = {
    fields: [],
    edges: [],
    ast: m.ast,
    import_ast: m.import_ast,
    source_path: m.source_path,
    path: m.path,
  }
  for f in m.fields {
    out.add_field(clone_field_for_properties(f))
  }
  // Edges are not expected in property maps.
  out
}

///|
fn merge_properties_into_map(target : Map, src : Map) -> Unit {
  for prop in src.fields {
    let existing_field = match prop.name_syntax() {
      Some(name_syntax) => target.get_field_by_syntax(name_syntax)
      None => target.get_field(prop.name)
    }
    match existing_field {
      Some(existing) => {
        let prop_follows = glob_property_follows_existing(existing, prop)
        let primary = if prop.primary is Some(_) && prop_follows {
          prop.primary
        } else if prop.composite is Some(Array(_)) && prop_follows {
          None
        } else {
          existing.primary
        }
        let composite = match prop.composite {
          Some(Map(src_map)) =>
            match existing.composite {
              Some(Map(dst_map)) => {
                merge_properties_into_map(dst_map, src_map)
                existing.composite
              }
              _ => Some(Map(clone_map_for_properties(src_map)))
            }
          Some(other) =>
            if prop_follows {
              Some(clone_composite_for_properties(other))
            } else {
              existing.composite
            }
          None =>
            if prop.primary is Some(_) &&
              prop_follows &&
              existing.composite is Some(Array(_)) {
              None
            } else {
              existing.composite
            }
        }
        let updated = Field::new(
          existing.name,
          primary,
          composite,
          {
            let refs = existing.references.copy()
            for reference in prop.references {
              refs.push(reference)
            }
            refs
          },
          name_syntax=existing.name_syntax(),
        )
        target.set_field(updated)
      }
      None => target.add_field(clone_field_for_properties(prop))
    }
  }
}

///|
fn glob_property_follows_existing(existing : Field, prop : Field) -> Bool {
  guard prop.last_primary_ref() is Some(prop_ref) else { return true }
  guard existing.last_primary_ref() is Some(existing_ref) else { return true }
  let prop_context = prop_ref.context()
  let existing_context = existing_ref.context()
  match (prop_context, existing_context) {
    (Some(prop_context), Some(existing_context)) =>
      if prop_context.source_path != existing_context.source_path {
        return true
      }
    _ => ()
  }
  reference_operation_range(prop_ref).start.offset >=
  reference_operation_range(existing_ref).start.offset
}

///|
fn reference_operation_range(reference : Reference) -> @lexer.Range {
  if reference.due_to_glob() || reference.due_to_lazy_glob() {
    match reference.context() {
      Some(context) =>
        match context.key {
          Some(key) => return key.range
          None => ()
        }
      None => ()
    }
  }
  reference.range()
}

///|
/// Apply properties from a source map to a field
fn apply_properties_to_field(field : Field, properties : Map) -> Field {
  // Ensure field has a composite map
  let (field, field_map) = match field.composite {
    Some(Map(m)) => (field, m)
    None => {
      let m = Map::new()
      let field = Field::new(
        field.name,
        field.primary,
        Some(Map(m)),
        field.references,
        name_syntax=field.name_syntax(),
      )
      (field, m)
    }
    Some(_) => return field // Can't apply to arrays
  }
  // Copy properties
  merge_properties_into_map(field_map, properties)
  field
}
