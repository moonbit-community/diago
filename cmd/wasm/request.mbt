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
priv struct WasmFailure {
  error_kind : Int
  message : String
}

///|
priv struct WasmRenderRequest {
  source : String
  options : @diago.CompileOptions
}

///|
fn decode_render_request(json : Json) -> Result[WasmRenderRequest, WasmFailure] {
  guard json is Object(fields) else {
    return invalid_request("request body must be a JSON object")
  }
  for key, _ in fields {
    if !is_request_field(key) {
      return invalid_request("unknown request field `\{key}`")
    }
  }
  let version = match required_int(fields, "version") {
    Ok(version) => version
    Err(message) => return invalid_request(message)
  }
  if version != abi_version_number {
    return Err({
      error_kind: error_unsupported_version,
      message: "unsupported request version \{version}; expected \{abi_version_number}",
    })
  }
  let source = match required_string(fields, "source") {
    Ok(source) => source
    Err(message) => return invalid_request(message)
  }
  let output_name = match string_or_default(fields, "output", "svg") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let output_mode = match parse_output_mode(output_name) {
    Some(value) => value
    None =>
      return invalid_request(
        "field `output` must be one of: svg, ascii, unicode",
      )
  }
  let layout_name = match string_or_default(fields, "layout", "auto") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let layout_engine = match parse_layout_engine(layout_name) {
    Some(value) => value
    None =>
      return invalid_request(
        "field `layout` must be one of: auto, dagre, elk, railway",
      )
  }
  let direction_name = match string_or_default(fields, "direction", "down") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let direction = match parse_direction(direction_name) {
    Some(value) => value
    None =>
      return invalid_request(
        "field `direction` must be one of: down, up, left, right",
      )
  }
  let target = match optional_string(fields, "target") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let render_fields = match optional_object(fields, "render") {
    Ok(Some(value)) => value
    Ok(None) => Map([])
    Err(message) => return invalid_request(message)
  }
  for key, _ in render_fields {
    if !is_render_field(key) {
      return invalid_request("unknown render field `\{key}`")
    }
  }
  let theme_name = match optional_string(render_fields, "themeName") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let dark_theme_id = match optional_int(render_fields, "darkThemeId") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let sketch = match optional_bool(render_fields, "sketch") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let pad = match optional_double(render_fields, "pad") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let center = match optional_bool(render_fields, "center") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let theme_overrides = match
    optional_theme_overrides(render_fields, "themeOverrides") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let dark_theme_overrides = match
    optional_theme_overrides(render_fields, "darkThemeOverrides") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let scale = match optional_double(render_fields, "scale") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let no_xml_tag = match optional_bool(render_fields, "noXmlTag") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let salt = match optional_string(render_fields, "salt") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let omit_version = match optional_bool(render_fields, "omitVersion") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let options = @diago.CompileOptions::new()
    .with_output_mode(output_mode)
    .with_layout_engine(layout_engine)
    .with_direction(direction)
    .with_target_spec(target)
    .with_theme_name(theme_name)
    .with_dark_theme_id(dark_theme_id)
    .with_sketch(sketch)
    .with_pad(pad)
    .with_center(center)
    .with_theme_overrides(theme_overrides)
    .with_dark_theme_overrides(dark_theme_overrides)
    .with_scale(scale)
    .with_no_xml_tag(no_xml_tag)
    .with_salt(salt)
    .with_omit_version(omit_version)
  Ok({ source, options })
}

///|
fn[T] invalid_request(message : String) -> Result[T, WasmFailure] {
  Err({ error_kind: error_invalid_request, message })
}

///|
fn is_request_field(key : String) -> Bool {
  match key {
    "version"
    | "source"
    | "output"
    | "layout"
    | "direction"
    | "target"
    | "render" => true
    _ => false
  }
}

///|
fn is_render_field(key : String) -> Bool {
  match key {
    "themeName"
    | "darkThemeId"
    | "sketch"
    | "pad"
    | "center"
    | "themeOverrides"
    | "darkThemeOverrides"
    | "scale"
    | "noXmlTag"
    | "salt"
    | "omitVersion" => true
    _ => false
  }
}

///|
fn required_string(
  fields : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match fields.get(key) {
    Some(String(value)) => Ok(value)
    Some(_) => Err("field `\{key}` must be a string")
    None => Err("missing required field `\{key}`")
  }
}

///|
fn required_int(
  fields : Map[String, Json],
  key : String,
) -> Result[Int, String] {
  match fields.get(key) {
    Some(Number(value, ..)) => {
      let integer = value.to_int()
      if integer.to_double() == value {
        Ok(integer)
      } else {
        Err("field `\{key}` must be an integer")
      }
    }
    Some(_) => Err("field `\{key}` must be an integer")
    None => Err("missing required field `\{key}`")
  }
}

///|
fn string_or_default(
  fields : Map[String, Json],
  key : String,
  default_value : String,
) -> Result[String, String] {
  match fields.get(key) {
    Some(String(value)) => Ok(value)
    Some(_) => Err("field `\{key}` must be a string")
    None => Ok(default_value)
  }
}

///|
fn optional_string(
  fields : Map[String, Json],
  key : String,
) -> Result[String?, String] {
  match fields.get(key) {
    Some(String(value)) => Ok(Some(value))
    Some(Null) | None => Ok(None)
    Some(_) => Err("field `\{key}` must be a string or null")
  }
}

///|
fn optional_int(
  fields : Map[String, Json],
  key : String,
) -> Result[Int?, String] {
  match fields.get(key) {
    Some(Number(value, ..)) => {
      let integer = value.to_int()
      if integer.to_double() == value {
        Ok(Some(integer))
      } else {
        Err("field `\{key}` must be an integer or null")
      }
    }
    Some(Null) | None => Ok(None)
    Some(_) => Err("field `\{key}` must be an integer or null")
  }
}

///|
fn optional_double(
  fields : Map[String, Json],
  key : String,
) -> Result[Double?, String] {
  match fields.get(key) {
    Some(Number(value, ..)) => Ok(Some(value))
    Some(Null) | None => Ok(None)
    Some(_) => Err("field `\{key}` must be a number or null")
  }
}

///|
fn optional_bool(
  fields : Map[String, Json],
  key : String,
) -> Result[Bool?, String] {
  match fields.get(key) {
    Some(True) => Ok(Some(true))
    Some(False) => Ok(Some(false))
    Some(Null) | None => Ok(None)
    Some(_) => Err("field `\{key}` must be a boolean or null")
  }
}

///|
fn optional_object(
  fields : Map[String, Json],
  key : String,
) -> Result[Map[String, Json]?, String] {
  match fields.get(key) {
    Some(Object(value)) => Ok(Some(value))
    Some(Null) | None => Ok(None)
    Some(_) => Err("field `\{key}` must be an object or null")
  }
}

///|
fn optional_theme_overrides(
  fields : Map[String, Json],
  key : String,
) -> Result[@diagram.ThemeOverrides?, String] {
  let values = match optional_object(fields, key) {
    Ok(Some(value)) => value
    Ok(None) => return Ok(None)
    Err(message) => return Err(message)
  }
  let mut overrides = @diagram.ThemeOverrides::new()
  for code, value in values {
    guard value is String(color) else {
      return Err("field `\{key}.\{code}` must be a string")
    }
    let next = overrides.with_code(code, color)
    if next.get(code) is None {
      return Err("field `\{key}` contains unsupported theme code `\{code}`")
    }
    overrides = next
  }
  if overrides.is_empty() {
    Ok(None)
  } else {
    Ok(Some(overrides))
  }
}

///|
fn parse_output_mode(value : String) -> @diago.OutputMode? {
  match value.to_lower() {
    "svg" => Some(Svg)
    "ascii" => Some(Ascii)
    "unicode" => Some(Unicode)
    _ => None
  }
}

///|
fn parse_layout_engine(value : String) -> @diago.LayoutEngine? {
  match value.to_lower() {
    "auto" => Some(Auto)
    "dagre" => Some(Dagre)
    "elk" => Some(Elk)
    "railway" => Some(Railway)
    _ => None
  }
}

///|
fn parse_direction(value : String) -> @engine_api.Direction? {
  match value.to_lower() {
    "down" => Some(Down)
    "up" => Some(Up)
    "left" => Some(Left)
    "right" => Some(Right)
    _ => None
  }
}
