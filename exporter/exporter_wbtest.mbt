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
fn compile_source_graph(source : String) -> Result[@graph.GraphInput, String] {
  let (ast, errors) = @parser.parse(source)
  if !errors.is_empty() {
    return Err("Parse errors: \{errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("IR error: \{e}") }
  try compile("root", ir) catch {
    err => Err(err.to_string())
  } noraise {
    graph => Ok(graph)
  }
}

///|
test "triple-glob defaults reach exported objects and edges" {
  let source =
    #|***.style.fill: lightblue
    #|(*** -> ***)[*]: {
    #|  style.stroke: red
    #|}
    #|x -> y
  let graph = compile_source_graph(source).unwrap()
  guard graph.find_object("x") is Some(x) else { fail("expected x") }
  guard graph.find_object("y") is Some(y) else { fail("expected y") }
  @debug.assert_eq(
    x.style.fill,
    Some(@graph.StyleValue::from_string("lightblue")),
  )
  @debug.assert_eq(
    y.style.fill,
    Some(@graph.StyleValue::from_string("lightblue")),
  )
  @debug.assert_eq(
    graph.edges[0].style.stroke,
    Some(@graph.StyleValue::from_string("red")),
  )
}

///|
test "root sequence diagrams export root actors with D2 defaults" {
  let graph = compile_source_graph(
    (
      #|shape: sequence_diagram
      #|alice -> bob
      #|note
    ),
  ).unwrap()
  assert_eq(graph.root.label, "")
  guard graph.find_object("alice") is Some(alice) else {
    fail("expected alice")
  }
  guard graph.find_object("bob") is Some(bob) else { fail("expected bob") }
  guard graph.find_object("note") is Some(note) else { fail("expected note") }
  @debug.assert_eq(alice.style.fill, Some(@graph.StyleValue::from_string("B5")))
  @debug.assert_eq(bob.style.fill, Some(@graph.StyleValue::from_string("B5")))
  @debug.assert_eq(note.style.fill, Some(@graph.StyleValue::from_string("N7")))
}

///|
test "nested sequence actors inherit message defaults by syntax path" {
  let graph = compile_source_graph(
    (
      #|seq: {
      #|  shape: sequence_diagram
      #|  alice.t -> bob.t
      #|}
    ),
  ).unwrap()
  for id in ["seq.alice", "seq.bob"] {
    guard graph.find_object(id) is Some(actor) else {
      fail("expected nested actor \{id}")
    }
    @debug.assert_eq(
      actor.style.fill,
      Some(@graph.StyleValue::from_string("B5")),
    )
    @debug.assert_eq(actor.label_position, Some("INSIDE_MIDDLE_CENTER"))
  }
}

///|
test "sequence descendants export as activations notes and groups" {
  let graph = compile_source_graph(
    (
      #|shape: sequence_diagram
      #|alice.t -> bob
      #|bob."remember this"
      #|phase: {
      #|  alice -> bob
      #|}
    ),
  ).unwrap()
  guard graph.find_object("alice.t") is Some(activation) else {
    fail("expected activation")
  }
  assert_eq(activation.label, "")
  @debug.assert_eq(
    activation.style.fill,
    Some(@graph.StyleValue::from_string("B4")),
  )
  guard graph.find_object("bob.remember this") is Some(note) else {
    fail("expected note")
  }
  assert_eq(note.shape_type, @graph.ShapeType::Page)
  guard graph.find_object("phase") is Some(group) else {
    fail("expected group")
  }
  @debug.assert_eq(group.style.fill, Some(@graph.StyleValue::from_string("N5")))
  @debug.assert_eq(
    group.style.stroke_width,
    Some(@graph.StyleValue::from_double(0.0)),
  )
  assert_true(group.classes.contains("__diago_sequence_group"))
}

///|
test "triple-glob defaults reach objects inside layers" {
  let source =
    #|***.style.fill: yellow
    #|layers: {
    #|  next: {
    #|    a
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  @debug.assert_eq(graph.layers.length(), 1)
  guard graph.layers[0].graph.find_object("a") is Some(a) else {
    fail("expected layer object a")
  }
  @debug.assert_eq(a.style.fill, Some(@graph.StyleValue::from_string("yellow")))
}

///|
test "edge glob endpoint filters remain isolated after graph export" {
  let source =
    #|(** -> **)[*]: {
    #|  &src: a
    #|  &dst: c
    #|  style.stroke: yellow
    #|}
    #|a -> b
    #|a -> c
  let graph = compile_source_graph(source).unwrap()
  @debug.assert_eq(graph.edges.length(), 2)
  for edge in graph.edges {
    guard edge.style.stroke is Some(stroke) else {
      fail("expected defaulted edge stroke")
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
test "imported class retains nested style properties" {
  let source =
    #|...@classes
    #|user.class: person
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let resolver = @ir.ImportResolver::new(fn(path) {
    if path == "classes" || path == "classes.d2" {
      let classes_source =
        #|classes.person: {
        #|  shape: person
        #|  style.stroke-dash: 3
        #|}
      Some(classes_source)
    } else {
      None
    }
  })
  let ir = @ir.compile_with_imports(ast, resolver) catch {
    error => fail("IR error: \{error}")
  }
  let graph = compile("root", ir) catch {
    error => fail("graph error: \{error}")
  }
  guard graph.find_object("user") is Some(user) else { fail("expected user") }
  guard user.style.stroke_dash is Some(stroke_dash) else {
    fail("expected stroke dash")
  }
  @debug.assert_eq(stroke_dash.get_value(), "3")
}

///|
test "classes block is treated as reserved during object compilation" {
  let class_def = @ir.Map::new()
  class_def.add_field(
    @ir.Field::new("shape", Some(@ir.Scalar::string("person")), None, []),
  )
  let classes_map = @ir.Map::new()
  classes_map.add_field(@ir.Field::new("user", None, Some(Map(class_def)), []))
  let alice_map = @ir.Map::new()
  let ir = @ir.Map::new()
  ir.add_field(@ir.Field::new("classes", None, Some(Map(classes_map)), []))
  ir.add_field(
    @ir.Field::new(
      "alice",
      Some(@ir.Scalar::string("Alice")),
      Some(Map(alice_map)),
      [],
    ),
  )
  guard ir.get_field("classes") is Some(classes_field) else {
    fail("expected classes field")
  }
  assert_true(classes_field.is_reserved_keyword_name())
  let classes = extract_classes(ir)
  let graph = Graph::new("root")
  compile_objects(graph, ir, "", "", classes)
  @debug.assert_eq(graph.objects.length(), 1)
  @debug.assert_eq(graph.objects[0].id, "alice")
}

///|
test "board graphs carry folder-only metadata" {
  let layer_body = @ir.Map::new()
  layer_body.add_field(
    @ir.Field::new("service", None, Some(Map(@ir.Map::new())), []),
  )
  let layers_map = @ir.Map::new()
  layers_map.add_field(@ir.Field::new("one", None, Some(Map(layer_body)), []))
  let ir = @ir.Map::new()
  ir.add_field(@ir.Field::new("layers", None, Some(Map(layers_map)), []))

  let graph = compile("root", ir) catch { e => fail(e.to_string()) }
  assert_true(graph.is_folder_only)
  @debug.assert_eq(graph.layers.length(), 1)
  assert_false(graph.layers[0].graph.is_folder_only)
  assert_true(graph.layers[0].graph.find_object("service") is Some(_))
}

///|
test "scenarios and steps inherit base board objects while layers stay isolated" {
  let source =
    #|x: {
    #|  style.opacity: 0.5
    #|}
    #|scenarios: {
    #|  scene: {}
    #|}
    #|steps: {
    #|  1: {}
    #|}
    #|layers: {
    #|  alt: {
    #|    x
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.scenarios[0].graph.find_object("x") is Some(scenario_x) else {
    fail("expected inherited scenario object")
  }
  guard graph.steps[0].graph.find_object("x") is Some(step_x) else {
    fail("expected inherited step object")
  }
  guard graph.layers[0].graph.find_object("x") is Some(layer_x) else {
    fail("expected layer object")
  }
  assert_false(graph.scenarios[0].graph.is_folder_only)
  assert_false(graph.steps[0].graph.is_folder_only)
  @debug.assert_eq(
    scenario_x.style.opacity,
    Some(@graph.StyleValue::from_string("0.5")),
  )
  @debug.assert_eq(
    step_x.style.opacity,
    Some(@graph.StyleValue::from_string("0.5")),
  )
  @debug.assert_eq(layer_x.style.opacity, None)
}

///|
test "scenario overlays preserve base objects and apply overrides" {
  let source =
    #|a
    #|x
    #|a -> x
    #|scenarios: {
    #|  focus: {
    #|    x.style.opacity: 0.1
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  let scenario = graph.scenarios[0].graph
  @debug.assert_eq(scenario.objects.length(), 2)
  @debug.assert_eq(scenario.edges.length(), 1)
  guard scenario.find_object("x") is Some(x) else {
    fail("expected overlaid object")
  }
  @debug.assert_eq(x.style.opacity, Some(@graph.StyleValue::from_string("0.1")))
}

///|
test "indexed edge properties update the selected edge" {
  let source =
    #|a -> b: first
    #|a -> b: second
    #|(a -> b)[1].style.opacity: 0.4
  let graph = match compile_source_graph(source) {
    Ok(graph) => graph
    Err(message) => fail(message)
  }
  @debug.assert_eq(graph.edges.length(), 2)
  @debug.assert_eq(graph.edges[0].label, "first")
  @debug.assert_eq(graph.edges[0].style.opacity, None)
  @debug.assert_eq(graph.edges[1].label, "second")
  @debug.assert_eq(
    graph.edges[1].style.opacity,
    Some(@graph.StyleValue::from_string("0.4")),
  )
}

///|
test "scenario indexed edge properties update inherited edges" {
  let source =
    #|a -> b: first
    #|a -> b: second
    #|scenarios: {
    #|  focus: {
    #|    (a -> b)[1].style.opacity: 0.1
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  let scenario = graph.scenarios[0].graph
  @debug.assert_eq(scenario.edges.length(), 2)
  @debug.assert_eq(scenario.edges[0].label, "first")
  @debug.assert_eq(scenario.edges[0].style.opacity, None)
  @debug.assert_eq(scenario.edges[1].label, "second")
  @debug.assert_eq(
    scenario.edges[1].style.opacity,
    Some(@graph.StyleValue::from_string("0.1")),
  )
}

///|
test "scenario edge declarations append after inherited parallel edges" {
  let source =
    #|a -> b: base
    #|scenarios: {
    #|  expanded: {
    #|    a -> b: added
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  let scenario = graph.scenarios[0].graph
  @debug.assert_eq(scenario.edges.length(), 2)
  @debug.assert_eq(scenario.edges[0].label, "base")
  @debug.assert_eq(scenario.edges[1].label, "added")
}

///|
test "scenario edge order preserves inherited overlay mutation order" {
  let source =
    #|local.code -> github.dev: commit
    #|github: {
    #|  dev -> master.workflows: merge
    #|}
    #|github.master.workflows -> aws.builders: upload
    #|aws: {
    #|  builders -> s3: binaries
    #|  ec2 <- s3: pull
    #|}
    #|local.code -> aws.ec2: direct
    #|scenarios: {
    #|  hotfix: {
    #|    (local.code -> github.dev)[0].style.opacity: 0.1
    #|    github: {
    #|      (dev -> master.workflows)[0].style.opacity: 0.1
    #|    }
    #|    (github.master.workflows -> aws.builders)[0].style.opacity: 0.1
    #|    (local.code -> aws.ec2)[0].style.opacity: 1
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  @debug.assert_eq(
    graph.scenarios[0].graph.edges.map(fn(edge) { edge.label }),
    ["merge", "binaries", "pull", "commit", "upload", "direct"],
  )
}

///|
test "scenario indexed updates retain inherited indexes after new declarations" {
  let source =
    #|a -> b: base
    #|scenarios: {
    #|  expanded: {
    #|    a -> b: added
    #|    (a -> b)[0].style.opacity: 0.2
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  let scenario = graph.scenarios[0].graph
  @debug.assert_eq(scenario.edges.length(), 2)
  @debug.assert_eq(scenario.edges[0].label, "base")
  @debug.assert_eq(
    scenario.edges[0].style.opacity,
    Some(@graph.StyleValue::from_string("0.2")),
  )
  @debug.assert_eq(scenario.edges[1].label, "added")
  @debug.assert_eq(scenario.edges[1].style.opacity, None)
}

///|
test "scenario edge index globs update all inherited parallel edges" {
  let source =
    #|a -> b: first
    #|a -> b: second
    #|scenarios: {
    #|  focus: {
    #|    (a -> b)[*].style.opacity: 0.3
    #|    (missing -> edge)[*].style.opacity: 0.1
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  let scenario = graph.scenarios[0].graph
  @debug.assert_eq(scenario.edges.length(), 2)
  for edge in scenario.edges {
    @debug.assert_eq(
      edge.style.opacity,
      Some(@graph.StyleValue::from_string("0.3")),
    )
  }
}

///|
test "indexed edge map forms merge without changing other edges" {
  let source =
    #|a -> b: forward
    #|a <-> b: bidirectional
    #|(a -> b)[0].style: {
    #|  opacity: 0.4
    #|}
    #|(a -> b)[0]: {
    #|  style.stroke: red
    #|}
  let graph = compile_source_graph(source).unwrap()
  @debug.assert_eq(graph.edges.length(), 2)
  @debug.assert_eq(graph.edges[0].label, "forward")
  @debug.assert_eq(
    graph.edges[0].style.opacity,
    Some(@graph.StyleValue::from_string("0.4")),
  )
  @debug.assert_eq(
    graph.edges[0].style.stroke,
    Some(@graph.StyleValue::from_string("red")),
  )
  @debug.assert_eq(graph.edges[1].label, "bidirectional")
  @debug.assert_eq(graph.edges[1].style.opacity, None)
  @debug.assert_eq(
    graph.edges[1].style.stroke,
    Some(@graph.StyleValue::from_string("B1")),
  )
}

///|
test "steps inherit the previous step before applying indexed edge properties" {
  let source =
    #|a -> b: base
    #|steps: {
    #|  1: {
    #|    (a -> b)[0].style.opacity: 0.2
    #|  }
    #|  2: {
    #|    (a -> b)[0].style.stroke: red
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  @debug.assert_eq(graph.steps.length(), 2)
  @debug.assert_eq(
    graph.steps[0].graph.edges[0].style.opacity,
    Some(@graph.StyleValue::from_string("0.2")),
  )
  @debug.assert_eq(
    graph.steps[1].graph.edges[0].style.opacity,
    Some(@graph.StyleValue::from_string("0.2")),
  )
  @debug.assert_eq(
    graph.steps[1].graph.edges[0].style.stroke,
    Some(@graph.StyleValue::from_string("red")),
  )
}

///|
test "board primary labels override explicit labels and base labels are not inherited" {
  let source =
    #|label: hi
    #|layers: {
    #|  1: one {
    #|    RJ
    #|  }
    #|  2: {
    #|    label: two
    #|    RJ
    #|  }
    #|}
    #|scenarios: {
    #|  x: b {
    #|    k
    #|  }
    #|}
    #|steps: {
    #|  s1: {
    #|    RJ
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  @debug.assert_eq(graph.layers[0].graph.root.label, "one")
  @debug.assert_eq(graph.layers[1].graph.root.label, "two")
  @debug.assert_eq(graph.scenarios[0].graph.root.label, "b")
  @debug.assert_eq(graph.steps[0].graph.root.label, "root")
}

///|
test "duplicate board names across kinds raise semantic error" {
  let source =
    #|layers: {
    #|  one: {
    #|    santa
    #|  }
    #|}
    #|steps: {
    #|  one: {
    #|    clause
    #|  }
    #|}
  match compile_source_graph(source) {
    Err(err) =>
      assert_true(err.contains("board name one already used by another board"))
    Ok(_) => fail("expected duplicate board name error")
  }
}

///|
test "board keywords must be declared at a board root scope" {
  let source =
    #|x: {
    #|  steps: {
    #|    1: {
    #|      a
    #|    }
    #|  }
    #|}
  match compile_source_graph(source) {
    Err(err) =>
      assert_true(err.contains("steps must be declared at a board root scope"))
    Ok(_) => fail("expected board root scope error")
  }
}

///|
test "board links canonicalize quoted board targets" {
  let source =
    #|x.link: layers."cat.go"
    #|layers: {
    #|  "cat.go": {
    #|    y
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.find_object("x") is Some(x) else {
    fail("expected linked object")
  }
  @debug.assert_eq(x.link, Some("cat.go.svg"))
}

///|
test "board links resolve relative underscores and discard invalid links" {
  let source =
    #|question.link: layers.cat
    #|plain.link: two
    #|layers: {
    #|  cat: {
    #|    meow
    #|    layers: {
    #|      kitten: {
    #|        up.link: _
    #|        self.link: _.layers.kitten
    #|        missing.link: _._._
    #|        remote.link: https://example.com/docs
    #|      }
    #|    }
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.find_object("question") is Some(question) else {
    fail("expected question object")
  }
  guard graph.find_object("plain") is Some(plain) else {
    fail("expected plain object")
  }
  let kitten_board = graph.layers[0].graph.layers[0].graph
  guard kitten_board.find_object("up") is Some(up) else {
    fail("expected relative-link object")
  }
  guard kitten_board.find_object("self") is Some(self) else {
    fail("expected self-link object")
  }
  guard kitten_board.find_object("missing") is Some(missing) else {
    fail("expected missing-link object")
  }
  guard kitten_board.find_object("remote") is Some(remote) else {
    fail("expected remote-link object")
  }
  @debug.assert_eq(question.link, Some("cat/index.svg"))
  @debug.assert_eq(plain.link, None)
  @debug.assert_eq(up.link, Some("index.svg"))
  @debug.assert_eq(self.link, None)
  @debug.assert_eq(missing.link, None)
  @debug.assert_eq(remote.link, Some("https://example.com/docs"))
}

///|
test "near keys cannot target descendants of grid diagrams" {
  let source =
    #|x.near: z.x
    #|z: {
    #|  grid-rows: 1
    #|  x
    #|}
  match compile_source_graph(source) {
    Err(err) =>
      assert_true(
        err.contains(
          "near keys cannot be set to descendants of special objects, like grid cells",
        ),
      )
    Ok(_) => fail("expected near_special error")
  }
}

///|
test "near keys cannot target objects within sequence diagrams" {
  let source =
    #|x: {
    #|  shape: sequence_diagram
    #|  a
    #|}
    #|b.near: x.a
  match compile_source_graph(source) {
    Err(err) =>
      assert_true(
        err.contains(
          "near keys cannot be set to an object within sequence diagrams",
        ),
      )
    Ok(_) => fail("expected near_sequence error")
  }
}

///|
test "position rules keep quoted-dot and nested identities distinct" {
  let source =
    #|"seq.child": {
    #|  top: 1
    #|}
    #|seq: {
    #|  shape: sequence_diagram
    #|  child
    #|}
  guard compile_source_graph(source) is Ok(graph) else {
    fail("top-level quoted-dot object should not inherit the nested parent")
  }
  guard graph.find_object("\"seq.child\"") is Some(quoted) else {
    fail("expected quoted-dot object")
  }
  @debug.assert_eq(quoted.top, Some(1))
}

///|
test "near keys cannot target objects with constant near keys" {
  let source =
    #|title: Title {
    #|  near: top-center
    #|}
    #|
    #|obj {
    #|  near: title
    #|}
  match compile_source_graph(source) {
    Err(err) =>
      assert_true(
        err.contains(
          "near keys cannot be set to an object with a constant near key",
        ),
      )
    Ok(_) => fail("expected near_near_const error")
  }
}

///|
test "edges from constant near containers cannot enter themselves" {
  let source =
    #|tl: {
    #|  near: top-left
    #|  a
    #|}
    #|tl -> tl.a
  match compile_source_graph(source) {
    Err(err) => assert_true(err.contains("edge from constant near"))
    Ok(_) => fail("expected constant near edge error")
  }
}

///|
test "edges from grid diagrams and cells cannot enter themselves" {
  let grid_source =
    #|grid: {
    #|  grid-rows: 1
    #|  cell
    #|}
    #|grid -> grid.cell
  match compile_source_graph(grid_source) {
    Err(err) => assert_true(err.contains("edge from grid diagram"))
    Ok(_) => fail("expected grid diagram edge error")
  }

  let cell_source =
    #|grid: {
    #|  grid-rows: 1
    #|  cell: {
    #|    c
    #|  }
    #|}
    #|grid.cell -> grid.cell.c
  match compile_source_graph(cell_source) {
    Err(err) => assert_true(err.contains("edge from grid cell"))
    Ok(_) => fail("expected grid cell edge error")
  }
}

///|
test "edges from sequence diagrams cannot enter themselves" {
  let source =
    #|seq: {
    #|  shape: sequence_diagram
    #|  e
    #|}
    #|seq -> seq.e
  match compile_source_graph(source) {
    Err(err) => assert_true(err.contains("edge from sequence diagram"))
    Ok(_) => fail("expected sequence diagram edge error")
  }
}

///|
test "grid nested simple edges fixture compiles edge classes on grid descendants like the reference" {
  let source =
    #|direction: right
    #|
    #|outer-grid -> outer-container
    #|
    #|outer-grid: {
    #|  grid-columns: 1
    #|
    #|  inner-grid -> container -> etc
    #|
    #|  container: {
    #|    label.near: top-left
    #|    (** -> **)[*].class: red
    #|    a -> b -> c -> a
    #|    d -> e -> g.h.i
    #|    d -> f -> g.h
    #|    b -> g
    #|  }
    #|
    #|  inner-grid: {
    #|    grid-rows: 1
    #|    1 -> 2 -> 3: {class: red}
    #|  }
    #|}
    #|
    #|outer-container: {
    #|  grid -> container
    #|
    #|  grid: {
    #|    grid-rows: 1
    #|    1 -> 2 -> 3
    #|  }
    #|
    #|  container: {
    #|    4 -> 5 -> 6
    #|    nested container: {
    #|      7 -> 8
    #|    }
    #|  }
    #|}
    #|
    #|classes.red.style.stroke: red
  let graph = compile_source_graph(source).unwrap()
  let red_inner_grid_edges : Array[@graph.EdgeInput] = []
  let container_chain_edges : Array[@graph.EdgeInput] = []
  for edge in graph.edges {
    if edge.src_id.has_prefix("outer-grid.inner-grid.") &&
      edge.dst_id.has_prefix("outer-grid.inner-grid.") {
      red_inner_grid_edges.push(edge)
    }
    if edge.src_id == "outer-grid.inner-grid" ||
      edge.src_id == "outer-grid.container" {
      if edge.dst_id == "outer-grid.container" ||
        edge.dst_id == "outer-grid.etc" {
        container_chain_edges.push(edge)
      }
    }
  }
  @debug.assert_eq(red_inner_grid_edges.length(), 2)
  for edge in red_inner_grid_edges {
    @debug.assert_eq(
      edge.style.stroke,
      Some(@graph.StyleValue::from_string("red")),
    )
  }
  @debug.assert_eq(container_chain_edges.length(), 2)
}

///|
test "edge classes retain names and distinguish arrow from triangle" {
  let source =
    #|a -> b: {
    #|  class: arrow
    #|}
    #|classes.arrow: {
    #|  target-arrowhead.shape: arrow
    #|  style.stroke: black
    #|}
  let graph = compile_source_graph(source).unwrap()
  @debug.assert_eq(graph.edges.length(), 1)
  let edge = graph.edges[0]
  @debug.assert_eq(edge.classes, ["arrow"])
  @debug.assert_eq(edge.dst_arrowhead, @graph.Arrow)
  @debug.assert_eq(
    edge.style.stroke,
    Some(@graph.StyleValue::from_string("black")),
  )
}

///|
test "nested arrowhead label field is exported" {
  let graph = compile_source_graph("a -> b: { source-arrowhead.label: 1 }").unwrap()
  @debug.assert_eq(graph.edges.length(), 1)
  @debug.assert_eq(graph.edges[0].src_arrowhead_label, Some("1"))
}

///|
test "arrowhead filled style selects the effective marker shape" {
  let graph = compile_source_graph(
    "a <-> b: { source-arrowhead.shape: triangle; source-arrowhead.style.filled: false; target-arrowhead.shape: diamond; target-arrowhead.style.filled: true }",
  ).unwrap()
  @debug.assert_eq(graph.edges.length(), 1)
  @debug.assert_eq(graph.edges[0].src_arrowhead, @graph.Open)
  @debug.assert_eq(graph.edges[0].dst_arrowhead, @graph.FilledDiamond)
}

///|
test "grid fill direction follows the first dimension keyword" {
  let rows_first = compile_source_graph(
    (
      #|grid-rows: 2
      #|grid-columns: 3
      #|a
      #|b
    ),
  ).unwrap()
  let columns_first = compile_source_graph(
    (
      #|grid-columns: 3
      #|grid-rows: 2
      #|a
      #|b
    ),
  ).unwrap()
  @debug.assert_eq(rows_first.root.grid_row_directed, Some(true))
  @debug.assert_eq(columns_first.root.grid_row_directed, Some(false))
}

///|
test "comma-bearing grid cell IDs survive graph export" {
  let source =
    #|grid-rows: 1
    #|grid-columns: 3
    #|0,0 -> 0,1 -> 0,2
  let graph = compile_source_graph(source).unwrap()
  assert_true(graph.find_object("0,0") is Some(_))
  assert_true(graph.find_object("0,1") is Some(_))
  assert_true(graph.find_object("0,2") is Some(_))
  @debug.assert_eq(graph.edges.length(), 2)
  @debug.assert_eq(graph.edges[0].src_id, "0,0")
  @debug.assert_eq(graph.edges[0].dst_id, "0,1")
  @debug.assert_eq(graph.edges[1].src_id, "0,1")
  @debug.assert_eq(graph.edges[1].dst_id, "0,2")
}

///|
test "label icon and tooltip near fields follow position semantics" {
  let source =
    #|hey: {
    #|  label: sushi {
    #|    near: outside-top-left
    #|  }
    #|  icon: https://asdf.com {
    #|    near: border-right-center
    #|  }
    #|  tooltip: hover text {
    #|    near: center-left
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.find_object("hey") is Some(hey) else { fail("expected object") }
  @debug.assert_eq(hey.label, "sushi")
  @debug.assert_eq(hey.icon, Some("https://asdf.com"))
  @debug.assert_eq(hey.tooltip, Some("hover text"))
  @debug.assert_eq(hey.label_position, Some("OUTSIDE_TOP_LEFT"))
  @debug.assert_eq(hey.icon_position, Some("BORDER_RIGHT_MIDDLE"))
  @debug.assert_eq(hey.tooltip_position, Some("center-left"))
}

///|
test "edge icon and link fields compile like D2 connections" {
  let source =
    #|a -> b: hello {
    #|  icon: https://example.com/icon.svg {
    #|    near: outside-top-center
    #|    style.border-radius: 12
    #|  }
    #|  link: https://example.com/docs
    #|}
  let graph = compile_source_graph(source).unwrap()
  @debug.assert_eq(graph.edges.length(), 1)
  let edge = graph.edges[0]
  @debug.assert_eq(edge.icon, Some("https://example.com/icon.svg"))
  @debug.assert_eq(edge.icon_position, Some("OUTSIDE_TOP_CENTER"))
  @debug.assert_eq(edge.icon_border_radius, Some(12.0))
  @debug.assert_eq(edge.link, Some("https://example.com/docs"))
}

///|
test "edge links reject URL labels like object links" {
  let source =
    #|a -> b: https://example.com/label {
    #|  link: https://example.com/docs
    #|}
  match compile_source_graph(source) {
    Err(error) => assert_true(error.contains("Label cannot be set to URL"))
    Ok(_) => fail("expected URL edge label safety error")
  }
}

///|
test "separate near fields and null position resets follow position semantics" {
  let source =
    #|hey: sushi {
    #|  label.near: outside-top-left
    #|  tooltip: hover text {
    #|    near: null
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.find_object("hey") is Some(hey) else { fail("expected object") }
  @debug.assert_eq(hey.label, "sushi")
  @debug.assert_eq(hey.label_position, Some("OUTSIDE_TOP_LEFT"))
  @debug.assert_eq(hey.tooltip_position, None)
}

///|
test "null style values reset inherited properties" {
  let source =
    #|one: {
    #|  style.fill: pink
    #|  style.stroke: green
    #|}
    #|one.style.stroke: null
  let graph = compile_source_graph(source).unwrap()
  guard graph.find_object("one") is Some(one) else { fail("expected object") }
  @debug.assert_eq(one.style.fill.unwrap().get_value(), "pink")
  @debug.assert_eq(one.style.stroke.unwrap().get_value(), "B1")
}

///|
test "null removes objects and connections" {
  let graph = compile_source_graph(
    (
      #|one -> two
      #|two: null
    ),
  ).unwrap()
  @debug.assert_eq(graph.objects.length(), 1)
  @debug.assert_eq(graph.objects[0].id, "one")
  @debug.assert_eq(graph.edges.length(), 0)

  let edge_graph = compile_source_graph(
    (
      #|one -> two
      #|(one -> two)[0]: null
    ),
  ).unwrap()
  @debug.assert_eq(edge_graph.objects.length(), 2)
  @debug.assert_eq(edge_graph.edges.length(), 0)
}

///|
test "tooltip near rejects label-only positions like the reference" {
  let source =
    #|hey: {
    #|  tooltip: hover text {
    #|    near: outside-top-left
    #|  }
    #|}
  match compile_source_graph(source) {
    Err(_) => ()
    Ok(_) => fail("expected invalid near error")
  }
}

///|
test "legend config follows the compile semantics and defaults" {
  let source =
    #|vars: {
    #|  d2-legend: "凡例" {
    #|    User: "A person who interacts with the system" {
    #|      shape: person
    #|      style: {
    #|        fill: "#f5f5f5"
    #|      }
    #|    }
    #|
    #|    Database: "Stores application data" {
    #|      shape: cylinder
    #|      style.fill: "#b5d3ff"
    #|    }
    #|
    #|    HiddenShape: "This should not appear in the legend" {
    #|      style.opacity: 0
    #|    }
    #|
    #|    User -> Database: "Reads data" {
    #|      style.stroke: blue
    #|    }
    #|
    #|    Database -> User: "Returns results" {
    #|      style.stroke-dash: 5
    #|    }
    #|  }
    #|}
    #|
    #|user: User
    #|db: Database
    #|user -> db: Uses
  let graph = compile_source_graph(source).unwrap()
  guard graph.legend is Some(legend) else {
    fail("expected legend to be compiled")
  }

  @debug.assert_eq(legend.title, Some("凡例"))
  @debug.assert_eq(legend.position, BottomRight)
  @debug.assert_eq(legend.fill, Some("#ffffff"))
  @debug.assert_eq(legend.stroke, Some("#DEE1EB"))
  @debug.assert_eq(legend.padding, 20.0)
  @debug.assert_eq(legend.entry_gap, 15.0)
  @debug.assert_eq(legend.icon_size, 24.0)
  @debug.assert_eq(legend.entry_count(), 4)
  @debug.assert_eq(legend.entries.length(), 5)

  match legend.entries[0] {
    ShapeEntry(shape~, label~, style~, ..) => {
      @debug.assert_eq(shape, Person)
      @debug.assert_eq(label, "A person who interacts with the system")
      guard style is Some(style_input) else {
        fail("expected user legend style")
      }
      @debug.assert_eq(style_input.fill.unwrap().get_value(), "#f5f5f5")
    }
    _ => fail("expected first legend entry to be user shape")
  }

  match legend.entries[1] {
    ShapeEntry(shape~, label~, style~, ..) => {
      @debug.assert_eq(shape, Cylinder)
      @debug.assert_eq(label, "Stores application data")
      guard style is Some(style_input) else {
        fail("expected database legend style")
      }
      @debug.assert_eq(style_input.fill.unwrap().get_value(), "#b5d3ff")
    }
    _ => fail("expected second legend entry to be database shape")
  }

  assert_true(legend.entries[2] is Separator)

  match legend.entries[3] {
    ConnectionEntry(src_arrow~, dst_arrow~, label~, style~, ..) => {
      @debug.assert_eq(src_arrow, None)
      @debug.assert_eq(dst_arrow, Triangle)
      @debug.assert_eq(label, "Reads data")
      guard style is Some(style_input) else {
        fail("expected reads-data legend style")
      }
      @debug.assert_eq(style_input.stroke.unwrap().get_value(), "blue")
    }
    _ => fail("expected fourth legend entry to be reads-data connection")
  }

  match legend.entries[4] {
    ConnectionEntry(src_arrow~, dst_arrow~, label~, style~, ..) => {
      @debug.assert_eq(src_arrow, None)
      @debug.assert_eq(dst_arrow, Triangle)
      @debug.assert_eq(label, "Returns results")
      guard style is Some(style_input) else {
        fail("expected returns-results legend style")
      }
      @debug.assert_eq(style_input.stroke_dash.unwrap().get_value(), "5")
    }
    _ => fail("expected fifth legend entry to be returns-results connection")
  }

  assert_true(graph.find_object("user") is Some(_))
  assert_true(graph.find_object("db") is Some(_))
}

///|
test "legend config keeps zero-opacity edges like the reference compiler" {
  let source =
    #|vars: {
    #|  d2-legend: {
    #|    A
    #|    B
    #|    A -> B: Hidden {
    #|      style.opacity: 0
    #|    }
    #|  }
    #|}
  let graph = compile_source_graph(source).unwrap()
  guard graph.legend is Some(legend) else {
    fail("expected legend to be compiled")
  }
  @debug.assert_eq(legend.entry_count(), 3)
  guard legend.entries.last() is Some(last_entry) else {
    fail("expected trailing legend connection entry")
  }
  match last_entry {
    ConnectionEntry(label~, style~, ..) => {
      @debug.assert_eq(label, "Hidden")
      guard style is Some(style_input) else {
        fail("expected style on hidden legend edge")
      }
      @debug.assert_eq(style_input.opacity.unwrap().get_value(), "0")
    }
    _ => fail("expected trailing legend entry to be connection")
  }
}

///|
test "graph objects preserve explicit language and sql constraints" {
  let code_body = @ir.Map::new()
  code_body.add_field(
    @ir.Field::new("shape", Some(@ir.Scalar::string("code")), None, []),
  )
  let column_body = @ir.Map::new()
  column_body.add_field(
    @ir.Field::new(
      "constraint",
      None,
      Some(
        Array(
          @ir.IRArray::new([
            Scalar(@ir.Scalar::string("primary_key")),
            Scalar(@ir.Scalar::string("unique")),
          ]),
        ),
      ),
      [],
    ),
  )
  let table_body = @ir.Map::new()
  table_body.add_field(
    @ir.Field::new("shape", Some(@ir.Scalar::string("sql_table")), None, []),
  )
  table_body.add_field(@ir.Field::new("id", None, Some(Map(column_body)), []))
  let ir = @ir.Map::new()
  ir.add_field(
    @ir.Field::new(
      "snippet",
      Some(@ir.Scalar::string("select 1")),
      Some(Map(code_body)),
      [],
    ),
  )
  ir.add_field(@ir.Field::new("orders", None, Some(Map(table_body)), []))

  let graph = compile("root", ir) catch { e => fail(e.to_string()) }
  guard graph.find_object("snippet") is Some(snippet) else {
    fail("expected code object")
  }
  guard graph.find_object("orders.id") is Some(column) else {
    fail("expected sql column object")
  }
  @debug.assert_eq(snippet.language, Some("text"))
  @debug.assert_eq(column.sql_constraints, ["primary_key", "unique"])
}

///|
test "D2 semicolon arrays apply classes and SQL constraints" {
  let source =
    #|classes: {
    #|  base.style.fill: red
    #|  rounded.style.border-radius: 8
    #|}
    #|box: {
    #|  class: [base; rounded]
    #|}
    #|users: {
    #|  shape: sql_table
    #|  id: int {constraint: [primary_key; unique]}
    #|}
  guard compile_source_graph(source) is Ok(graph) else {
    fail("expected semicolon arrays to compile")
  }
  guard graph.find_object("box") is Some(box) else {
    fail("expected box object")
  }
  guard graph.find_object("users.id") is Some(column) else {
    fail("expected SQL column object")
  }
  @debug.assert_eq(box.classes, ["base", "rounded"])
  guard box.style.fill is Some(fill) else { fail("expected fill style") }
  guard box.style.border_radius is Some(border_radius) else {
    fail("expected border radius")
  }
  @debug.assert_eq(fill.get_value(), "red")
  @debug.assert_eq(border_radius.as_int(), Some(8))
  @debug.assert_eq(column.sql_constraints, ["primary_key", "unique"])
}

///|
test "sql endpoint normalization keeps quoted-dot objects distinct" {
  let source =
    #|"orders.id"
    #|orders: {
    #|  shape: sql_table
    #|  id: int
    #|}
    #|users: {
    #|  shape: sql_table
    #|  id: int
    #|}
    #|"orders.id" -> users.id
    #|orders.id -> users.id
  guard compile_source_graph(source) is Ok(graph) else {
    fail("expected syntax-distinct sql endpoint graph")
  }
  @debug.assert_eq(graph.edges.length(), 2)
  let quoted_edge = graph.edges[0]
  @debug.assert_eq(quoted_edge.src_id, "orders.id")
  @debug.assert_eq(quoted_edge.src_id_syntax, "\"orders.id\"")
  @debug.assert_eq(quoted_edge.src_column_index, None)
  @debug.assert_eq(quoted_edge.dst_id, "users")
  @debug.assert_eq(quoted_edge.dst_id_syntax, "users")
  @debug.assert_eq(quoted_edge.dst_column_index, Some(0))

  let column_edge = graph.edges[1]
  @debug.assert_eq(column_edge.src_id, "orders")
  @debug.assert_eq(column_edge.src_id_syntax, "orders")
  @debug.assert_eq(column_edge.src_column_index, Some(0))
  @debug.assert_eq(column_edge.dst_id, "users")
  @debug.assert_eq(column_edge.dst_id_syntax, "users")
  @debug.assert_eq(column_edge.dst_column_index, Some(0))
}

///|
fn test_range(offset : Int) -> @lexer.Range {
  let start = @lexer.Position::new(0, offset, offset)
  let end = @lexer.Position::new(0, offset + 1, offset + 1)
  @lexer.Range::new(start, end)
}

///|
test "sort_graph_by_references reorders objects edges and children by source ranges" {
  let graph = Graph::new("root")

  let parent = Object::new("parent")
  let child_late = Object::new(
    "parent.late",
    id_val="late",
    id_syntax="late",
    abs_id_syntax="parent.late",
  )
  child_late.references = [
    @graph.ObjectReference::new(
      test_range(40),
      0,
      false,
      Some("parent"),
      None,
      true,
      false,
      false,
    ),
  ]
  let child_early = Object::new(
    "parent.early",
    id_val="early",
    id_syntax="early",
    abs_id_syntax="parent.early",
  )
  child_early.references = [
    @graph.ObjectReference::new(
      test_range(10),
      0,
      false,
      Some("parent"),
      None,
      true,
      false,
      false,
    ),
  ]
  parent.add_child(child_late)
  parent.add_child(child_early)

  let object_late = Object::new("late")
  object_late.references = [
    @graph.ObjectReference::new(
      test_range(30),
      0,
      false,
      Some("root"),
      None,
      true,
      false,
      false,
    ),
  ]
  let object_early = Object::new("early")
  object_early.references = [
    @graph.ObjectReference::new(
      test_range(5),
      0,
      false,
      Some("root"),
      None,
      true,
      false,
      false,
    ),
  ]

  let edge_late = Edge::new(2, "late", "early", false, true)
  edge_late.references = [
    @graph.EdgeReference::new(
      test_range(50),
      2,
      Some("root"),
      None,
      true,
      false,
      false,
    ),
  ]
  let edge_early = Edge::new(1, "early", "late", false, true)
  edge_early.references = [
    @graph.EdgeReference::new(
      test_range(15),
      1,
      Some("root"),
      None,
      true,
      false,
      false,
    ),
  ]

  graph.add_object(object_late)
  graph.add_object(object_early)
  graph.add_object(parent)
  graph.add_edge(edge_late)
  graph.add_edge(edge_early)

  sort_graph_by_references(graph)

  @debug.assert_eq(graph.objects.map(fn(obj) { obj.id }), [
    "early", "late", "parent",
  ])
  @debug.assert_eq(graph.edges.map(fn(edge) { edge.index }), [1, 2])
  @debug.assert_eq(parent.children.map(fn(child) { child.id }), [
    "parent.early", "parent.late",
  ])
}

///|
test "edge ordering ignores glob references that precede direct syntax" {
  let graph = Graph::new("test")
  let later = Edge::new(0, "a", "b", false, true)
  later.references = [
    @graph.EdgeReference::new(
      test_range(1),
      0,
      Some("root"),
      None,
      true,
      true,
      true,
    ),
    @graph.EdgeReference::new(
      test_range(40),
      0,
      Some("root"),
      None,
      true,
      false,
      false,
    ),
  ]
  let earlier = Edge::new(1, "c", "d", false, true)
  earlier.references = [
    @graph.EdgeReference::new(
      test_range(2),
      1,
      Some("root"),
      None,
      true,
      true,
      true,
    ),
    @graph.EdgeReference::new(
      test_range(20),
      1,
      Some("root"),
      None,
      true,
      false,
      false,
    ),
  ]
  graph.add_edge(later)
  graph.add_edge(earlier)
  sort_graph_by_references(graph)
  @debug.assert_eq(graph.edges.map(fn(edge) { edge.index }), [1, 0])
}
