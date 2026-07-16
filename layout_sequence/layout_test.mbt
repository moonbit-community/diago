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
fn sequence_root(child_ids : Array[String]) -> @graph.ObjectInput {
  @graph.ObjectInput::from_parts(
    "root",
    "root",
    SequenceDiagram,
    @graph.StyleInput::new(),
    None,
    None,
    child_ids,
    0,
    None,
    None,
    None,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
}

///|
fn fixed_object_size(_obj : @graph.ObjectInput) -> (Double, Double) {
  (100.0, 66.0)
}

///|
test "shared sequence layout preserves syntax-distinct participant identities" {
  let quoted = @graph.ObjectInput::new(
    "\"a.b\"",
    id_val="a.b",
    id_syntax="\"a.b\"",
    abs_id_syntax="\"a.b\"",
  )
  let nested = @graph.ObjectInput::new(
    "a.b",
    id_val="b",
    id_syntax="b",
    abs_id_syntax="a.b",
  )
  let edge = @graph.EdgeInput::new(
    0,
    "\"a.b\"",
    "a.b",
    false,
    true,
    src_id_syntax="\"a.b\"",
    dst_id_syntax="a.b",
  )
  let graph = @graph.GraphInput::from_parts(
    "syntax-distinct",
    sequence_root(["\"a.b\"", "a.b"]),
    [quoted, nested],
    [edge],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    None,
  )

  let patch = @layout_sequence.layout(graph, fixed_object_size)
  assert_true(patch.nodes.contains("\"a.b\""))
  assert_true(patch.nodes.contains("a.b"))
  assert_true(patch.edges.get(0).unwrap_or([]).length() >= 2)
}

///|
test "shared sequence layout resolves a nested participant through its container" {
  let group = @graph.ObjectInput::from_parts(
    "service",
    "service",
    Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["service.worker"],
    0,
    None,
    None,
    None,
    [],
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
  let client = @graph.ObjectInput::new("client")
  let worker = @graph.ObjectInput::new(
    "service.worker",
    id_val="worker",
    id_syntax="worker",
    abs_id_syntax="service.worker",
  )
  let edge = @graph.EdgeInput::new(
    0,
    "client",
    "service.worker",
    false,
    true,
    src_id_syntax="client",
    dst_id_syntax="service.worker",
  )
  let graph = @graph.GraphInput::from_parts(
    "nested-participant",
    sequence_root(["client", "service"]),
    [client, group, worker],
    [edge],
    [],
    [],
    [],
    [],
    [],
    [],
    [],
    None,
  )

  let patch = @layout_sequence.layout(graph, fixed_object_size)
  let client_box = patch.nodes.get("client").unwrap()
  let worker_box = patch.nodes.get("service.worker").unwrap()
  assert_true(client_box.x < worker_box.x)
  assert_true(patch.edges.get(0).unwrap_or([]).length() >= 2)
}
