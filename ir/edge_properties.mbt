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
fn edge_property_map(
  path : @ast.KeyPath,
  primary : Scalar?,
  value_map : Map?,
) -> Map {
  let root = Map::new()
  let mut current = root
  for i, segment in path.path {
    let child = if i == path.path.length() - 1 {
      value_map
    } else {
      Some(Map::new())
    }
    current.add_field(
      Field::new(
        segment.content(),
        if i == path.path.length() - 1 {
          primary
        } else {
          None
        },
        match child {
          Some(m) => Some(Map(m))
          None => None
        },
        [],
        name_syntax=Some(segment),
      ),
    )
    if i < path.path.length() - 1 {
      current = child.unwrap()
    }
  }
  root
}

///|
fn merge_edge_maps(base : Map?, patch : Map?, patch_overrides : Bool) -> Map? {
  match (base, patch) {
    (Some(base), Some(patch)) =>
      if patch_overrides {
        Some(base.overlay(patch))
      } else {
        let merged = base.overlay(Map::new())
        merge_missing_edge_properties(merged, patch)
        Some(merged)
      }
    (Some(base), None) => Some(base)
    (None, Some(patch)) => Some(patch)
    (None, None) => None
  }
}

///|
fn merge_missing_edge_properties(target : Map, patch : Map) -> Unit {
  for patch_field in patch.fields {
    match target.get_field(patch_field.name) {
      Some(existing) =>
        match (existing.composite, patch_field.composite) {
          (Some(Map(existing_map)), Some(Map(patch_map))) =>
            merge_missing_edge_properties(existing_map, patch_map)
          _ => ()
        }
      None => target.add_field(clone_field(patch_field))
    }
  }
}

///|
fn glob_edge_patch_follows_existing(
  existing : Edge?,
  glob_offset : Int,
) -> Bool {
  guard existing is Some(edge) else { return true }
  for i = edge.references.length() - 1; i >= 0; i = i - 1 {
    let reference = edge.references[i]
    if !reference.due_to_glob {
      return glob_offset >= reference.range.start.offset
    }
  }
  true
}

///|
fn apply_edge_value(
  existing : Edge?,
  edge_key : @ast.KeyPath?,
  patch_primary : Scalar?,
  patch_map : Map?,
  patch_overrides? : Bool = true,
) -> (Scalar?, Map?) {
  let existing_primary = match existing {
    Some(edge) => edge.primary
    None => None
  }
  let existing_map = match existing {
    Some(edge) => edge.map
    None => None
  }
  match edge_key {
    Some(path) => {
      let property_map = edge_property_map(path, patch_primary, patch_map)
      (
        existing_primary,
        merge_edge_maps(existing_map, Some(property_map), patch_overrides),
      )
    }
    None =>
      (
        match patch_primary {
          Some(primary) => Some(primary)
          None => existing_primary
        },
        merge_edge_maps(existing_map, patch_map, patch_overrides),
      )
  }
}
