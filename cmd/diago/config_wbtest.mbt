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
async fn compile_diagram_for_test(
  source : String,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
) -> Result[@diagram.Diagram, String] {
  let options = base_compile_options(
    source, base_path, layout_engine, layout_explicit, target_spec,
  )
  try @diago_core.compile_diagram(source, options~) catch {
    err => Err(diago_error_message(err))
  } noraise {
    diagram => Ok(diagram)
  }
}

///|
async test "vars config theme-id applies when cli theme absent" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-id: 300
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(source, Svg, None, None, Dagre, false, None).unwrap()
  assert_true(svg.contains("text-mono"))
}

///|
async test "cli theme overrides vars config theme-id" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-id: 300
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(
    source,
    Svg,
    Some("Neutral Default"),
    None,
    Dagre,
    false,
    None,
  ).unwrap()
  assert_true(!svg.contains("text-mono"))
}

///|
async test "vars config layout-engine applies when cli layout is not explicit" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    layout-engine: dagre
    #|  }
    #|}
    #|a -> b
    #|a -> c
    #|b -> d
    #|c -> d
  let auto_svg = compile_source(source, Svg, None, None, Dagre, false, None).unwrap()
  let dagre_svg = compile_source(source, Svg, None, None, Dagre, true, None).unwrap()
  @debug.assert_eq(auto_svg, dagre_svg)
}

///|
async test "cli layout overrides invalid vars config layout-engine" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    layout-engine: not-a-layout
    #|  }
    #|}
    #|a -> b
  let cli_result = compile_source(source, Svg, None, None, Dagre, true, None)
  assert_true(cli_result is Ok(_))

  let auto_result = compile_source(source, Svg, None, None, Dagre, false, None)
  match auto_result {
    Ok(_) => fail("expected invalid vars.d2-config layout-engine to fail")
    Err(msg) => assert_true(msg.contains("vars.d2-config.layout-engine"))
  }
}

///|
async test "extract vars config into diagram config" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    sketch: false
    #|    theme-id: 4
    #|    dark-theme-id: 200
    #|    theme-overrides: {
    #|      B1: red
    #|    }
    #|    dark-theme-overrides: {
    #|      N1: white
    #|    }
    #|    pad: 16
    #|    center: true
    #|    layout-engine: dagre
    #|    scale: 1.5
    #|    no-xml-tag: true
    #|    salt: custom-salt
    #|    omit-version: true
    #|    data: {
    #|      owner: platform
    #|      later: [1, 5, 2]
    #|    }
    #|  }
    #|}
    #|a -> b
  let options = base_compile_options(source, None, Dagre, false, None)
  let diagram = @diago_core.compile_diagram(source, options~)
  match diagram.config {
    None => fail("expected diagram config")
    Some(config) => {
      @debug.assert_eq(config.sketch, Some(false))
      @debug.assert_eq(config.theme_id, Some(4))
      @debug.assert_eq(config.dark_theme_id, Some(200))
      @debug.assert_eq(config.theme_overrides.unwrap().get("B1"), Some("red"))
      @debug.assert_eq(
        config.dark_theme_overrides.unwrap().get("N1"),
        Some("white"),
      )
      @debug.assert_eq(config.pad, Some(16.0))
      @debug.assert_eq(config.center, Some(true))
      @debug.assert_eq(config.layout_engine, Some("dagre"))
      @debug.assert_eq(config.scale, Some(1.5))
      @debug.assert_eq(config.no_xml_tag, Some(true))
      @debug.assert_eq(config.salt, Some("custom-salt"))
      @debug.assert_eq(config.omit_version, Some(true))
      @debug.assert_eq(config.data["owner"], Text("platform"))
      @debug.assert_eq(config.data["later"], StringArray(["1", "5", "2"]))
    }
  }
}

///|
async test "vars config data arrays do not break svg rendering" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    data: {
    #|      later: [1, 5, 2]
    #|    }
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(source, Svg, None, None, Dagre, false, None).unwrap()
  assert_true(svg.contains("<svg"))
}

///|
async test "vars config no-xml-tag omits XML declaration" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    no-xml-tag: true
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(source, Svg, None, None, Dagre, false, None).unwrap()
  assert_true(!svg.contains("<?xml"))
}

///|
async test "theme-overrides applies to theme tokens in style" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-overrides: {
    #|      B1: red
    #|    }
    #|  }
    #|}
    #|a: {
    #|  style: {
    #|    fill: B1
    #|  }
    #|}
  let svg = compile_source(source, Svg, None, None, Dagre, false, None).unwrap()
  assert_true(svg.contains("fill=\"red\""))
}

///|
async test "invalid theme-overrides key fails config parsing" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-overrides: {
    #|      ZZ9: red
    #|    }
    #|  }
    #|}
    #|a -> b
  match compile_source(source, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected invalid theme-overrides key to fail")
    Err(msg) => assert_true(msg.contains("\"ZZ9\" is not a valid theme code"))
  }
}

///|
async test "invalid theme-overrides color fails config parsing" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    theme-overrides: {
    #|      B1: definitely-not-a-color
    #|    }
    #|  }
    #|}
    #|a -> b
  match compile_source(source, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected invalid theme-overrides color to fail")
    Err(msg) =>
      assert_true(
        msg.contains(
          "expected \"B1\" to be a valid named color (\"orange\") or a hex code (\"#f0ff3a\")",
        ),
      )
  }
}

///|
async test "dark-theme-id does not replace base light theme when theme-id is absent" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    dark-theme-id: 300
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(source, Svg, None, None, Dagre, false, None).unwrap()
  assert_true(!svg.contains("text-mono"))
}

///|
async test "vars config pad is applied to svg config padding" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    pad: 16
    #|  }
    #|}
    #|a -> b
  let diagram = compile_diagram_for_test(source, None, Dagre, false, None).unwrap()
  guard diagram.config is Some(config) else { fail("expected source config") }
  @debug.assert_eq(config.pad, Some(16.0))
}

///|
async test "vars config center is applied to svg alignment" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    center: true
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(source, Svg, None, None, Dagre, false, None).unwrap()
  assert_true(svg.contains("preserveAspectRatio=\"xMidYMid meet\""))
}

///|
async test "cli center overrides vars config center=false" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    center: false
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(
    source,
    Svg,
    None,
    None,
    Dagre,
    false,
    None,
    center=Some(true),
  ).unwrap()
  assert_true(svg.contains("preserveAspectRatio=\"xMidYMid meet\""))
}

///|
async test "vars config sketch is unsupported" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    sketch: true
    #|  }
    #|}
    #|a -> b
  guard compile_source(source, Svg, None, None, Dagre, false, None)
    is Err(message) else {
    fail("expected sketch error")
  }
  assert_true(message.contains("sketch rendering is not supported"))
}

///|
async test "cli sketch true is unsupported and false remains a no-op" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    sketch: false
    #|  }
    #|}
    #|a -> b
  guard compile_source(
      source,
      Svg,
      None,
      None,
      Dagre,
      false,
      None,
      sketch=Some(false),
    )
    is Ok(_) else {
    fail("sketch=false must remain supported")
  }
  let plain_source =
    #|a -> b
  guard compile_source(
      plain_source,
      Svg,
      None,
      None,
      Dagre,
      false,
      None,
      sketch=Some(true),
    )
    is Err(message) else {
    fail("expected sketch error")
  }
  assert_true(message.contains("sketch rendering is not supported"))
}

///|
async test "vars config dark-theme-id emits dark media css" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    dark-theme-id: 200
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(source, Svg, None, None, Dagre, false, None).unwrap()
  assert_true(svg.contains("@media screen and (prefers-color-scheme:dark)"))
  assert_true(svg.contains(".fill-N7{fill:#1E1E2E;}"))
}

///|
async test "target selection matches the reference board-only vs board-with-children semantics" {
  let source =
    #|layers: {
    #|  core: {
    #|    a -> b
    #|    scenarios: {
    #|      variant: {
    #|        c -> d
    #|      }
    #|    }
    #|  }
    #|}
  let board_only = compile_diagram_for_test(
    source,
    None,
    Dagre,
    false,
    Some("layers.core"),
  ).unwrap()
  let board_with_children = compile_diagram_for_test(
    source,
    None,
    Dagre,
    false,
    Some("layers.core.*"),
  ).unwrap()
  let root_only = compile_diagram_for_test(source, None, Dagre, false, Some("")).unwrap()
  @debug.assert_eq(board_only.scenarios.length(), 0)
  @debug.assert_eq(board_with_children.scenarios.length(), 1)
  @debug.assert_eq(root_only.layers.length(), 0)
}

///|
async test "salt namespaces SVG marker IDs" {
  let source =
    #|vars: {
    #|  d2-config: {
    #|    salt: custom-salt
    #|  }
    #|}
    #|a -> b
  let svg = compile_source(source, Svg, None, None, Dagre, false, None).unwrap()
  assert_true(svg.contains("id=\"mk-d2-"))
  assert_true(svg.contains("url(#mk-d2-"))
}

///|
async test "local image assets are bundled even when remote bundling is disabled" {
  let icon_path = ".diago_bundle_compile_local.svg"
  let icon_svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>
  remove_config_test_file(icon_path)
  @fs.write_file(icon_path, icon_svg, create_mode=CreateOrTruncate)
  let source =
    #|photo: {
    #|  shape: image
    #|  icon: .diago_bundle_compile_local.svg
    #|}
  let svg = compile_source(source, Svg, None, Some("."), Dagre, false, None).unwrap()
  remove_config_test_file(icon_path)
  assert_true(svg.contains("data:image/svg+xml;base64,"))
  assert_false(svg.contains(icon_path))
}

///|
async test "svg compile keeps output when local bundling reports an error" {
  let ok_icon_path = ".diago_bundle_compile_partial_ok.svg"
  let missing_icon_path = ".diago_bundle_compile_partial_missing.svg"
  let icon_svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>
  remove_config_test_file(ok_icon_path)
  @fs.write_file(ok_icon_path, icon_svg, create_mode=CreateOrTruncate)
  let source =
    #|good: {
    #|  shape: image
    #|  icon: .diago_bundle_compile_partial_ok.svg
    #|}
    #|bad: {
    #|  shape: image
    #|  icon: .diago_bundle_compile_partial_missing.svg
    #|}
  let compiled = compile_source_with_warnings(
    source,
    Svg,
    None,
    Some("."),
    Dagre,
    false,
    None,
  ).unwrap()
  remove_config_test_file(ok_icon_path)
  @debug.assert_eq(
    compiled.warning,
    Some(
      "failed to bundle local images: [.diago_bundle_compile_partial_missing.svg]",
    ),
  )
  assert_true(compiled.output.contains("data:image/svg+xml;base64,"))
  assert_true(compiled.output.contains(missing_icon_path))
}

///|
async test "omit-version removes the version attribute" {
  let source_default =
    #|a -> b
  let default_svg = compile_source(
    source_default,
    Svg,
    None,
    None,
    Dagre,
    false,
    None,
  ).unwrap()
  assert_true(default_svg.contains("data-d2-version=\""))

  let source_omit =
    #|vars: {
    #|  d2-config: {
    #|    omit-version: true
    #|  }
    #|}
    #|a -> b
  let omit_svg = compile_source(
    source_omit,
    Svg,
    None,
    None,
    Dagre,
    false,
    None,
  ).unwrap()
  assert_true(!omit_svg.contains("data-d2-version=\""))
}

///|
async test "invalid style keyword fails semantic validation" {
  let source =
    #|a: {
    #|  style: {
    #|    unknown-key: 1
    #|  }
    #|}
  match compile_source(source, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected invalid style keyword to fail")
    Err(msg) => assert_true(msg.contains("invalid style keyword"))
  }
}

///|
async test "url tooltip with link fails semantic validation" {
  let source =
    #|a: {
    #|  link: https://example.com
    #|  tooltip: https://phishing.example
    #|}
  match compile_source(source, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected link + URL tooltip check to fail")
    Err(msg) => assert_true(msg.contains("Tooltip cannot be set to URL"))
  }
}

///|
async fn remove_config_test_file(path : String) -> Unit {
  @fs.remove(path) catch {
    _ => ()
  }
}

///|
async test "near ancestor and edge map non-reserved are rejected" {
  let near_source =
    #|a: {
    #|  b: {
    #|    near: a
    #|  }
    #|}
  match compile_source(near_source, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected near ancestor check to fail")
    Err(msg) =>
      assert_true(msg.contains("near keys cannot be set to an ancestor"))
  }

  let edge_source =
    #|a -> b: hello {
    #|  note: not-allowed
    #|}
  match compile_source(edge_source, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected edge map reserved-key check to fail")
    Err(msg) =>
      assert_true(msg.contains("edge map keys must be reserved keywords"))
  }
}

///|
async test "dagre rejects top/left fixed positioning like the reference" {
  let source =
    #|a: {
    #|  top: 120
    #|  left: 240
    #|}
    #|b
    #|a -> b
  match compile_source(source, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected dagre fixed-position feature check to fail")
    Err(msg) =>
      assert_true(
        msg.contains("does not support locked positions"),
        msg="unexpected error: \{msg}",
      )
  }
}

///|
async test "top/left must be non-negative integers" {
  let non_integer_top =
    #|a: {
    #|  top: abc
    #|}
  match compile_source(non_integer_top, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected non-integer top to fail")
    Err(msg) => assert_true(msg.contains("non-integer top"))
  }

  let negative_left =
    #|a: {
    #|  left: -2
    #|}
  match compile_source(negative_left, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected negative left to fail")
    Err(msg) => assert_true(msg.contains("left must be a non-negative integer"))
  }
}

///|
async test "top/left compatibility checks for hierarchy sequence and grid" {
  let hierarchy_source =
    #|x: {
    #|  shape: hierarchy
    #|  a: {
    #|    top: 20
    #|  }
    #|}
  match compile_source(hierarchy_source, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected hierarchy compatibility check to fail")
    Err(msg) =>
      assert_true(msg.contains("position keywords cannot be used with shape"))
  }

  let sequence_source =
    #|shape: sequence_diagram
    #|a: {
    #|  left: 20
    #|}
  match compile_source(sequence_source, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected sequence compatibility check to fail")
    Err(msg) =>
      assert_true(msg.contains("position keywords cannot be used inside shape"))
  }

  let grid_source =
    #|g: {
    #|  grid-rows: 1
    #|  a: {
    #|    left: 20
    #|  }
    #|}
  match compile_source(grid_source, Svg, None, None, Dagre, false, None) {
    Ok(_) => fail("expected grid compatibility check to fail")
    Err(msg) =>
      assert_true(msg.contains("position keywords cannot be used with grids"))
  }
}

///|
async test "format parser supports supported format names" {
  guard parse_stdout_format("svg") is Some(Svg) else {
    fail("svg should parse")
  }
  guard parse_stdout_format("ascii") is Some(Ascii) else {
    fail("ascii should parse")
  }
  guard parse_stdout_format("unicode") is Some(Unicode) else {
    fail("unicode should parse")
  }
  guard parse_stdout_format("bad-format") is None else {
    fail("unknown format should fail")
  }
}

///|
async test "output mode can be inferred from output extension" {
  guard infer_output_mode_from_path("diagram.svg") is Some(Svg) else {
    fail("svg extension should map to svg mode")
  }
  guard infer_output_mode_from_path("diagram.ascii.txt") is Some(Ascii) else {
    fail("ascii text extension should map to ascii mode")
  }
  guard infer_output_mode_from_path("diagram.unicode.txt") is Some(Unicode) else {
    fail("unicode text extension should map to unicode mode")
  }
  guard infer_output_mode_from_path("diagram") is None else {
    fail("unknown extension should not infer mode")
  }
}

///|
async test "layout parser supports dagre elk railway" {
  guard parse_layout_engine("dagre") is Some(Dagre) else {
    fail("dagre should parse")
  }
  guard parse_layout_engine("elk") is Some(Elk) else {
    fail("elk should parse")
  }
  guard parse_layout_engine("railway") is Some(Railway) else {
    fail("railway should parse")
  }
  guard parse_layout_engine("bad-layout") is None else {
    fail("unknown layout should fail")
  }
  @debug.assert_eq(layout_engine_name(Elk), "elk")
}

///|
async test "ascii and unicode output modes render different text charsets" {
  let source =
    #|a -> b
  let ascii_output = compile_source(
    source,
    Ascii,
    None,
    None,
    Dagre,
    false,
    None,
  ).unwrap()
  let unicode_output = compile_source(
    source,
    Unicode,
    None,
    None,
    Dagre,
    false,
    None,
  ).unwrap()
  assert_true(ascii_output.contains("+"))
  assert_true(unicode_output.contains("┌"))
  assert_true(ascii_output != unicode_output)
}

///|
async test "basename helper resolves file name for dump output paths" {
  @debug.assert_eq(basename_string("foo/bar/diagram.svg"), "diagram.svg")
}
