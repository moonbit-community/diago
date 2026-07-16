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
fn identity_graph() -> @graph.GraphInput {
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
  @graph.GraphInput::from_parts(
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
}

///|
test "layout problem canonicalizes syntax-distinct identities" {
  let problem = @layout_core.compile(identity_graph())
  let graph = problem.graph()
  @debug.assert_eq(graph.objects[0].id, "\"a.b\"")
  @debug.assert_eq(graph.objects[1].id, "a.b")
  @debug.assert_eq(graph.edges[0].src_id, "\"a.b\"")
  @debug.assert_eq(graph.edges[0].dst_id, "a.b")
}

///|
test "layout problem rejects duplicate canonical identities" {
  let graph = identity_graph()
  graph.objects.push(
    @graph.ObjectInput::new("other", id_syntax="other", abs_id_syntax="a.b"),
  )
  try @layout_core.compile(graph) catch {
    DuplicateObjectId(id) => @debug.assert_eq(id, "a.b")
    error => fail("unexpected error: \{error.message()}")
  } noraise {
    _ => fail("expected duplicate object identity to fail")
  }
}

///|
test "layout problem rejects missing edge endpoints" {
  let graph = identity_graph()
  graph.edges.push(
    @graph.EdgeInput::new(
      1,
      "a.b",
      "missing",
      false,
      true,
      src_id_syntax="a.b",
      dst_id_syntax="missing",
    ),
  )
  try @layout_core.compile(graph) catch {
    MissingEdgeEndpoint(edge_index~, endpoint_id~) => {
      @debug.assert_eq(edge_index, 1)
      @debug.assert_eq(endpoint_id, "missing")
    }
    error => fail("unexpected error: \{error.message()}")
  } noraise {
    _ => fail("expected missing endpoint to fail")
  }
}

///|
test "layout problem validates patch identities" {
  let problem = @layout_core.compile(identity_graph())
  let patch = @graph.LayoutPatch::new()
  patch.nodes["unknown"] = @graph.Box::new(0.0, 0.0, 10.0, 10.0)
  try problem.validate_patch(patch) catch {
    UnknownPatchNode(id) => @debug.assert_eq(id, "unknown")
    error => fail("unexpected error: \{error.message()}")
  } noraise {
    _ => fail("expected unknown patch identity to fail")
  }
}
