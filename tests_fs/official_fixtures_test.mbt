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
async test "official nested grid cross edge uses D2 logical boundary" {
  let source = @fs.read_file(
    "testdata/d2-official/d2-docs/static/bespoke-d2/grid-nested-connections.d2",
  ).text()
  let graph_input = compile_graph_no_layout(source).unwrap()
  let config = @engine_api.LayoutConfig::new()
  let dagre = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    config,
    Down,
  ) catch {
    error => fail("dagre layout error: \{error}")
  }
  let elk = @engine_api.layout_with_engine(
    @engine_elk.ElkEngine::new(),
    graph_input,
    config,
    Down,
  ) catch {
    error => fail("elk layout error: \{error}")
  }
  let dagre_target = @diagram.from_graph(dagre, None)
  let elk_target = @diagram.from_graph(elk, None)
  let dagre_edge = find_connection(
    dagre_target, "top-row.Random Matrix Generator", "bottom-row.matrix-container.matrix",
  ).unwrap()
  let elk_edge = find_connection(
    elk_target, "top-row.Random Matrix Generator", "bottom-row.matrix-container.matrix",
  ).unwrap()
  assert_route_points_close(
    dagre_edge.route,
    [@graph.Point::new(1342.0, 230.0), @graph.Point::new(1321.0, 450.0)],
    tolerance=0.000001,
  )
  assert_route_points_close(
    elk_edge.route,
    [@graph.Point::new(1348.0, 230.0), @graph.Point::new(1343.0, 450.0)],
    tolerance=0.000001,
  )
}

///|
async test "official grid padding preserves escaped IDs and glob classes" {
  let source = @fs.read_file(
    "testdata/d2-official/d2-docs/static/d2/grid-padding-1.d2",
  ).text()
  let graph = compile_graph_no_layout(source).unwrap()
  let service = graph
    .find_object("Kubernetes.system.Backend Node.ClusterIP\nService 1")
    .unwrap()
  @debug.assert_eq(
    service.abs_id_syntax,
    "Kubernetes.system.Backend Node.\"ClusterIP\\nService 1\"",
  )
  assert_true(service.classes.contains("clust"))
  let next_pod = graph
    .find_object("Kubernetes.system.Backend Node.Deployment 1.NEXT POD 1")
    .unwrap()
  assert_true(next_pod.classes.contains("nextpod"))
  @debug.assert_eq(
    next_pod.icon,
    Some("https://www.svgrepo.com/show/378440/nextjs-fill.svg"),
  )
  let flask_pod = graph
    .find_object("Kubernetes.system.Frontend Node.Deployment 2.FLASK POD 1")
    .unwrap()
  assert_true(flask_pod.classes.contains("flaskpod"))
  @debug.assert_eq(
    flask_pod.icon,
    Some("https://www.svgrepo.com/show/508915/flask.svg"),
  )
}

///|
async test "official class members preserve escaped visibility prefixes" {
  let source = @fs.read_file(
    "testdata/d2-official/d2-docs/static/d2/classes-2.d2",
  ).text()
  let graph = compile_graph_no_layout(source).unwrap()
  let parser = graph.find_object("D2 Parser").unwrap()
  @debug.assert_eq(parser.child_ids, [
    "D2 Parser.+reader", "D2 Parser.readerPos", "D2 Parser.-lookahead", "D2 Parser.\"#lookaheadPos\"",
    "D2 Parser.\"+peek()\"", "D2 Parser.\"rewind()\"", "D2 Parser.\"commit()\"",
    "D2 Parser.\"#peekn(n int)\"",
  ])
}

///|
async test "sequence connection identities omit nested group scopes" {
  let source = @fs.read_file(
    "testdata/d2-official/d2-docs/static/d2/sequence-diagrams-scope.d2",
  ).text()
  let graph = compile_graph_no_layout(source).unwrap()
  let group = graph.find_object("Office chatter.awkward small talk").unwrap()
  assert_true(group.classes.contains("__diago_sequence_group"))
  @debug.assert_eq(group.abs_id_syntax, "Office chatter.awkward small talk")
  let diagram = @diagram.from_graph(graph, None)
  let identities : Array[String] = []
  for edge in diagram.connections {
    identities.push("\{edge.src_syntax_id}->\{edge.dst_syntax_id}")
  }
  @debug.assert_eq(identities, [
    "Office chatter.alice->Office chatter.bob", "Office chatter.bob->Office chatter.alice",
    "Office chatter.alice->Office chatter.bob", "Office chatter.bob->Office chatter.alice",
  ])
}
