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
/// Dagre SVG E2E tests against committed snapshots.
///
/// This suite validates snapshot stability for all bundled examples
/// (`examples/diago-dagre-output`).

///|
async test "examples: dagre svg e2e snapshots" {
  let dagre_example_names = e2e_example_names().unwrap()
  for name in dagre_example_names {
    let source = read_required_file("examples/" + name + ".d2").unwrap()
    let actual_svg = compile(source).unwrap()
    assert_true(
      actual_svg.contains("<svg"),
      msg="diago svg missing <svg> for \{name}",
    )
    assert_true(
      actual_svg.contains("</svg>"),
      msg="diago svg missing </svg> for \{name}",
    )

    let snapshot_svg = read_required_file(
      "examples/diago-dagre-output/" + name + ".svg",
    ).unwrap()
    assert_eq(
      normalize_svg_snapshot(actual_svg),
      normalize_svg_snapshot(snapshot_svg),
      msg="\{name}: diago dagre svg snapshot mismatch",
    )
  }
}

///|
async fn e2e_example_names() -> Result[Array[String], String] {
  let entries = @fs.readdir("examples") catch {
    error => return Err("failed to read examples directory: \{error}")
  }
  let names : Array[String] = []
  for entry in entries {
    if entry.has_suffix(".d2") {
      names.push(slice_string(entry, 0, entry.length() - 3))
    }
  }
  if names.is_empty() {
    return Err("no example source files found in examples/")
  }
  Ok(sort_strings(names))
}

///|
fn sort_strings(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    out.push(value)
  }
  let mut i = 0
  while i < out.length() {
    let mut j = i + 1
    while j < out.length() {
      if out[j] < out[i] {
        let tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
      }
      j = j + 1
    }
    i = i + 1
  }
  out
}

///|
async fn read_required_file(path : String) -> Result[String, String] {
  try @fs.read_file(path).text() catch {
    error => Err("failed to read '\{path}': \{error}")
  } noraise {
    content => Ok(content)
  }
}

///|
fn normalize_svg_snapshot(svg : String) -> String {
  normalize_svg_wrapper_classes(
    normalize_svg_hashes(
      normalize_image_href_payloads(
        svg.replace(old="\r\n", new="\n").replace(old="\r", new="\n"),
      ),
    ),
  )
  .trim()
  .to_owned()
}

///|
fn normalize_svg_hashes(svg : String) -> String {
  match extract_svg_scope_hash(svg) {
    Some(hash) => replace_all_string(svg, hash, "d2-HASH")
    None => svg
  }
}

///|
fn normalize_svg_wrapper_classes(svg : String) -> String {
  let out = StringBuilder()
  let mut i = 0
  while i < svg.length() {
    if i + 2 <= svg.length() && slice_string(svg, i, i + 2) == "<g" {
      let tag_end = match
        find_substring(slice_string(svg, i, svg.length()), ">") {
        Some(v) => i + v
        None => {
          out.write_string(slice_string(svg, i, svg.length()))
          break
        }
      }
      let tag = slice_string(svg, i, tag_end + 1)
      let normalized = normalize_svg_wrapper_group_tag(tag)
      out.write_string(normalized)
      i = tag_end + 1
      continue
    }
    match svg.code_unit_at(i).to_int().unsafe_to_char().to_string() {
      ch => out.write_string(ch)
    }
    i += 1
  }
  out.to_string()
}

///|
fn extract_svg_scope_hash(svg : String) -> String? {
  let marker = "class=\"d2-"
  let start = match find_substring(svg, marker) {
    Some(v) => v + "class=\"".length()
    None => return None
  }
  let rest = slice_string(svg, start, svg.length())
  let end_rel = match find_substring(rest, " d2-svg\"") {
    Some(v) => v
    None => return None
  }
  Some(slice_string(svg, start, start + end_rel))
}

///|
fn replace_all_string(source : String, old : String, new : String) -> String {
  if old.length() == 0 {
    return source
  }
  let out = StringBuilder()
  let mut cursor = 0
  while cursor < source.length() {
    let rest = slice_string(source, cursor, source.length())
    match find_substring(rest, old) {
      Some(rel) => {
        let hit = cursor + rel
        out.write_string(slice_string(source, cursor, hit))
        out.write_string(new)
        cursor = hit + old.length()
      }
      None => {
        out.write_string(slice_string(source, cursor, source.length()))
        break
      }
    }
  }
  out.to_string()
}

///|
fn normalize_svg_wrapper_group_tag(tag : String) -> String {
  match parse_attr_string(tag, "class") {
    Some(class_value) =>
      match normalize_svg_wrapper_class_value(class_value) {
        Some(normalized) => replace_attr_string_value(tag, "class", normalized)
        None => tag
      }
    None => tag
  }
}

///|
fn normalize_svg_wrapper_class_value(value : String) -> String? {
  let first_space = find_substring(value, " ")
  let first_token = match first_space {
    Some(v) => slice_string(value, 0, v)
    None => value
  }
  if !is_svg_wrapper_class_token(first_token) {
    return None
  }
  let suffix = match first_space {
    Some(v) => slice_string(value, v, value.length())
    None => ""
  }
  Some("__ID__" + suffix)
}

///|
fn is_svg_wrapper_class_token(token : String) -> Bool {
  if token.length() < 8 || token.length() % 4 == 1 {
    return false
  }
  let mut has_signal = false
  let mut seen_padding = false
  let mut padding_count = 0
  for i = 0; i < token.length(); i = i + 1 {
    let ch = token.code_unit_at(i)
    if ch == '=' {
      if i < token.length() - 2 {
        return false
      }
      seen_padding = true
      padding_count += 1
      if padding_count > 2 {
        return false
      }
      has_signal = true
      continue
    }
    if seen_padding {
      return false
    }
    if ('A'.to_int().to_uint16() <= ch && ch <= 'Z'.to_int().to_uint16()) ||
      ('0'.to_int().to_uint16() <= ch && ch <= '9'.to_int().to_uint16()) ||
      ch == '_' {
      has_signal = true
    }
    if ('A'.to_int().to_uint16() <= ch && ch <= 'Z'.to_int().to_uint16()) ||
      ('a'.to_int().to_uint16() <= ch && ch <= 'z'.to_int().to_uint16()) ||
      ('0'.to_int().to_uint16() <= ch && ch <= '9'.to_int().to_uint16()) ||
      ch == '-' ||
      ch == '_' {
      continue
    }
    return false
  }
  has_signal
}

///|
test "normalize_svg_hashes only replaces extracted root hash token" {
  let svg =
    #|<svg><svg class="d2-12345 d2-svg"><style>.d2-12345 .text{font-family:"d2-12345-font-regular"} .other{content:"d2-99999";}</style><mask id="d2-12345"></mask><text>d2-99999</text></svg></svg>
  let normalized = normalize_svg_hashes(svg)
  assert_true(normalized.contains("class=\"d2-HASH d2-svg\""))
  assert_true(normalized.contains(".d2-HASH .text"))
  assert_true(normalized.contains("font-family:\"d2-HASH-font-regular\""))
  assert_true(normalized.contains("id=\"d2-HASH\""))
  assert_true(normalized.contains(">d2-99999<"))
}

///|
test "normalize_svg_wrapper_classes only rewrites group wrapper id token" {
  let svg =
    #|<svg><g class="aW1fYQ== animated-shape foo"></g><g class="shape"></g><rect class="aW1fYQ=="></rect></svg>
  let normalized = normalize_svg_wrapper_classes(svg)
  assert_true(normalized.contains("<g class=\"__ID__ animated-shape foo\">"))
  assert_true(normalized.contains("<g class=\"shape\">"))
  assert_true(normalized.contains("<rect class=\"aW1fYQ==\">"))
}

///|
fn normalize_image_href_payloads(svg : String) -> String {
  let parts = svg.split("<image").collect()
  if parts.length() < 2 {
    return svg
  }
  let out = StringBuilder()
  out.write_string(parts[0].to_owned())
  for i in 1..<parts.length() {
    let part = parts[i].to_owned()
    let close_index = match find_substring(part, "/>") {
      Some(v) => v
      None =>
        match find_substring(part, ">") {
          Some(v) => v
          None => {
            out.write_string("<image")
            out.write_string(part)
            continue
          }
        }
    }
    let attrs = slice_string(part, 0, close_index)
    let suffix = slice_string(part, close_index, part.length())
    out.write_string("<image")
    out.write_string(normalize_single_image_attrs(attrs))
    out.write_string(suffix)
  }
  out.to_string()
}

///|
fn normalize_single_image_attrs(attrs : String) -> String {
  let mut normalized = attrs
  match parse_attr_string(attrs, "href") {
    Some(v) =>
      if should_normalize_image_href(v) {
        normalized = replace_attr_string_value(normalized, "href", "__IMAGE__")
      }
    None => ()
  }
  match parse_attr_string(attrs, "xlink:href") {
    Some(v) =>
      if should_normalize_image_href(v) {
        normalized = replace_attr_string_value(
          normalized, "xlink:href", "__IMAGE__",
        )
      }
    None => ()
  }
  normalized
}

///|
fn should_normalize_image_href(href : String) -> Bool {
  let lower = href.to_lower()
  lower.has_prefix("data:") ||
  lower.has_prefix("http://") ||
  lower.has_prefix("https://")
}

///|
fn replace_attr_string_value(
  attrs : String,
  name : String,
  new_value : String,
) -> String {
  let pattern = name + "=\""
  let start = match find_substring(attrs, pattern) {
    Some(i) => i
    None => return attrs
  }
  let value_start = start + pattern.length()
  let rest = slice_string(attrs, value_start, attrs.length())
  let end_rel = match find_substring(rest, "\"") {
    Some(i) => i
    None => return attrs
  }
  let value_end = value_start + end_rel
  slice_string(attrs, 0, value_start) +
  new_value +
  slice_string(attrs, value_end, attrs.length())
}

///|
#warnings("-unused_value")
fn reference_parity_metrics(
  diago_svg : String,
  d2_svg : String,
) -> (Double, Double, Double, Int32, Double) {
  let diago_labels = extract_text_positions(diago_svg)
  let d2_labels = extract_text_positions(d2_svg)
  let label_distances : Array[Double] = []

  for label, d2_points in d2_labels {
    let diago_points = match diago_labels.get(label) {
      Some(v) => v
      None => []
    }
    for target in d2_points {
      if diago_points.is_empty() {
        label_distances.push(999.0)
      } else {
        let mut best = 1000000000000.0
        for actual in diago_points {
          let dist = euclidean_distance(actual, target)
          if dist < best {
            best = dist
          }
        }
        label_distances.push(best)
      }
    }
  }

  let label_p95 = percentile95(label_distances)
  let label_max = array_max_double(label_distances)

  let diago_edges = extract_edge_endpoints_and_cubic(diago_svg)
  let d2_edges = extract_edge_endpoints_and_cubic(d2_svg)
  let mut edge_endpoint_max = 0.0
  let cubic_param_distances : Array[Double] = []
  for d2_edge in d2_edges {
    let target = d2_edge.0
    let mut best = 1000000000000.0
    let mut best_index = -1
    let mut j = 0
    for diago_edge in diago_edges {
      let dist = endpoint_l1_distance(diago_edge.0, target)
      if dist < best {
        best = dist
        best_index = j
      }
      j = j + 1
    }
    if best > edge_endpoint_max {
      edge_endpoint_max = best
    }
    if d2_edge.1 {
      if best_index >= 0 {
        let matched = diago_edges[best_index]
        if matched.1 {
          cubic_param_distances.push(
            cubic_param_l1_distance(matched.2, d2_edge.2),
          )
        } else {
          cubic_param_distances.push(999.0)
        }
      } else {
        cubic_param_distances.push(999.0)
      }
    }
  }
  let cubic_gap = (count_cubic(diago_edges) - count_cubic(d2_edges)).abs()
  let cubic_param_p95 = percentile95(cubic_param_distances)
  (label_p95, label_max, edge_endpoint_max, cubic_gap, cubic_param_p95)
}

///|
fn extract_text_positions(svg : String) -> Map[String, Array[(Double, Double)]] {
  let positions : Map[String, Array[(Double, Double)]] = Map([])
  let parts = svg.split("<text").collect()
  if parts.length() < 2 {
    return positions
  }
  for i in 1..<parts.length() {
    let part = parts[i].to_owned()
    let gt_parts = part.split(">").collect()
    if gt_parts.length() < 2 {
      continue
    }
    let attrs = gt_parts[0].to_owned()
    let tail = gt_parts[1].to_owned()
    let text_parts = tail.split("</text>").collect()
    if text_parts.length() == 0 {
      continue
    }
    let label = normalize_inline_text(strip_xml_tags(text_parts[0].to_owned()))
    if label.length() == 0 {
      continue
    }
    let x = match parse_attr_double(attrs, "x") {
      Some(v) => v
      None => continue
    }
    let y = match parse_attr_double(attrs, "y") {
      Some(v) => v
      None => continue
    }
    let arr = match positions.get(label) {
      Some(v) => v
      None => []
    }
    arr.push((x, y))
    positions[label] = arr
  }
  positions
}

///|
fn extract_edge_endpoints_and_cubic(
  svg : String,
) -> Array[((Double, Double, Double, Double), Bool, Array[Double])] {
  let result : Array[((Double, Double, Double, Double), Bool, Array[Double])] = []
  let parts = svg.split("<path").collect()
  if parts.length() < 2 {
    return result
  }
  for i in 1..<parts.length() {
    let part = parts[i].to_owned()
    let close_index = match find_substring(part, "/>") {
      Some(v) => v
      None => continue
    }
    let attrs = slice_string(part, 0, close_index)
    let has_marker = attrs.contains("marker-end=") ||
      attrs.contains("marker-start=")
    if !has_marker {
      continue
    }
    let d_value = match parse_attr_string(attrs, "d") {
      Some(v) => v
      None => continue
    }
    let nums = parse_numbers(d_value)
    if nums.length() < 4 {
      continue
    }
    let endpoints = (
      nums[0],
      nums[1],
      nums[nums.length() - 2],
      nums[nums.length() - 1],
    )
    let is_cubic = d_value.contains("C") || d_value.contains("c")
    result.push((endpoints, is_cubic, nums))
  }
  result
}

///|
fn count_cubic(
  edges : Array[((Double, Double, Double, Double), Bool, Array[Double])],
) -> Int32 {
  let mut count = 0
  for edge in edges {
    if edge.1 {
      count = count + 1
    }
  }
  count
}

///|
fn parse_attr_string(attrs : String, name : String) -> String? {
  let pattern = name + "=\""
  let start = match find_substring(attrs, pattern) {
    Some(i) => i + pattern.length()
    None => return None
  }
  let rest = slice_string(attrs, start, attrs.length())
  let end_rel = match find_substring(rest, "\"") {
    Some(i) => i
    None => return None
  }
  Some(slice_string(rest, 0, end_rel))
}

///|
fn parse_attr_double(attrs : String, name : String) -> Double? {
  match parse_attr_string(attrs, name) {
    Some(raw) => parse_double_safe(raw)
    None => None
  }
}

///|
fn parse_numbers(s : String) -> Array[Double] {
  let nums : Array[Double] = []
  let mut sb = StringBuilder()
  for c in s {
    if is_number_char(c) {
      sb.write_char(c)
    } else if sb.to_string().length() > 0 {
      match parse_double_safe(sb.to_string()) {
        Some(v) => nums.push(v)
        None => ()
      }
      sb = StringBuilder()
    }
  }
  if sb.to_string().length() > 0 {
    match parse_double_safe(sb.to_string()) {
      Some(v) => nums.push(v)
      None => ()
    }
  }
  nums
}

///|
fn is_number_char(c : Char) -> Bool {
  (c >= '0' && c <= '9') ||
  c == '.' ||
  c == '-' ||
  c == '+' ||
  c == 'e' ||
  c == 'E'
}

///|
fn percentile95(values : Array[Double]) -> Double {
  if values.is_empty() {
    return 0.0
  }
  let xs = values.copy()
  xs.sort_by((a, b) => a.compare(b))
  let index = (xs.length() - 1) * 95 / 100
  xs[index]
}

///|
fn array_max_double(values : Array[Double]) -> Double {
  if values.is_empty() {
    return 0.0
  }
  let mut best = values[0]
  for v in values {
    if v > best {
      best = v
    }
  }
  best
}

///|
fn euclidean_distance(a : (Double, Double), b : (Double, Double)) -> Double {
  let dx = a.0 - b.0
  let dy = a.1 - b.1
  (dx * dx + dy * dy).sqrt()
}

///|
fn endpoint_l1_distance(
  a : (Double, Double, Double, Double),
  b : (Double, Double, Double, Double),
) -> Double {
  (a.0 - b.0).abs() + (a.1 - b.1).abs() + (a.2 - b.2).abs() + (a.3 - b.3).abs()
}

///|
fn cubic_param_l1_distance(a : Array[Double], b : Array[Double]) -> Double {
  if a.is_empty() || b.is_empty() {
    return 999.0
  }
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let mut sum = 0.0
  for i in 0..<n {
    sum = sum + (a[i] - b[i]).abs()
  }
  let gap = (a.length() - b.length()).abs().to_double()
  sum + gap * 25.0
}

///|
fn find_substring(s : String, pattern : String) -> Int32? {
  if pattern.length() == 0 {
    return Some(0)
  }
  if pattern.length() > s.length() {
    return None
  }
  let limit = s.length() - pattern.length()
  for i = 0; i <= limit; i = i + 1 {
    if slice_string(s, i, i + pattern.length()) == pattern {
      return Some(i)
    }
  }
  None
}

///|
fn parse_double_safe(s : String) -> Double? {
  try @string.parse_double(s) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
fn slice_string(s : String, start : Int32, end_exclusive : Int32) -> String {
  let sb = StringBuilder()
  for i in start..<end_exclusive {
    match s[i].to_char() {
      Some(c) => sb.write_char(c)
      None => ()
    }
  }
  sb.to_string()
}

///|
fn strip_xml_tags(s : String) -> String {
  let sb = StringBuilder()
  let mut in_tag = false
  for c in s {
    if c == '<' {
      in_tag = true
    } else if c == '>' {
      in_tag = false
    } else if !in_tag {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn normalize_inline_text(s : String) -> String {
  let sb = StringBuilder()
  let mut prev_space = false
  for c in s {
    if is_svg_whitespace(c) {
      if !prev_space {
        sb.write_char(' ')
        prev_space = true
      }
    } else {
      sb.write_char(c)
      prev_space = false
    }
  }
  sb.to_string().trim().to_owned()
}

///|
fn is_svg_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\t' || c == '\r'
}
