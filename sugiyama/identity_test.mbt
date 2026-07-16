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
test "sugiyama preserves syntax-distinct canonical identities" {
  let root = @graph.ObjectInput::from_parts(
    "root",
    "root",
    Rectangle,
    @graph.StyleInput::new(),
    None,
    None,
    ["\"a.b\"", "a.b"],
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
  let quoted = @graph.ObjectInput::new(
    "a.b",
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
    "a.b",
    "a.b",
    false,
    true,
    src_id_syntax="\"a.b\"",
    dst_id_syntax="a.b",
  )
  let graph = @graph.GraphInput::from_parts(
    "identity",
    root,
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
  let problem = @layout_core.compile(graph)
  let canonical = problem.graph()
  let cycle = break_cycles(canonical)
  let layers = assign_layers(canonical, cycle)

  assert_true(layers.layers.length() == 2)
  assert_true(layers.layers.contains("\"a.b\""))
  assert_true(layers.layers.contains("a.b"))
  assert_true(
    layers.layers.get("\"a.b\"").unwrap() < layers.layers.get("a.b").unwrap(),
  )
  let placement = place(problem, fn(_obj) { (100.0, 60.0) }, Down, 60.0, 40.0)
  assert_true(placement.boxes.contains(@layout_core.ObjectId::new("\"a.b\"")))
  assert_true(placement.boxes.contains(@layout_core.ObjectId::new("a.b")))
}
