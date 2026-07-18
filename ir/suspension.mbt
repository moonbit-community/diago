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
fn field_suspension(field : Field) -> Bool? {
  let mut state : Bool? = None
  for reference in field.references {
    match reference.context() {
      Some(context) =>
        match context.key {
          Some(key) =>
            match key_suspension(key) {
              Some(value) => state = Some(value)
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  state
}

///|
fn edge_suspension(edge : Edge) -> Bool? {
  let mut state : Bool? = None
  for reference in edge.references {
    match reference.context() {
      Some(context) =>
        match context.key {
          Some(key) =>
            match key_suspension(key) {
              Some(value) => state = Some(value)
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  state
}

///|
fn suspension_path_key(path : Array[String]) -> String {
  let out = StringBuilder::new()
  for segment in path {
    out.write_string(segment.length().to_string())
    out.write_char(':')
    out.write_string(segment)
    out.write_char(';')
  }
  out.to_string()
}

///|
fn append_suspension_path(
  prefix : Array[String],
  suffix : Array[String],
) -> Array[String] {
  let path = prefix.copy()
  for segment in suffix {
    path.push(segment)
  }
  path
}

///|
fn force_path_and_ancestors(
  forced : Array[String],
  path : Array[String],
) -> Unit {
  let prefix : Array[String] = []
  for segment in path {
    prefix.push(segment)
    let key = suspension_path_key(prefix)
    if !forced.contains(key) {
      forced.push(key)
    }
  }
}

///|
fn collect_unsuspended_edge_endpoints(
  ir : Map,
  prefix : Array[String],
  forced : Array[String],
) -> Unit {
  for edge in ir.edges {
    if edge_suspension(edge) == Some(false) {
      force_path_and_ancestors(
        forced,
        append_suspension_path(prefix, edge.id.src_path),
      )
      force_path_and_ancestors(
        forced,
        append_suspension_path(prefix, edge.id.dst_path),
      )
    }
  }
  for field in ir.fields {
    match field.composite {
      Some(Map(child)) => {
        let child_prefix = prefix.copy()
        child_prefix.push(field.name)
        collect_unsuspended_edge_endpoints(child, child_prefix, forced)
      }
      _ => ()
    }
  }
}

///|
fn remove_suspended_nodes(
  ir : Map,
  prefix : Array[String],
  forced : Array[String],
) -> Unit {
  for i = ir.fields.length() - 1; i >= 0; i = i - 1 {
    let field = ir.fields[i]
    let field_path = prefix.copy()
    field_path.push(field.name)
    if field_suspension(field) == Some(true) &&
      !forced.contains(suspension_path_key(field_path)) {
      let _ = ir.fields.remove(i)
      continue
    }
    match field.composite {
      Some(Map(child)) => remove_suspended_nodes(child, field_path, forced)
      _ => ()
    }
  }
  for i = ir.edges.length() - 1; i >= 0; i = i - 1 {
    let edge = ir.edges[i]
    if edge_suspension(edge) == Some(true) ||
      !suspension_endpoint_exists(ir, edge.id.src_path_syntax()) ||
      !suspension_endpoint_exists(ir, edge.id.dst_path_syntax()) {
      let _ = ir.edges.remove(i)
    }
  }
}

///|
fn suspension_endpoint_exists(ir : Map, path : Array[@ast.StringValue]) -> Bool {
  if path.is_empty() {
    return false
  }
  let mut current = ir
  for i, syntax in path {
    match current.get_field_by_syntax(syntax) {
      Some(field) =>
        if i == path.length() - 1 {
          return true
        } else {
          match field.composite {
            Some(Map(child)) => current = child
            _ => return false
          }
        }
      None => return false
    }
  }
  false
}

///|
fn apply_suspensions(ir : Map) -> Unit {
  let forced : Array[String] = []
  collect_unsuspended_edge_endpoints(ir, [], forced)
  remove_suspended_nodes(ir, [], forced)
}
