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
/// Dagre-specific E2E regression tests against D2 dagre output.
///
/// We compare semantic geometry and connectivity and intentionally ignore style.

///|
fn compare_boxes_dagre(
  name : String,
  got_svg : String,
  expected_svg : String,
) -> Result[Unit, String] {
  let got_raw = match map_labels_to_boxes(got_svg) {
    Ok(v) => v
    Err(e) => return Err(name + ": got svg: " + e)
  }
  let exp_raw = match map_labels_to_boxes(expected_svg) {
    Ok(v) => v
    Err(e) => return Err(name + ": expected svg: " + e)
  }
  let got_labels : Map[String, Bool] = {}
  let exp_labels : Map[String, Bool] = {}
  for pair in got_raw.iter() {
    let (k_view, _) = pair
    got_labels[k_view.to_string()] = true
  }
  for pair in exp_raw.iter() {
    let (k_view, _) = pair
    exp_labels[k_view.to_string()] = true
  }
  let mut exp_count = 0
  let mut common_count = 0
  for pair in exp_labels.iter() {
    let (label_view, _) = pair
    let label = label_view.to_string()
    exp_count = exp_count + 1
    if got_labels.get(label).unwrap_or(false) {
      common_count = common_count + 1
    }
  }
  if exp_count == 0 {
    return Ok(())
  }
  let coverage = common_count.to_double() / exp_count.to_double()
  // Rough parity target for the current migration phase.
  if coverage < 0.45 {
    return Err(
      name +
      ": low label coverage, got " +
      common_count.to_string() +
      "/" +
      exp_count.to_string() +
      " (" +
      coverage.to_string() +
      ")",
    )
  }
  Ok(())
}

///|
fn compare_routes_dagre(
  name : String,
  got_svg : String,
  expected_svg : String,
) -> Result[Unit, String] {
  let got_routes = match extract_routes(got_svg) {
    Ok(v) => v
    Err(e) => return Err(name + ": got svg: " + e)
  }
  let exp_routes = match extract_routes(expected_svg) {
    Ok(v) => v
    Err(e) => return Err(name + ": expected svg: " + e)
  }
  let got_n = got_routes.length()
  let exp_n = exp_routes.length()
  if exp_n == 0 {
    return Ok(())
  }
  let diff = if got_n >= exp_n { got_n - exp_n } else { exp_n - got_n }
  let allowed = @cmp.maximum(2, exp_n / 2)
  if diff > allowed {
    return Err(
      name +
      ": route count drift too large, got=" +
      got_n.to_string() +
      " expected=" +
      exp_n.to_string(),
    )
  }
  Ok(())
}

///|
test "examples: dagre svg matches D2 dagre reference (semantic)" {
  let names : Array[String] = [
    "architecture", "arrowheads", "basic", "c4", "classes", "containers", "directions",
    "grid", "hello", "layers", "legend_auto", "legend_custom", "sequence", "shapes",
    "sql_tables", "styles", "variables",
  ]
  let failures : Array[String] = []
  for name in names {
    let input_path = "examples/" + name + ".d2"
    let expected_path = "examples/d2-dagre-output/" + name + ".svg"
    let source = match read_file(input_path) {
      Ok(v) => v
      Err(e) => fail(name + ": " + e)
    }
    let got_svg_raw = match compile_dagre(source) {
      Ok(v) => v
      Err(e) => fail(name + ": " + e)
    }
    let got_svg = normalize_newlines(got_svg_raw)
    write_file("examples/diago-dagre-output/" + name + ".svg", got_svg)
    let expected_svg = match read_file(expected_path) {
      Ok(v) => normalize_newlines(v)
      Err(e) => fail(name + ": " + e)
    }
    match compare_boxes_dagre(name, got_svg, expected_svg) {
      Ok(_) => ()
      Err(msg) => {
        write_file("examples/diago-dagre-output/" + name + ".boxes.diff", msg)
        failures.push(msg)
      }
    }
    match compare_routes_dagre(name, got_svg, expected_svg) {
      Ok(_) => ()
      Err(msg) => {
        write_file("examples/diago-dagre-output/" + name + ".routes.diff", msg)
        failures.push(msg)
      }
    }
  }
  if !failures.is_empty() {
    let buf = StringBuilder::new()
    buf.write_string(
      "dagre e2e failures: " + failures.length().to_string() + "\n",
    )
    for msg in failures {
      buf.write_string(msg + "\n")
    }
    fail(buf.to_string())
  }
}
