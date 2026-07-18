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
fn compile(source : String) -> Result[String, String] {
  match compile_to_diagram(source, Down) {
    Ok(diagram) => {
      let render_config = @renderer_svg.SvgConfig::new()
      try @renderer_svg.render(diagram, render_config) catch {
        e => Err(e.to_string())
      } noraise {
        value => Ok(value)
      }
    }
    Err(error) => Err(error)
  }
}

///|
fn compile_to_diagram(
  source : String,
  direction : @engine_api.Direction,
) -> Result[@diagram.Diagram, String] {
  let graph_input = match compile_graph_no_layout(source) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let laid_out_graph = @engine_api.layout_with_engine(
    @engine_dagre.DagreEngine::new(),
    graph_input,
    @engine_api.LayoutConfig::new(),
    direction,
  ) catch {
    error => return Err("Layout error: \{error}")
  }
  Ok(@diagram.from_graph(laid_out_graph, None))
}

///|
fn compile_graph_no_layout(
  source : String,
) -> Result[@graph.GraphInput, String] {
  let (ast, errors) = @parser.parse(source)
  if !errors.is_empty() {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile_with_imports(
    ast,
    @ir.ImportResolver::new(fn(_) { None }),
  ) catch {
    error => return Err("IR error: \{error}")
  }
  let graph_input = @exporter.compile("test", ir) catch {
    error => return Err("Graph error: \{error}")
  }
  Ok(graph_input)
}

///|
fn find_connection(
  diagram : @diagram.Diagram,
  src_id : String,
  dst_id : String,
) -> @diagram.Connection? {
  for connection in diagram.get_edges() {
    if (
        connection.src_lookup_id == src_id || connection.src_syntax_id == src_id
      ) &&
      (connection.dst_lookup_id == dst_id || connection.dst_syntax_id == dst_id) {
      return Some(connection)
    }
  }
  None
}

///|
fn assert_route_points_close(
  actual : Array[@graph.Point],
  expected : Array[@graph.Point],
  tolerance? : Double = 1.0e-3,
) -> Unit raise {
  @debug.assert_eq(actual.length(), expected.length())
  for i in 0..<actual.length() {
    let dx = (actual[i].x - expected[i].x).abs()
    let dy = (actual[i].y - expected[i].y).abs()
    assert_true(
      dx <= tolerance && dy <= tolerance,
      msg="route point \{i} mismatch: actual=\{actual[i]}, expected=\{expected[i]}, dx=\{dx}, dy=\{dy}",
    )
  }
}
