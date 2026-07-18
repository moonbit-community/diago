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
test "compile empty map" {
  let zero = @lexer.Position::zero()
  let ast = @ast.Map::new(@lexer.Range::new(zero, zero), [])
  let ir = compile(ast)
  @debug.assert_eq(ir.fields.length(), 0)
  @debug.assert_eq(ir.edges.length(), 0)
}

///|
test "compile simple key" {
  let (ast, _) = @parser.parse("x")
  let ir = compile(ast)
  @debug.assert_eq(ir.fields.length(), 1)
  @debug.assert_eq(ir.fields[0].name, "x")
}

///|
test "leading underscores compile fields into parent object scopes" {
  let source =
    #|root_child: {
    #|  nested: {
    #|    _.sibling
    #|    _._.top
    #|  }
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  guard ir.get_field("root_child") is Some(root_child) else {
    fail("expected root_child")
  }
  guard root_child.map() is Some(root_child_map) else {
    fail("expected root_child map")
  }
  assert_true(root_child_map.has_field("nested"))
  assert_true(root_child_map.has_field("sibling"))
  assert_true(ir.has_field("top"))
  guard root_child_map.get_field("nested") is Some(nested) else {
    fail("expected nested")
  }
  guard nested.map() is Some(nested_map) else { fail("expected nested map") }
  assert_false(nested_map.has_field("_"))
}

///|
test "leading underscores resolve edge scopes and asymmetric endpoints" {
  let source =
    #|container: {
    #|  local
    #|  _.outside -> local
    #|  (_.outside -> local)[0]: updated
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  @debug.assert_eq(ir.edges.length(), 1)
  let edge = ir.edges[0]
  @debug.assert_eq(edge.id.src_path, ["outside"])
  @debug.assert_eq(edge.id.dst_path, ["container", "local"])
  @debug.assert_eq(
    edge.primary.map(fn(value) { value.to_string() }),
    Some("updated"),
  )
  assert_true(ir.has_field("outside"))
  guard ir.get_field("container") is Some(container) else {
    fail("expected container")
  }
  guard container.map() is Some(container_map) else {
    fail("expected container map")
  }
  assert_true(container_map.has_field("local"))
  assert_false(container_map.has_field("_"))
}

///|
test "import-aware compiler preserves leading underscore scope semantics" {
  let source =
    #|christmas: { presents }
    #|birthdays: {
    #|  presents
    #|  _.christmas.presents -> presents: regift
    #|  _.christmas.style.fill: "#ACE1AF"
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let resolver = ImportResolver::new(fn(_path) { None })
  let ir = compile_with_imports(ast, resolver)
  assert_false(ir.get_field("birthdays").unwrap().map().unwrap().has_field("_"))
  guard ir.get_field("christmas") is Some(christmas) else {
    fail("expected christmas")
  }
  guard christmas.map() is Some(christmas_map) else {
    fail("expected christmas map")
  }
  guard christmas_map.get_field("style") is Some(style) else {
    fail("expected style")
  }
  guard style.map() is Some(style_map) else { fail("expected style map") }
  @debug.assert_eq(
    style_map.get_field("fill").unwrap().primary.unwrap().to_string(),
    "#ACE1AF",
  )
  @debug.assert_eq(ir.edges.length(), 1)
  @debug.assert_eq(ir.edges[0].id.src_path, ["christmas", "presents"])
  @debug.assert_eq(ir.edges[0].id.dst_path, ["birthdays", "presents"])
}

///|
test "suspend globs remove only targets declared before the operation" {
  let source =
    #|a -> b
    #|c
    #|**: suspend
    #|(** -> **)[*]: suspend
    #|d
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  @debug.assert_eq(ir.fields.map(fn(field) { field.name }), ["d"])
  @debug.assert_eq(ir.edges.length(), 0)
}

///|
test "unsuspending edges restores endpoints and ancestors without relabeling" {
  let source =
    #|a: { b }
    #|c: { d; e }
    #|a.b -> c.d: likes
    #|a.b -> c.e: dislikes
    #|**: suspend
    #|(** -> **)[*]: suspend
    #|(** -> **)[*]: unsuspend {
    #|  &label: likes
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let mut unsuspend_key : @ast.Key? = None
  for node in ast.nodes {
    match node {
      Key(key) =>
        if key_suspension(key) == Some(false) {
          unsuspend_key = Some(key)
        }
      _ => ()
    }
  }
  guard unsuspend_key is Some(unsuspend_key) else {
    fail("expected unsuspend key")
  }
  guard unsuspend_key.value is Some(BlockScalar(_, filter_map)) else {
    fail("expected suspension block")
  }
  @debug.assert_eq(filter_map.nodes.length(), 1)
  guard filter_map.nodes[0] is Key(filter_key) else {
    fail("expected filter key")
  }
  @debug.assert_eq(filter_key.ampersand, true)
  @debug.assert_eq(filter_key.not_ampersand, false)
  @debug.assert_eq(key_suspension(unsuspend_key), Some(false))
  @debug.assert_eq(collect_filters_from_value(unsuspend_key), [
    (false, "label", "likes"),
  ])
  let ir = compile_with_imports(ast, ImportResolver::new(fn(_) { None }))
  @debug.assert_eq(ir.fields.map(fn(field) { field.name }), ["a", "c"])
  @debug.assert_eq(ir.edges.length(), 1)
  @debug.assert_eq(ir.edges[0].primary.unwrap().to_string(), "likes")
  @debug.assert_eq(
    ir.get_field("a").unwrap().map().unwrap().fields.map(fn(field) {
      field.name
    }),
    ["b"],
  )
  @debug.assert_eq(
    ir.get_field("c").unwrap().map().unwrap().fields.map(fn(field) {
      field.name
    }),
    ["d"],
  )
}

///|
test "quoted suspension words remain ordinary labels" {
  let source =
    #|a: "suspend"
    #|a -> a: "unsuspend"
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  @debug.assert_eq(ir.fields[0].primary.unwrap().to_string(), "suspend")
  @debug.assert_eq(ir.edges[0].primary.unwrap().to_string(), "unsuspend")
}

///|
test "recursive edge suspension filters include nested edges with absolute endpoints" {
  let source =
    #|restaurants: {
    #|  chip
    #|  bk
    #|  chip -> bk: competes
    #|}
    #|diners: { zack }
    #|diners.zack -> restaurants.bk: likes
    #|**: suspend
    #|(** -> **)[*]: suspend
    #|(** -> **)[*]: unsuspend {
    #|  &dst: restaurants.bk
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile_with_imports(ast, ImportResolver::new(fn(_) { None }))
  @debug.assert_eq(ir.fields.map(fn(field) { field.name }), [
    "restaurants", "diners",
  ])
  @debug.assert_eq(ir.edges.length(), 1)
  guard ir.get_field("restaurants") is Some(restaurants) else {
    fail("expected restaurants")
  }
  guard restaurants.map() is Some(restaurants_map) else {
    fail("expected restaurants map")
  }
  @debug.assert_eq(restaurants_map.fields.map(fn(field) { field.name }), [
    "chip", "bk",
  ])
  @debug.assert_eq(restaurants_map.edges.length(), 1)
}

///|
test "glob blocks compile dotted properties and wildcard filters" {
  let source =
    #|x.link: https://google.com
    #|y
    #|*: {
    #|  &link: *
    #|  style.fill: red
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.map() is Some(x_map) else { fail("expected x map") }
  guard x_map.get_field("style") is Some(style) else { fail("expected style") }
  guard style.map() is Some(style_map) else { fail("expected style map") }
  guard style_map.get_field("fill") is Some(fill) else { fail("expected fill") }
  @debug.assert_eq(
    fill.primary.map(fn(value) { value.to_string() }),
    Some("red"),
  )
  guard ir.get_field("y") is Some(y) else { fail("expected y") }
  assert_true(y.map() is None)
}

///|
test "nested globs apply inside each filtered match" {
  let source =
    #|conversation: {
    #|  shape: sequence_diagram
    #|  alice -> bob
    #|}
    #|**: {
    #|  &shape: sequence_diagram
    #|  **: { shape: person }
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  guard ir.get_field("conversation") is Some(conversation) else {
    fail("expected conversation")
  }
  guard conversation.map() is Some(conversation_map) else {
    fail("expected conversation map")
  }
  for name in ["alice", "bob"] {
    guard conversation_map.get_field(name) is Some(actor) else {
      fail("expected actor")
    }
    guard actor.map() is Some(actor_map) else { fail("expected actor map") }
    guard actor_map.get_field("shape") is Some(shape) else {
      fail("expected shape")
    }
    @debug.assert_eq(
      shape.primary.map(fn(value) { value.to_string() }),
      Some("person"),
    )
  }
}

///|
test "edge glob endpoint filters update only matching edges" {
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
  let ir = compile(ast)
  @debug.assert_eq(ir.edges.length(), 2)
  for edge in ir.edges {
    let expected = if edge.id.dst_path == ["c"] { Some("yellow") } else { None }
    let actual = match edge.map {
      Some(edge_map) =>
        match edge_map.get_field("style") {
          Some(style) =>
            match style.map() {
              Some(style_map) =>
                match style_map.get_field("stroke") {
                  Some(stroke) =>
                    match stroke.primary {
                      Some(value) => Some(value.to_string())
                      None => None
                    }
                  None => None
                }
              None => None
            }
          None => None
        }
      None => None
    }
    @debug.assert_eq(actual, expected)
  }
}

///|
test "compile key with value" {
  let (ast, _) = @parser.parse("x: hello")
  let ir = compile(ast)
  @debug.assert_eq(ir.fields.length(), 1)
  @debug.assert_eq(ir.fields[0].name, "x")
  guard ir.fields[0].primary is Some(p) else { fail("expected primary") }
  @debug.assert_eq(p.to_string(), "hello")
}

///|
test "compile nested keys" {
  let (ast, _) = @parser.parse("a.b.c: value")
  let ir = compile(ast)
  @debug.assert_eq(ir.fields.length(), 1)
  @debug.assert_eq(ir.fields[0].name, "a")
  guard ir.fields[0].composite is Some(Map(m1)) else { fail("expected map") }
  @debug.assert_eq(m1.fields.length(), 1)
  @debug.assert_eq(m1.fields[0].name, "b")
  guard m1.fields[0].composite is Some(Map(m2)) else { fail("expected map") }
  @debug.assert_eq(m2.fields.length(), 1)
  @debug.assert_eq(m2.fields[0].name, "c")
  guard m2.fields[0].primary is Some(p) else { fail("expected primary") }
  @debug.assert_eq(p.to_string(), "value")
}

///|
test "repeated map declarations merge their fields" {
  let source =
    #|x: {
    #|  a
    #|}
    #|x: {
    #|  b
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.map() is Some(x_map) else { fail("expected x map") }
  assert_true(x_map.has_field("a"))
  assert_true(x_map.has_field("b"))
}

///|
test "field references retain AST context" {
  let (ast, _) = @parser.parse("a.b.c: value")
  let expected_key = match ast.nodes[0] {
    Key(key) => key
    _ => fail("expected key node")
  }
  let ir = compile(ast)
  guard ir.get_field("a") is Some(a_field) else { fail("expected field a") }
  guard a_field.map() is Some(a_map) else { fail("expected map a") }
  guard a_map.get_field("b") is Some(b_field) else { fail("expected field b") }
  guard b_field.map() is Some(b_map) else { fail("expected map b") }
  guard b_map.get_field("c") is Some(c_field) else { fail("expected field c") }
  guard c_field.last_ref() is Some(FieldRef(last_ref)) else {
    fail("expected last field reference")
  }
  @debug.assert_eq(last_ref.string, "c")
  assert_true(last_ref.primary)
  guard last_ref.context() is Some(context) else {
    fail("expected reference context")
  }
  @debug.assert_eq(context.source_path, None)
  @debug.assert_eq(context.key, Some(expected_key))
  guard c_field.last_primary_key() is Some(primary_key) else {
    fail("expected primary key")
  }
  @debug.assert_eq(primary_key, expected_key)
  guard c_field.ast() is Some(StringValue(syntax)) else {
    fail("expected string AST node")
  }
  @debug.assert_eq(syntax.content(), "c")
}

///|
test "bare key fields retain name syntax and non-primary references" {
  let (ast, _) = @parser.parse("\"style\"")
  let quoted_syntax = match ast.nodes[0] {
    Key(key) =>
      match key.key {
        Some(key_path) => key_path.path[0]
        None => fail("expected key path")
      }
    _ => fail("expected key node")
  }
  let ir = compile(ast)
  @debug.assert_eq(ir.get_field("style"), None)
  guard ir.get_field_by_syntax(quoted_syntax) is Some(field) else {
    fail("expected quoted style field")
  }
  @debug.assert_eq(field.name, "style")
  assert_false(field.name_is_unquoted())
  guard field.name_syntax() is Some(DoubleQuoted(_)) else {
    fail("expected double-quoted field syntax")
  }
  guard field.last_ref() is Some(FieldRef(reference)) else {
    fail("expected field reference")
  }
  assert_false(reference.primary)
}

///|
test "compile edge" {
  let (ast, _) = @parser.parse("a -> b")
  let ir = compile(ast)
  @debug.assert_eq(ir.edges.length(), 1)
  @debug.assert_eq(ir.edges[0].id.src_path, ["a"])
  @debug.assert_eq(ir.edges[0].id.dst_path, ["b"])
  assert_false(ir.edges[0].id.src_arrow)
  assert_true(ir.edges[0].id.dst_arrow)
  // Source and destination fields should exist
  assert_true(ir.has_field("a"))
  assert_true(ir.has_field("b"))
}

///|
test "edge endpoints append field references in source order" {
  let source =
    #|b: {
    #|  1 -> 2
    #|  2
    #|  1
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("b") is Some(b_field) else { fail("expected field b") }
  guard b_field.map() is Some(b_map) else { fail("expected map b") }
  guard b_map.get_field("1") is Some(one) else { fail("expected field 1") }
  guard b_map.get_field("2") is Some(two) else { fail("expected field 2") }
  assert_true(one.references.length() >= 2)
  assert_true(two.references.length() >= 2)
  assert_true(
    one.references[0].range.start.offset < two.references[0].range.start.offset,
  )
  guard one.references[0].context() is Some(one_context) else {
    fail("expected field 1 edge context")
  }
  guard two.references[0].context() is Some(two_context) else {
    fail("expected field 2 edge context")
  }
  assert_true(one_context.edge is Some(_))
  assert_true(two_context.edge is Some(_))
}

///|
test "edge ids preserve quoted endpoint syntax" {
  let (ast, _) = @parser.parse("\"style\" -> target")
  let quoted_src = match ast.nodes[0] {
    Key(key) => key.edges[0].src.path[0]
    _ => fail("expected edge key")
  }
  let ir = compile(ast)
  @debug.assert_eq(ir.edges.length(), 1)
  let edge = ir.edges[0]
  @debug.assert_eq(edge.id.src_path, ["style"])
  let src_path_syntax = edge.id.src_path_syntax()
  guard src_path_syntax[0] is DoubleQuoted(_) else {
    fail("expected quoted source path syntax")
  }
  @debug.assert_eq(src_path_syntax[0], quoted_src)
  @debug.assert_eq(ir.get_field("style"), None)
  guard ir.get_field_by_syntax(quoted_src) is Some(src_field) else {
    fail("expected quoted source field")
  }
  assert_false(src_field.name_is_unquoted())
}

///|
test "edge references retain context for glob expansions" {
  let source =
    #|a
    #|c
    #|* -> c
  let (ast, _) = @parser.parse(source)
  let expected_key = match ast.nodes[2] {
    Key(key) => key
    _ => fail("expected edge key")
  }
  let ir = compile(ast)
  @debug.assert_eq(ir.edges.length(), 1)
  let edge = ir.edges[0]
  guard edge.last_ref() is Some(EdgeRef(reference)) else {
    fail("expected edge reference")
  }
  assert_true(reference.due_to_glob)
  guard reference.context() is Some(context) else {
    fail("expected edge context")
  }
  @debug.assert_eq(context.key, Some(expected_key))
  guard context.edge is Some(edge_ast) else { fail("expected edge ast") }
  assert_true(edge_ast.src.has_glob())
  guard edge.ast() is Some(Edge(ast_edge)) else {
    fail("expected edge AST node")
  }
  @debug.assert_eq(ast_edge, edge_ast)
}

///|
test "compile edge with label" {
  let (ast, _) = @parser.parse("a -> b: connection")
  let ir = compile(ast)
  @debug.assert_eq(ir.edges.length(), 1)
  guard ir.edges[0].primary is Some(p) else { fail("expected primary") }
  @debug.assert_eq(p.to_string(), "connection")
}

///|
test "compile edge between sequence diagram objects" {
  let source =
    #|A: hello {
    #|  shape: sequence_diagram
    #|}
    #|
    #|B: goodbye {
    #|  shape: sequence_diagram
    #|}
    #|
    #|A->B
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  assert_true(ir.has_field("A"))
  assert_true(ir.has_field("B"))
  @debug.assert_eq(ir.edges.length(), 1)
  @debug.assert_eq(ir.edges[0].id.src_path, ["A"])
  @debug.assert_eq(ir.edges[0].id.dst_path, ["B"])
}

///|
test "compile reverse edge" {
  let (ast, _) = @parser.parse("a <- b")
  let ir = compile(ast)
  @debug.assert_eq(ir.edges.length(), 1)
  assert_true(ir.edges[0].id.src_arrow)
  assert_false(ir.edges[0].id.dst_arrow)
}

///|
test "compile bidirectional edge" {
  let (ast, _) = @parser.parse("a <-> b")
  let ir = compile(ast)
  @debug.assert_eq(ir.edges.length(), 1)
  assert_true(ir.edges[0].id.src_arrow)
  assert_true(ir.edges[0].id.dst_arrow)
}

///|
test "compile block" {
  let source =
    #|container {
    #|  child
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  @debug.assert_eq(ir.fields.length(), 1)
  @debug.assert_eq(ir.fields[0].name, "container")
  guard ir.fields[0].composite is Some(Map(m)) else { fail("expected map") }
  @debug.assert_eq(m.fields.length(), 1)
  @debug.assert_eq(m.fields[0].name, "child")
}

///|
test "compile array" {
  let (ast, _) = @parser.parse("x: [1, 2, 3]")
  let ir = compile(ast)
  @debug.assert_eq(ir.fields.length(), 1)
  guard ir.fields[0].composite is Some(Array(arr)) else {
    fail("expected array")
  }
  @debug.assert_eq(arr.values.length(), 3)
}

///|
test "glob properties preserve array values" {
  let source =
    #|*.class: [text; blue]
    #|x
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.map() is Some(x_map) else { fail("expected x map") }
  guard x_map.get_field("class") is Some(class_field) else {
    fail("expected class")
  }
  guard class_field.array() is Some(classes) else {
    fail("expected class array")
  }
  @debug.assert_eq(classes.values.length(), 2)
}

///|
test "explicit empty array clears an earlier glob array" {
  let source =
    #|*.class: [text; blue]
    #|x: {
    #|  class: []
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.map() is Some(x_map) else { fail("expected x map") }
  guard x_map.get_field("class") is Some(class_field) else {
    fail("expected class")
  }
  guard class_field.array() is Some(classes) else {
    fail("expected class array")
  }
  @debug.assert_eq(classes.values.length(), 0)
}

///|
test "later scalar glob replaces an earlier array glob" {
  let source =
    #|*.class: [text; blue]
    #|1*.class: note
    #|1x
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  guard ir.get_field("1x") is Some(x) else { fail("expected 1x") }
  guard x.map() is Some(x_map) else { fail("expected 1x map") }
  guard x_map.get_field("class") is Some(class_field) else {
    fail("expected class")
  }
  @debug.assert_eq(class_field.primary.unwrap().to_string(), "note")
  assert_true(class_field.composite is None)
}

///|
test "compile boolean values" {
  let (ast, _) = @parser.parse("x: true")
  let ir = compile(ast)
  guard ir.fields[0].primary is Some(p) else { fail("expected primary") }
  assert_true(p.is_bool())
  @debug.assert_eq(p.as_bool(), Some(true))
}

///|
test "compile null value" {
  let (ast, _) = @parser.parse("x: null")
  let ir = compile(ast)
  guard ir.fields[0].primary is Some(p) else { fail("expected primary") }
  assert_true(p.is_null())
}

///|
test "compile number value" {
  let (ast, _) = @parser.parse("x: 42")
  let ir = compile(ast)
  guard ir.fields[0].primary is Some(p) else { fail("expected primary") }
  assert_true(p.is_number())
  @debug.assert_eq(p.to_string(), "42")
}

///|
test "map operations" {
  let m = Map::new()
  m.add_field(Field::simple("a"))
  m.add_field(Field::simple("b"))
  @debug.assert_eq(m.fields.length(), 2)
  assert_true(m.has_field("a"))
  assert_true(m.has_field("A")) // case-insensitive
  assert_false(m.has_field("c"))
  // Get field
  guard m.get_field("a") is Some(f) else { fail("expected field") }
  @debug.assert_eq(f.name, "a")
  // Ensure field (existing)
  let f2 = m.ensure_field("a")
  @debug.assert_eq(f2.name, "a")
  @debug.assert_eq(m.fields.length(), 2) // No new field
  // Ensure field (new)
  let f3 = m.ensure_field("c")
  @debug.assert_eq(f3.name, "c")
  @debug.assert_eq(m.fields.length(), 3) // New field added
  // Delete field
  let deleted = m.delete_field("b")
  assert_true(deleted is Some(_))
  @debug.assert_eq(m.fields.length(), 2)
  assert_false(m.has_field("b"))
}

///|
test "edge id matching" {
  let id1 = EdgeID::new(["a"], ["b"], false, true)
  let id2 = EdgeID::new(["a"], ["b"], false, true)
  let id3 = EdgeID::new(["a"], ["c"], false, true)
  let id4 = EdgeID::new(["A"], ["B"], false, true) // case-insensitive
  assert_true(id1.matches(id2))
  assert_false(id1.matches(id3))
  assert_true(id1.matches(id4))
}

///|
test "edge id with index" {
  let id1 = EdgeID::with_index(["a"], ["b"], false, true, 0)
  let id2 = EdgeID::with_index(["a"], ["b"], false, true, 0)
  let id3 = EdgeID::with_index(["a"], ["b"], false, true, 1)
  assert_true(id1.matches(id2))
  assert_false(id1.matches(id3))
}

///|
test "indexed edge update rejects a missing edge" {
  let source =
    #|(a -> b)[0].style.opacity: 0.4
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  try compile(ast) catch {
    InvalidKey(message) =>
      @debug.assert_eq(message, "indexed edge does not exist")
    err => fail("unexpected error: \{err}")
  } noraise {
    _ => fail("expected indexed edge compilation to fail")
  }
}

///|
test "scenario indexed edge update rejects an out of range index" {
  let source =
    #|a -> b
    #|scenarios: {
    #|  broken: {
    #|    (a -> b)[1].style.opacity: 0.4
    #|  }
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  try compile(ast) catch {
    InvalidKey(message) =>
      @debug.assert_eq(message, "indexed edge does not exist")
    err => fail("unexpected error: \{err}")
  } noraise {
    _ => fail("expected scenario indexed edge compilation to fail")
  }
}

///|
test "scalar operations" {
  let s1 = Scalar::null()
  assert_true(s1.is_null())
  assert_false(s1.is_bool())
  @debug.assert_eq(s1.to_string(), "null")
  let s2 = Scalar::bool(true)
  assert_true(s2.is_bool())
  @debug.assert_eq(s2.as_bool(), Some(true))
  @debug.assert_eq(s2.to_string(), "true")
  let s3 = Scalar::number("3.14")
  assert_true(s3.is_number())
  @debug.assert_eq(s3.to_string(), "3.14")
  let s4 = Scalar::string("hello")
  assert_true(s4.is_string())
  @debug.assert_eq(s4.to_string(), "hello")
}

///|
test "field operations" {
  let f = Field::simple("test")
  @debug.assert_eq(f.name, "test")
  assert_false(f.has_primary())
  assert_false(f.has_composite())
  assert_true(f.map() is None)
  assert_true(f.array() is None)
}

///|
test "value operations" {
  let v1 : Value = Scalar(Scalar::string("test"))
  assert_true(v1.as_scalar() is Some(_))
  assert_true(v1.as_map() is None)
  assert_true(v1.as_array() is None)
  let v2 : Value = Map(Map::new())
  assert_true(v2.as_map() is Some(_))
  let v3 : Value = Array(IRArray::new([]))
  assert_true(v3.as_array() is Some(_))
}

///|
test "glob style.fill applies to all fields" {
  let source =
    #|a
    #|b
    #|*.style.fill: red
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  // Both a and b should have style.fill: red
  for field_name in ["a", "b"] {
    guard ir.get_field(field_name) is Some(field) else {
      fail("no field \{field_name}")
    }
    guard field.composite is Some(Map(m)) else {
      fail("field \{field_name} has no map")
    }
    guard m.get_field("style") is Some(style_field) else {
      fail("field \{field_name} has no style")
    }
    guard style_field.composite is Some(Map(style_map)) else {
      fail("field \{field_name} style has no map")
    }
    guard style_map.get_field("fill") is Some(fill_field) else {
      fail("field \{field_name} style has no fill")
    }
    guard fill_field.primary is Some(p) else {
      fail("field \{field_name} fill has no value")
    }
    @debug.assert_eq(p.to_string(), "red")
  }
}

///|
test "triple glob applies inside layer boards" {
  let source =
    #|***.style.fill: yellow
    #|layers: {
    #|  next: {
    #|    a
    #|  }
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  let target_names : Array[String] = []
  for target in ir.glob_targets(["***"]) {
    target_names.push(target.field.name)
  }
  @debug.assert_eq(target_names, ["a"])
  guard ir.get_field("layers") is Some(layers) &&
    layers.composite is Some(Map(layers_map)) &&
    layers_map.get_field("next") is Some(next) &&
    next.composite is Some(Map(next_map)) &&
    next_map.get_field("a") is Some(a) &&
    a.composite is Some(Map(a_map)) &&
    a_map.get_field("style") is Some(style) &&
    style.composite is Some(Map(style_map)) &&
    style_map.get_field("fill") is Some(fill) &&
    fill.primary is Some(value) else {
    fail("expected layer object a to receive triple-glob fill")
  }
  @debug.assert_eq(value.to_string(), "yellow")
}

///|
test "glob-created properties keep due_to_glob references" {
  let source =
    #|a
    #|*.style.fill: red
  let (ast, _) = @parser.parse(source)
  let expected_key = match ast.nodes[1] {
    Key(key) => key
    _ => fail("expected glob key")
  }
  let ir = compile(ast)
  guard ir.get_field("a") is Some(a_field) else { fail("expected field a") }
  guard a_field.map() is Some(a_map) else { fail("expected field map") }
  guard a_map.get_field("style") is Some(style_field) else {
    fail("expected style field")
  }
  guard style_field.map() is Some(style_map) else { fail("expected style map") }
  guard style_map.get_field("fill") is Some(fill_field) else {
    fail("expected fill field")
  }
  guard fill_field.last_ref() is Some(FieldRef(reference)) else {
    fail("expected fill reference")
  }
  assert_true(reference.due_to_glob)
  @debug.assert_eq(reference.string, "fill")
  guard reference.context() is Some(context) else {
    fail("expected glob context")
  }
  @debug.assert_eq(context.key, Some(expected_key))
}

///|
test "compile with imports applies globs declared before their matches" {
  let source =
    #|***.style.fill: lightblue
    #|a
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile_with_imports(ast, ImportResolver::new(fn(_) { None }))
  guard ir.get_field("a") is Some(a) else { fail("expected a") }
  guard a.map() is Some(a_map) else { fail("expected a map") }
  guard a_map.get_field("style") is Some(style) else { fail("expected style") }
  guard style.map() is Some(style_map) else { fail("expected style map") }
  guard style_map.get_field("fill") is Some(fill) else { fail("expected fill") }
  guard fill.primary is Some(value) else { fail("expected fill value") }
  @debug.assert_eq(value.to_string(), "lightblue")
}

///|
test "compile with imports preserves edge glob endpoint filters" {
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
  let ir = compile_with_imports(ast, ImportResolver::new(fn(_) { None }))
  @debug.assert_eq(ir.edges.length(), 2)
  for edge in ir.edges {
    if edge.id.dst_path == ["b"] {
      assert_true(edge.map is None)
    } else {
      guard edge.map is Some(edge_map) else { fail("expected edge map") }
      guard edge_map.get_field("style") is Some(style) else {
        fail("expected style")
      }
      guard style.map() is Some(style_map) else { fail("expected style map") }
      guard style_map.get_field("stroke") is Some(stroke) else {
        fail("expected stroke")
      }
      @debug.assert_eq(
        stroke.primary.map(fn(value) { value.to_string() }),
        Some("yellow"),
      )
    }
  }
}

///|
test "double glob applies to nested fields" {
  let source =
    #|container {
    #|  child1
    #|  child2
    #|}
    #|**.style.opacity: 0.5
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  // container, child1, and child2 should all have style.opacity: 0.5
  guard ir.get_field("container") is Some(container) else {
    fail("no container")
  }
  guard container.composite is Some(Map(container_map)) else {
    fail("container has no map")
  }
  // Check child1 has opacity
  guard container_map.get_field("child1") is Some(child1) else {
    fail("no child1")
  }
  guard child1.composite is Some(Map(child1_map)) else {
    fail("child1 has no map")
  }
  guard child1_map.get_field("style") is Some(style) else {
    fail("child1 has no style")
  }
  guard style.composite is Some(Map(style_map)) else {
    fail("child1 style has no map")
  }
  guard style_map.get_field("opacity") is Some(opacity) else {
    fail("child1 has no opacity")
  }
  guard opacity.primary is Some(p) else { fail("opacity has no value") }
  @debug.assert_eq(p.to_string(), "0.5")
}

///|
test "double glob edge endpoints select leaf fields only" {
  let source =
    #|zone A: {
    #|  machine A
    #|  machine B: {
    #|    submachine A
    #|    submachine B
    #|  }
    #|}
    #|zone A.** -> load balancer
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  @debug.assert_eq(ir.edges.length(), 3)
  let sources = ir.edges.map(fn(edge) { edge.id.src_path.join(".") })
  @debug.assert_eq(sources, [
    "zone A.machine A", "zone A.machine B.submachine A", "zone A.machine B.submachine B",
  ])
}

///|
test "double glob suspension descends through reserved holders" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-id: 303
    #|  }
    #|}
    #|a
    #|**: suspend
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  guard ir.get_field("vars") is Some(vars) else { fail("expected vars holder") }
  guard vars.map() is Some(vars_map) else { fail("expected vars map") }
  assert_false(vars_map.has_field("d2-config"))
}

///|
test "recursive edge glob preserves arrow-direction matching" {
  let source =
    #|a -> b
    #|a <-> c
    #|(** -> **)[*]: suspend
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  @debug.assert_eq(ir.edges.length(), 1)
  assert_true(ir.edges[0].id.src_arrow)
  assert_true(ir.edges[0].id.dst_arrow)
}

///|
test "suspending endpoints removes unmatched directed edges" {
  let source =
    #|a -> b
    #|a <-> c
    #|**: suspend
    #|(** -> **)[*]: suspend
    #|(** -> **)[*]: unsuspend {
    #|  &src: a
    #|}
    #|(** -> **)[*]: unsuspend {
    #|  &dst: b
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  @debug.assert_eq(ir.fields.map(fn(field) { field.name }), ["a", "b"])
  @debug.assert_eq(ir.edges.length(), 1)
  assert_false(ir.edges[0].id.src_arrow)
  assert_true(ir.edges[0].id.dst_arrow)
}

///|
test "suspending nested endpoints removes unmatched directed edges" {
  let source =
    #|customer
    #|sys.web
    #|sys.spa
    #|sys.mobile
    #|sys.api
    #|sys.database
    #|sys.api: |md
    #|  ## API
    #|| {
    #|  shape: rectangle
    #|}
    #|sys.database: |md
    #|  ## Database
    #|| {
    #|  shape: rectangle
    #|}
    #|email
    #|main
    #|customer -> sys.web
    #|sys.web -> sys.spa
    #|customer -> sys.spa
    #|customer -> sys.mobile
    #|sys.spa -> sys.api
    #|sys.mobile -> sys.api
    #|sys.api -> main
    #|customer -> email
    #|sys.api -> email
    #|sys.database <-> sys.api
    #|**: suspend
    #|(** -> **)[*]: suspend
    #|(** -> **)[*]: unsuspend {
    #|  &src: sys.api
    #|}
    #|(** -> **)[*]: unsuspend {
    #|  &dst: sys.api
    #|}
    #|sys.label.near: bottom-center
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  guard ir.get_field("sys") is Some(sys) else { fail("expected sys") }
  guard sys.map() is Some(sys_map) else { fail("expected sys map") }
  @debug.assert_eq(sys_map.fields.map(fn(field) { field.name }), [
    "spa", "mobile", "api", "label",
  ])
  @debug.assert_eq(ir.edges.length(), 4)
  for edge in ir.edges {
    assert_false(edge.id.src_arrow)
    assert_true(edge.id.dst_arrow)
  }
  let imported = compile_with_imports(ast, ImportResolver::new(fn(_) { None }))
  guard imported.get_field("sys") is Some(imported_sys) else {
    fail("expected imported sys")
  }
  guard imported_sys.map() is Some(imported_sys_map) else {
    fail("expected imported sys map")
  }
  assert_false(imported_sys_map.has_field("database"))
  @debug.assert_eq(imported.edges.length(), 4)
}

///|
test "edge suspension globs respect later explicit declarations" {
  let source =
    #|a
    #|b
    #|**: suspend
    #|(** -> **)[*]: suspend
    #|**: unsuspend {
    #|  &level: 0
    #|}
    #|(** -> **)[*]: unsuspend {
    #|  &src.level: 0
    #|  &dst.level: 0
    #|}
    #|a -> b
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  for
    ir in [
      compile(ast),
      compile_with_imports(ast, ImportResolver::new(fn(_) { None })),
    ] {
    @debug.assert_eq(ir.edges.length(), 1)
    assert_false(ir.edges[0].id.src_arrow)
    assert_true(ir.edges[0].id.dst_arrow)
  }
}

///|
test "edge suspension level filters restore existing root edges" {
  let source =
    #|root_a -> root_b
    #|group: {
    #|  child_a -> child_b
    #|}
    #|**: suspend
    #|(** -> **)[*]: suspend
    #|**: unsuspend {
    #|  &level: 0
    #|}
    #|(** -> **)[*]: unsuspend {
    #|  &src.level: 0
    #|  &dst.level: 0
    #|}
    #|root_b -> root_c
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  for
    ir in [
      compile(ast),
      compile_with_imports(ast, ImportResolver::new(fn(_) { None })),
    ] {
    @debug.assert_eq(
      ir.edges.map(fn(edge) {
        (edge.id.src_path.join("."), edge.id.dst_path.join("."))
      }),
      [("root_a", "root_b"), ("root_b", "root_c")],
    )
    @debug.assert_eq(ir.fields.map(fn(field) { field.name }), [
      "root_a", "root_b", "group", "root_c",
    ])
    guard ir.get_field("group") is Some(group) && group.map() is Some(group_map) else {
      fail("expected root-level group")
    }
    assert_true(group_map.fields.is_empty())
  }
}

///|
test "recursive suspension globs do not suspend object properties" {
  let source =
    #|restaurants: {
    #|  style.stroke-dash: 2
    #|  child
    #|}
    #|**: suspend
    #|*: unsuspend
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  for
    ir in [
      compile(ast),
      compile_with_imports(ast, ImportResolver::new(fn(_) { None })),
    ] {
    guard ir.get_field("restaurants") is Some(restaurants) &&
      restaurants.map() is Some(restaurants_map) &&
      restaurants_map.get_field("style") is Some(style) &&
      style.map() is Some(style_map) &&
      style_map.get_field("stroke-dash") is Some(stroke_dash) &&
      stroke_dash.primary is Some(value) else {
      fail("expected unsuspended object properties")
    }
    assert_eq(value.to_string(), "2")
    assert_false(restaurants_map.has_field("child"))
  }
}

///|
test "filtered unsuspend restores every matching class array" {
  let source =
    #|a: { class: [customer-facing; one] }
    #|b: { class: [two; customer-facing] }
    #|c: { class: [other] }
    #|d: { class: [customer-facing; three] }
    #|**: suspend
    #|**: unsuspend {
    #|  &class: customer-facing
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  for
    ir in [
      compile(ast),
      compile_with_imports(ast, ImportResolver::new(fn(_) { None })),
    ] {
    @debug.assert_eq(ir.fields.map(fn(field) { field.name }), ["a", "b", "d"])
  }
}

///|
test "filtered unsuspend restores every matching spread-import class array" {
  let source =
    #|...@models
    #|**: suspend
    #|**: unsuspend {
    #|  &class: customer-facing
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let resolver = ImportResolver::new(fn(path) {
    if path == "models" || path == "models.d2" {
      Some(
        (
          #|a: { class: [customer-facing; one] }
          #|b: { class: [two; customer-facing] }
          #|c: { class: [other] }
          #|d: { class: [customer-facing; three] }
        ),
      )
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  @debug.assert_eq(ir.fields.map(fn(field) { field.name }), ["a", "b", "d"])
}

///|
test "compile with imports - basic" {
  let source = "common: @common"
  let (ast, _) = @parser.parse(source)
  // Create a resolver that returns content for "common.d2"
  let resolver = ImportResolver::new(fn(path) {
    if path == "common" || path == "common.d2" {
      Some("server\ndatabase")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  // Should have a "common" field with "server" and "database" inside
  guard ir.get_field("common") is Some(common) else { fail("no common field") }
  guard common.composite is Some(Map(common_map)) else {
    fail("common has no map")
  }
  assert_true(common_map.has_field("server"))
  assert_true(common_map.has_field("database"))
}

///|
test "compile with imports materializes indexed scenario edge updates" {
  let source =
    #|a -> b
    #|scenarios: {
    #|  focus: @focus
    #|}
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let resolver = ImportResolver::new(fn(path) {
    if path == "focus" || path == "focus.d2" {
      Some("(a -> b)[0].style.opacity: 0.6")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("scenarios") is Some(scenarios) else {
    fail("expected scenarios")
  }
  guard scenarios.map() is Some(scenarios_map) else {
    fail("expected scenarios map")
  }
  guard scenarios_map.get_field("focus") is Some(focus) else {
    fail("expected focus scenario")
  }
  guard focus.map() is Some(focus_map) else { fail("expected focus map") }
  @debug.assert_eq(focus_map.edges.length(), 1)
  guard focus_map.edges[0].map is Some(edge_map) else {
    fail("expected edge map")
  }
  guard edge_map.get_field("style") is Some(style) else {
    fail("expected edge style")
  }
  guard style.map() is Some(style_map) else { fail("expected style map") }
  guard style_map.get_field("opacity") is Some(opacity) else {
    fail("expected opacity")
  }
  guard opacity.primary is Some(value) else { fail("expected opacity value") }
  @debug.assert_eq(value.to_string(), "0.6")
}

///|
test "compile with imports tracks source path in references" {
  let resolver = ImportResolver::new(fn(path) {
    match path {
      "inner.d2" => Some("service.api: ok")
      _ => None
    }
  })
  let (ast, _) = @parser.parse("common: @inner")
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("common") is Some(inner_field) else {
    fail("expected imported field")
  }
  guard inner_field.map() is Some(inner_map) else {
    fail("expected imported map")
  }
  guard inner_map.get_field("service") is Some(service_field) else {
    fail("expected service field")
  }
  guard service_field.map() is Some(service_map) else {
    fail("expected service map")
  }
  guard service_map.get_field("api") is Some(api_field) else {
    fail("expected api field")
  }
  guard api_field.last_ref() is Some(FieldRef(reference)) else {
    fail("expected imported reference")
  }
  guard reference.context() is Some(context) else {
    fail("expected imported context")
  }
  @debug.assert_eq(context.source_path, Some("inner.d2"))
}

///|
test "compile with imports tracks import AST on imported maps fields and edges" {
  let resolver = ImportResolver::new(fn(path) {
    match path {
      "inner.d2" =>
        Some(
          (
            #|service.api: ok
            #|service -> db: call
          ),
        )
      _ => None
    }
  })
  let (ast, _) = @parser.parse("common: @inner")
  let import_node = match ast.nodes[0] {
    Key(key) =>
      match key.value {
        Some(Import(imp)) => @ast.Node::Import(imp)
        _ => fail("expected import value")
      }
    _ => fail("expected key node")
  }
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("common") is Some(common_field) else {
    fail("expected common field")
  }
  @debug.assert_eq(common_field.import_ast(), None)
  guard common_field.map() is Some(common_map) else {
    fail("expected imported map")
  }
  @debug.assert_eq(common_map.import_ast(), Some(import_node))
  guard common_map.get_field("service") is Some(service_field) else {
    fail("expected service field")
  }
  @debug.assert_eq(service_field.import_ast(), Some(import_node))
  guard service_field.last_ref() is Some(FieldRef(field_ref)) else {
    fail("expected service field ref")
  }
  guard field_ref.context() is Some(field_ctx) else {
    fail("expected service field context")
  }
  @debug.assert_eq(field_ctx.source_path, Some("inner.d2"))
  @debug.assert_eq(common_map.edges.length(), 1)
  let imported_edge = common_map.edges[0]
  @debug.assert_eq(imported_edge.import_ast(), Some(import_node))
  guard imported_edge.last_ref() is Some(EdgeRef(edge_ref)) else {
    fail("expected edge ref")
  }
  guard edge_ref.context() is Some(edge_ctx) else {
    fail("expected edge context")
  }
  @debug.assert_eq(edge_ctx.source_path, Some("inner.d2"))
}

///|
test "compile with imports - spread" {
  let source = "...@common"
  let (ast, _) = @parser.parse(source)
  // Create a resolver that returns content for "common.d2"
  let resolver = ImportResolver::new(fn(path) {
    if path == "common" || path == "common.d2" {
      Some("server\ndatabase")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  // Should have "server" and "database" directly at the root level
  assert_true(ir.has_field("server"))
  assert_true(ir.has_field("database"))
}

///|
test "compile with spread imports tracks import AST on merged fields and edges" {
  let resolver = ImportResolver::new(fn(path) {
    match path {
      "common.d2" =>
        Some(
          (
            #|alpha.beta: ok
            #|alpha -> beta
          ),
        )
      _ => None
    }
  })
  let (ast, _) = @parser.parse("...@common")
  let import_node = match ast.nodes[0] {
    Import(imp) => @ast.Node::Import(imp)
    _ => fail("expected import node")
  }
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("alpha") is Some(alpha_field) else {
    fail("expected alpha field")
  }
  @debug.assert_eq(alpha_field.import_ast(), Some(import_node))
  guard alpha_field.last_ref() is Some(FieldRef(alpha_ref)) else {
    fail("expected alpha ref")
  }
  guard alpha_ref.context() is Some(alpha_ctx) else {
    fail("expected alpha context")
  }
  @debug.assert_eq(alpha_ctx.source_path, Some("common.d2"))
  guard alpha_field.map() is Some(alpha_map) else { fail("expected alpha map") }
  guard alpha_map.get_field("beta") is Some(beta_field) else {
    fail("expected beta field")
  }
  guard beta_field.last_ref() is Some(FieldRef(beta_ref)) else {
    fail("expected beta ref")
  }
  guard beta_ref.context() is Some(beta_ctx) else {
    fail("expected beta context")
  }
  @debug.assert_eq(beta_ctx.source_path, Some("common.d2"))
  @debug.assert_eq(ir.edges.length(), 1)
  let imported_edge = ir.edges[0]
  @debug.assert_eq(imported_edge.import_ast(), Some(import_node))
  guard imported_edge.last_ref() is Some(EdgeRef(edge_ref)) else {
    fail("expected edge ref")
  }
  guard edge_ref.context() is Some(edge_ctx) else {
    fail("expected edge context")
  }
  @debug.assert_eq(edge_ctx.source_path, Some("common.d2"))
}

///|
test "compile with imports - missing import" {
  let source = "missing: @nonexistent"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(_) { None })
  // Should raise an error
  let result : Result[Map, CompileError] = Ok(
    compile_with_imports(ast, resolver),
  ) catch {
    e => Err(e)
  }
  assert_true(result is Err(_))
}

///|
test "compile with imports - selection (nested scalar)" {
  let source = "x: @a.y"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "a" || path == "a.d2" {
      Some("y: meow")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.primary is Some(p) else { fail("expected primary") }
  @debug.assert_eq(p.to_string(), "meow")
}

///|
test "compile with imports - selection (nested array)" {
  let source = "x: @a.y"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "a" || path == "a.d2" {
      Some("y: [1, 2]")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.composite is Some(Array(arr)) else { fail("expected array") }
  @debug.assert_eq(arr.values.length(), 2)
  guard arr.values[0] is Scalar(s0) else { fail("expected scalar") }
  guard arr.values[1] is Scalar(s1) else { fail("expected scalar") }
  @debug.assert_eq(s0.to_string(), "1")
  @debug.assert_eq(s1.to_string(), "2")
}

///|
test "compile with imports - spread selection non-map errors" {
  let source = "...@a.y"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "a" || path == "a.d2" {
      Some("y: meow")
    } else {
      None
    }
  })
  let result : Result[Map, CompileError] = Ok(
    compile_with_imports(ast, resolver),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(ImportError(msg)) =>
      @debug.assert_eq(msg, "cannot spread import non map into map")
    _ => fail("expected ImportError")
  }
}

///|
test "compile with imports - spread array into array" {
  let source = "x: [...@a.y, 3]"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "a" || path == "a.d2" {
      Some("y: [1, 2]")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  guard ir.get_field("x") is Some(x) else { fail("expected x") }
  guard x.composite is Some(Array(arr)) else { fail("expected array") }
  @debug.assert_eq(arr.values.length(), 3)
  guard arr.values[0] is Scalar(s0) else { fail("expected scalar") }
  guard arr.values[1] is Scalar(s1) else { fail("expected scalar") }
  guard arr.values[2] is Scalar(s2) else { fail("expected scalar") }
  @debug.assert_eq(s0.to_string(), "1")
  @debug.assert_eq(s1.to_string(), "2")
  @debug.assert_eq(s2.to_string(), "3")
}

///|
test "compile with imports - cyclic import errors" {
  let source = "...@a"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "a" || path == "a.d2" {
      Some("...@b")
    } else if path == "b" || path == "b.d2" {
      Some("...@a")
    } else {
      None
    }
  })
  let result : Result[Map, CompileError] = Ok(
    compile_with_imports(ast, resolver),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(ImportError(_)) => ()
    _ => fail("expected ImportError")
  }
}

///|
test "compile with imports - pre path normalization" {
  let source = "...@./../.././common"
  let (ast, _) = @parser.parse(source)
  let resolver = ImportResolver::new(fn(path) {
    if path == "../../common" || path == "../../common.d2" {
      Some("server")
    } else {
      None
    }
  })
  let ir = compile_with_imports(ast, resolver)
  assert_true(ir.has_field("server"))
}

///|
test "compile - imports require resolver" {
  let cases = ["common: @common", "...@common", "x: @common", "x: [@common]"]
  for src in cases {
    let (ast, _) = @parser.parse(src)
    let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
      e => Err(e)
    }
    match result {
      Err(ImportError(_)) => ()
      _ => fail("expected ImportError for: \{src}")
    }
  }
}

///|
test "compile vars - spread-in-place (reference behavior)" {
  let source =
    #|vars: {
    #|  person-shape: {
    #|    grid-columns: 1
    #|    grid-rows: 2
    #|    grid-gap: 0
    #|    head
    #|    body
    #|  }
    #|}
    #|
    #|dora: {
    #|  ...${person-shape}
    #|  body
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("dora") is Some(dora) else { fail("expected dora") }
  guard dora.composite is Some(Map(dm)) else { fail("expected dora map") }
  guard dm.fields.length() > 0 else { fail("expected fields") }
  @debug.assert_eq(dm.fields[0].name, "grid-columns")
}

///|
test "compile vars - spread array (reference behavior)" {
  let source =
    #|vars: {
    #|  xs: [1, 2]
    #|}
    #|
    #|a: [...${xs}, 3]
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("a") is Some(a) else { fail("expected a") }
  guard a.composite is Some(Array(arr)) else { fail("expected array") }
  @debug.assert_eq(arr.values.length(), 3)
  guard arr.values[0] is Scalar(s0) else { fail("expected scalar") }
  guard arr.values[1] is Scalar(s1) else { fail("expected scalar") }
  guard arr.values[2] is Scalar(s2) else { fail("expected scalar") }
  @debug.assert_eq(s0.to_string(), "1")
  @debug.assert_eq(s1.to_string(), "2")
  @debug.assert_eq(s2.to_string(), "3")
}

///|
test "compile vars - spread D2 semicolon array" {
  let source =
    #|vars: {
    #|  base: [NOT NULL; UNQ]
    #|}
    #|
    #|constraints: [PK; ...${base}]
  let (ast, errors) = @parser.parse(source)
  assert_true(errors.is_empty())
  let ir = compile(ast)
  guard ir.get_field("constraints") is Some(constraints) else {
    fail("expected constraints")
  }
  guard constraints.composite is Some(Array(arr)) else {
    fail("expected constraints array")
  }
  @debug.assert_eq(arr.values.length(), 3)
  guard arr.values[0] is Scalar(pk) else { fail("expected PK") }
  guard arr.values[1] is Scalar(not_null) else { fail("expected NOT NULL") }
  guard arr.values[2] is Scalar(unq) else { fail("expected UNQ") }
  @debug.assert_eq(pk.to_string(), "PK")
  @debug.assert_eq(not_null.to_string(), "NOT NULL")
  @debug.assert_eq(unq.to_string(), "UNQ")
}

///|
test "compile vars - unresolved substitution errors (reference behavior)" {
  let source = "x: ${missing}"
  let (ast, _) = @parser.parse(source)
  let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidSubstitution(msg)) =>
      @debug.assert_eq(msg, "could not resolve variable \"missing\"")
    _ => fail("expected InvalidSubstitution")
  }
}

///|
test "compile vars - self scope vars doesn't resolve to itself (reference behavior)" {
  let source =
    #|vars: {
    #|  x: a
    #|}
    #|hi: {
    #|  vars: {
    #|    x: ${x}-b
    #|  }
    #|  yo: ${x}
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("hi") is Some(hi) else { fail("expected hi") }
  guard hi.composite is Some(Map(hm)) else { fail("expected hi map") }
  guard hm.get_field("vars") is Some(vars) else { fail("expected vars") }
  guard vars.composite is Some(Map(vm)) else { fail("expected vars map") }
  guard vm.get_field("x") is Some(x) else { fail("expected x") }
  guard x.primary is Some(px) else { fail("expected x primary") }
  @debug.assert_eq(px.to_string(), "a-b")
  guard hm.get_field("yo") is Some(yo) else { fail("expected yo") }
  guard yo.primary is Some(pyo) else { fail("expected yo primary") }
  @debug.assert_eq(pyo.to_string(), "a-b")
}

///|
test "compile vars - spread non-composite errors (reference behavior)" {
  let source =
    #|vars: { x: 1 }
    #|a: { ...${x} }
  let (ast, _) = @parser.parse(source)
  let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidSubstitution(msg)) =>
      @debug.assert_eq(msg, "cannot spread non-composite")
    _ => fail("expected InvalidSubstitution")
  }
}

///|
test "compile vars - spread non-array into array errors (reference behavior)" {
  let source =
    #|vars: { x: { a } }
    #|a: [...${x}]
  let (ast, _) = @parser.parse(source)
  let result : Result[Map, CompileError] = Ok(compile(ast)) catch {
    e => Err(e)
  }
  match result {
    Err(InvalidSubstitution(msg)) =>
      @debug.assert_eq(msg, "cannot spread non-array into array")
    _ => fail("expected InvalidSubstitution")
  }
}

///|
test "compiled IR assigns node paths and parent lookups" {
  let source =
    #|a: {
    #|  b: hello
    #|  c: {
    #|    d: world
    #|  }
    #|  xs: [1, 2]
    #|}
    #|a -> z: edge
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  let root_path = NodePath::root()
  @debug.assert_eq(ir.path(), Some(root_path))

  guard ir.get_field("a") is Some(a_field) else { fail("expected a field") }
  let a_field_path = root_path.append(FieldStep("a", true))
  @debug.assert_eq(a_field.path(), Some(a_field_path))
  guard a_field.parent(ir) is Some(Map(parent_map)) else {
    fail("expected map parent")
  }
  @debug.assert_eq(parent_map.path(), Some(root_path))

  guard a_field.map() is Some(a_map) else { fail("expected a map") }
  let a_map_path = a_field_path.append(CompositeStep)
  @debug.assert_eq(a_map.path(), Some(a_map_path))
  guard a_map.parent(ir) is Some(Field(parent_field)) else {
    fail("expected field parent")
  }
  @debug.assert_eq(parent_field.name, "a")

  guard a_map.get_field("b") is Some(b_field) else { fail("expected b field") }
  let b_field_path = a_map_path.append(FieldStep("b", true))
  @debug.assert_eq(b_field.path(), Some(b_field_path))
  guard b_field.primary is Some(b_scalar) else { fail("expected b scalar") }
  let b_scalar_path = b_field_path.append(PrimaryStep)
  @debug.assert_eq(b_scalar.path(), Some(b_scalar_path))
  guard b_scalar.parent(ir) is Some(Field(parent_of_b_scalar)) else {
    fail("expected b scalar parent")
  }
  @debug.assert_eq(parent_of_b_scalar.name, "b")

  guard a_map.get_field("c") is Some(c_field) else { fail("expected c field") }
  guard c_field.map() is Some(c_map) else { fail("expected c map") }
  let c_map_path = a_map_path.append(FieldStep("c", true)).append(CompositeStep)
  @debug.assert_eq(c_map.path(), Some(c_map_path))
  guard c_map.parent(ir) is Some(Field(parent_of_c_map)) else {
    fail("expected c map parent")
  }
  @debug.assert_eq(parent_of_c_map.name, "c")

  guard a_map.get_field("xs") is Some(xs_field) else {
    fail("expected xs field")
  }
  guard xs_field.array() is Some(xs_array) else { fail("expected xs array") }
  let xs_array_path = a_map_path
    .append(FieldStep("xs", true))
    .append(CompositeStep)
  @debug.assert_eq(xs_array.path(), Some(xs_array_path))
  guard xs_array.parent(ir) is Some(Field(parent_of_xs_array)) else {
    fail("expected xs array parent")
  }
  @debug.assert_eq(parent_of_xs_array.name, "xs")
  guard xs_array.values[0] is Scalar(first_item) else {
    fail("expected first array item")
  }
  let first_item_path = xs_array_path.append(ArrayItemStep(0))
  @debug.assert_eq(first_item.path(), Some(first_item_path))
  guard first_item.parent(ir) is Some(IRArray(parent_array)) else {
    fail("expected array parent")
  }
  @debug.assert_eq(parent_array.path(), Some(xs_array_path))

  @debug.assert_eq(ir.edges.length(), 1)
  let edge = ir.edges[0]
  let edge_path = root_path.append(EdgeStep(edge.id.copy()))
  @debug.assert_eq(edge.path(), Some(edge_path))
  guard edge.parent(ir) is Some(Map(parent_of_edge)) else {
    fail("expected edge parent")
  }
  @debug.assert_eq(parent_of_edge.path(), Some(root_path))
  guard edge.primary is Some(edge_scalar) else { fail("expected edge scalar") }
  let edge_scalar_path = edge_path.append(PrimaryStep)
  @debug.assert_eq(edge_scalar.path(), Some(edge_scalar_path))
  guard edge_scalar.parent(ir) is Some(Edge(parent_edge)) else {
    fail("expected edge scalar parent")
  }
  @debug.assert_eq(parent_edge.id, edge.id)
}

///|
test "quoted reserved fields keep distinct node paths" {
  let source =
    #|style: red
    #|"style": blue
  let (ast, _) = @parser.parse(source)
  let unquoted_syntax = match ast.nodes[0] {
    Key(key) =>
      match key.key {
        Some(key_path) => key_path.path[0]
        None => fail("expected key path")
      }
    _ => fail("expected key node")
  }
  let quoted_syntax = match ast.nodes[1] {
    Key(key) =>
      match key.key {
        Some(key_path) => key_path.path[0]
        None => fail("expected key path")
      }
    _ => fail("expected key node")
  }
  let ir = compile(ast)
  guard ir.get_field_by_syntax(unquoted_syntax) is Some(unquoted_field) else {
    fail("expected unquoted style field")
  }
  guard ir.get_field_by_syntax(quoted_syntax) is Some(quoted_field) else {
    fail("expected quoted style field")
  }
  assert_true(unquoted_field.name_is_unquoted())
  assert_false(quoted_field.name_is_unquoted())
  guard ir.get_field("style") is Some(default_lookup) else {
    fail("expected unquoted default lookup")
  }
  assert_true(default_lookup.name_is_unquoted())
  let quoted_path = NodePath::root().append(FieldStep("style", false))
  @debug.assert_eq(quoted_field.path(), Some(quoted_path))
  guard ir.get_node(quoted_path) is Some(Field(looked_up_quoted)) else {
    fail("expected quoted field lookup by path")
  }
  assert_false(looked_up_quoted.name_is_unquoted())
}

///|
test "map get_node resolves nodes by stored path" {
  let source =
    #|a: {
    #|  c: {
    #|    d: world
    #|  }
    #|  xs: [1, 2]
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  guard ir.get_field("a") is Some(a_field) else { fail("expected a field") }
  guard a_field.map() is Some(a_map) else { fail("expected a map") }
  guard a_map.get_field("c") is Some(c_field) else { fail("expected c field") }
  guard c_field.map() is Some(c_map) else { fail("expected c map") }
  guard c_map.get_field("d") is Some(d_field) else { fail("expected d field") }
  guard d_field.primary is Some(d_scalar) else { fail("expected d scalar") }
  guard d_scalar.path() is Some(d_scalar_path) else {
    fail("expected scalar path")
  }
  guard ir.get_node(d_scalar_path) is Some(Scalar(looked_up_scalar)) else {
    fail("expected scalar lookup")
  }
  @debug.assert_eq(looked_up_scalar.to_string(), "world")

  guard a_map.get_field("xs") is Some(xs_field) else {
    fail("expected xs field")
  }
  guard xs_field.array() is Some(xs_array) else { fail("expected xs array") }
  guard xs_array.path() is Some(xs_array_path) else {
    fail("expected array path")
  }
  guard ir.get_node(xs_array_path) is Some(IRArray(looked_up_array)) else {
    fail("expected array lookup")
  }
  @debug.assert_eq(looked_up_array.values.length(), 2)
}

///|
test "map copy deep clones nested values and reindexes paths" {
  let source =
    #|a: {
    #|  b: hello
    #|  xs: [1, 2]
    #|}
  let (ast, _) = @parser.parse(source)
  let ir = compile(ast)
  let copied = ir.copy()

  ir.add_field(Field::simple("fresh"))
  guard ir.get_field("a") is Some(original_a) else { fail("expected a field") }
  guard original_a.map() is Some(original_a_map) else { fail("expected a map") }
  let _ = original_a_map.delete_field("b")
  guard original_a_map.get_field("xs") is Some(original_xs_field) else {
    fail("expected xs field")
  }
  guard original_xs_field.array() is Some(original_xs_array) else {
    fail("expected xs array")
  }
  original_xs_array.values.push(Scalar(Scalar::number("3")))

  @debug.assert_eq(copied.get_field("fresh"), None)
  guard copied.get_field("a") is Some(copied_a) else {
    fail("expected copied a")
  }
  guard copied_a.map() is Some(copied_a_map) else {
    fail("expected copied a map")
  }
  assert_true(copied_a_map.get_field("b") is Some(_))
  guard copied_a_map.get_field("xs") is Some(copied_xs_field) else {
    fail("expected copied xs field")
  }
  guard copied_xs_field.array() is Some(copied_xs_array) else {
    fail("expected copied xs array")
  }
  @debug.assert_eq(copied_xs_array.values.length(), 2)
  @debug.assert_eq(copied.path(), Some(NodePath::root()))
  guard copied_xs_array.values[0] is Scalar(copied_item) else {
    fail("expected copied item")
  }
  guard copied_item.parent(copied) is Some(IRArray(parent_array)) else {
    fail("expected copied item parent")
  }
  @debug.assert_eq(parent_array.values.length(), 2)
}
