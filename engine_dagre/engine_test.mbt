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
test "dagre engine can layout simple graph" {
  let (ast, errors) = @parser.parse("a -> b")
  if !errors.is_empty() {
    fail("parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => fail("ir error: \{e}") }
  let graph_input = @exporter.compile("test", ir) catch {
    e => fail("graph error: \{e}")
  }
  let laid_out = @engine_api.layout_with_engine(
    DagreEngine::new(),
    graph_input,
    @engine_api.LayoutConfig::new(),
    Down,
  ) catch {
    e => fail("layout error: \{e}")
  }
  assert_true(laid_out.find_object("a").unwrap().box is Some(_))
  assert_true(laid_out.find_object("b").unwrap().box is Some(_))
  assert_true(laid_out.edges.length() == 1)
  assert_true(laid_out.edges[0].route.length() >= 2)
}

///|
test "dagre layout preserves edge glob styles by edge index" {
  let source =
    #|(** -> **)[*]: {
    #|  &src: a
    #|  &dst: c
    #|  style.stroke: yellow
    #|}
    #|a -> b
    #|a -> c
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = @ir.compile(ast) catch { error => fail("ir error: \{error}") }
  let graph = @exporter.compile("test", ir) catch {
    error => fail("graph error: \{error}")
  }
  let laid_out = @engine_api.layout_with_engine(
    DagreEngine::new(),
    graph,
    @engine_api.LayoutConfig::new(),
    Down,
  ) catch {
    error => fail("layout error: \{error}")
  }
  for edge in laid_out.edges {
    guard edge.style.stroke is Some(stroke) else {
      fail("expected edge stroke")
    }
    @debug.assert_eq(
      stroke.get_value(),
      if edge.dst_id == "c" {
        "yellow"
      } else {
        "B1"
      },
    )
  }
}

///|
test "dagre nested container padding matches D2 terminal theme geometry" {
  let source =
    #|network: {
    #|  cell tower: {
    #|    satellites: { shape: stored_data; style.multiple: true }
    #|    transmitter
    #|    satellites -> transmitter: send
    #|    satellites -> transmitter: send
    #|    satellites -> transmitter: send
    #|  }
    #|  online portal: { ui: { shape: hexagon } }
    #|  data processor: { storage: { shape: cylinder; style.multiple: true } }
    #|  cell tower.transmitter -> data processor.storage: phone logs
    #|}
    #|user: { shape: person; width: 130 }
    #|user -> network.cell tower: make call
    #|user -> network.online portal.ui: access { style.stroke-dash: 3 }
    #|api server -> network.online portal.ui: display
    #|api server -> logs: persist
    #|logs: { shape: page; style.multiple: true }
    #|network.data processor -> api server
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = @ir.compile(ast) catch { error => fail("ir error: \{error}") }
  let base_graph = @exporter.compile("test", ir) catch {
    error => fail("graph error: \{error}")
  }
  let graph = base_graph.with_default_font("mono").with_caps_lock()
  let laid_out = @engine_api.layout_with_engine(
    DagreEngine::new(),
    graph,
    @engine_api.LayoutConfig::new(),
    Down,
  ) catch {
    error => fail("layout error: \{error}")
  }
  guard laid_out.find_object("network.cell tower").unwrap().box is Some(box) else {
    fail("expected laid-out cell tower box")
  }
  @debug.assert_eq(box.x, 130.0)
  @debug.assert_eq(box.y, 268.0)
  @debug.assert_eq(box.width, 253.0)
  @debug.assert_eq(box.height, 323.0)
}

///|
test "dagre rejects LaTeX labels before layout" {
  let source =
    #|grid-columns: 3
    #|grid-gap: 100
    #|*.style.fill: transparent
    #|*.style.stroke: black
    #|amscd plugin: {
    #|  ex: |tex
    #|    \begin{CD} B @>{\text{very long label}}>> C S^{{\mathcal{W}}_\Lambda}\otimes T @>j>> T\\ @VVV V \end{CD}
    #|  |
    #|}
    #|braket plugin: { ex: |tex
    #|  \bra{a}\ket{b}
    #|| }
    #|cancel plugin: { ex: |tex
    #|  \cancel{Culture + 5}
    #|| }
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = @ir.compile(ast) catch { error => fail("ir error: \{error}") }
  let graph = @exporter.compile("test", ir) catch {
    error => fail("graph error: \{error}")
  }
  try
    @engine_api.layout_with_engine(
      DagreEngine::new(),
      graph,
      @engine_api.LayoutConfig::new(),
      Down,
    )
  catch {
    Unsupported(message) =>
      @debug.assert_eq(message, "LaTeX labels are not supported")
    _ => fail("expected unsupported LaTeX error")
  } noraise {
    _ => fail("expected unsupported LaTeX error")
  }
}
