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
fn merge_edge_maps(base : Map?, patch : Map?) -> Map? {
  match (base, patch) {
    (Some(base), Some(patch)) => Some(base.overlay(patch))
    (Some(base), None) => Some(base)
    (None, Some(patch)) => Some(patch)
    (None, None) => None
  }
}

///|
fn apply_edge_value(
  existing : Edge?,
  edge_key : @ast.KeyPath?,
  patch_primary : Scalar?,
  patch_map : Map?,
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
      (existing_primary, merge_edge_maps(existing_map, Some(property_map)))
    }
    None =>
      (
        match patch_primary {
          Some(primary) => Some(primary)
          None => existing_primary
        },
        merge_edge_maps(existing_map, patch_map),
      )
  }
}
