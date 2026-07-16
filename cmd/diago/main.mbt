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
/// Diago - diago diagram compiler
///
/// A MoonBit implementation of the diago diagram language.
/// Usage: diago [options] <input> [output]

///|
enum OutputMode {
  Svg
  Ascii
  Unicode
} derive(Debug, Eq)

///|
fn output_extension(mode : OutputMode) -> String {
  match mode {
    Svg => ".svg"
    Ascii => ".ascii.txt"
    Unicode => ".unicode.txt"
  }
}

///|
fn output_mode_name(mode : OutputMode) -> String {
  match mode {
    Svg => "svg"
    Ascii => "ascii"
    Unicode => "unicode"
  }
}

///|
fn parse_stdout_format(value : String) -> OutputMode? {
  match value.to_lower() {
    "svg" => Some(Svg)
    "ascii" => Some(Ascii)
    "unicode" => Some(Unicode)
    _ => None
  }
}

///|
fn infer_output_mode_from_path(path : String) -> OutputMode? {
  if path.has_suffix(".svg") {
    Some(Svg)
  } else if path.has_suffix(".ascii.txt") {
    Some(Ascii)
  } else if path.has_suffix(".unicode.txt") {
    Some(Unicode)
  } else {
    None
  }
}

///|
fn is_stdout_output_path(path : String) -> Bool {
  path == "-"
}

///|
enum LayoutEngineChoice {
  Dagre
  Elk
  Railway
} derive(Debug, Eq)

///|
enum DumpInputEngine {
  Dagre
  Elk
} derive(Debug, Eq)

///|
priv struct CompiledSourceResult {
  output : String
  warning : String?
}

///|
fn parse_layout_engine(name : String) -> LayoutEngineChoice? {
  match name.to_lower() {
    "dagre" => Some(Dagre)
    "elk" => Some(Elk)
    "railway" => Some(Railway)
    _ => None
  }
}

///|
fn layout_engine_name(engine : LayoutEngineChoice) -> String {
  match engine {
    Dagre => "dagre"
    Elk => "elk"
    Railway => "railway"
  }
}

///|
fn parse_dump_input_engine(name : String) -> DumpInputEngine? {
  match name.to_lower() {
    "dagre" => Some(Dagre)
    "elk" => Some(Elk)
    _ => None
  }
}

///|
async fn main {
  run_cli(@sys.get_cli_args(), @sys.get_env_vars())
}

///|
fn write_compiled_output(
  _output_mode : OutputMode,
  output_path : String?,
  output : String,
) -> Result[Unit, String] {
  match output_path {
    Some(path) => write_output(path, output)
    None => {
      println(output)
      Ok(())
    }
  }
}

///|
fn write_output(path : String, content : String) -> Result[Unit, String] {
  @fs.write_string_to_file(path, content) catch {
    e => return Err("Error writing file '\{path}': \{e}")
  }
  println("Written to \{path}")
  Ok(())
}

///|
fn replace_extension(path : String, new_ext : String) -> String {
  // Find last dot
  let mut last_dot = -1
  for i in 0..<path.length() {
    if path.code_unit_at(i) == '.'.to_int().to_uint16() {
      last_dot = i
    }
  }
  if last_dot > 0 {
    // Build base string manually
    let buf = StringBuilder::new()
    for j in 0..<last_dot {
      buf.write_char(path.code_unit_at(j).to_int().unsafe_to_char())
    }
    buf.to_string() + new_ext
  } else {
    path + new_ext
  }
}

///|
fn collect_default_dump_input_sources() -> Result[Array[String], String] {
  let entries = @fs.read_dir("examples") catch {
    e => return Err("Error reading directory 'examples': \{e}")
  }
  let paths : Array[String] = []
  for entry in entries {
    if entry.has_suffix(".d2") {
      paths.push(@path.Path("examples").join(Path(entry)).to_string())
    }
  }
  paths.sort_by(fn(a, b) { a.compare(b) })
  Ok(paths)
}

///|
fn ensure_dir_recursive(path : String) -> Result[Unit, String] {
  if path.length() == 0 || path == "." {
    return Ok(())
  }
  if @fs.path_exists(path) {
    let exists_as_dir = @fs.is_dir(path) catch { _ => false }
    if exists_as_dir {
      return Ok(())
    }
    return Err("Path '\{path}' exists and is not a directory")
  }
  let parent = @path.Path(path).dirname().to_string()
  if parent.length() > 0 && parent != path {
    match ensure_dir_recursive(parent) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  @fs.create_dir(path) catch {
    e => {
      let exists_as_dir = if @fs.path_exists(path) {
        @fs.is_dir(path) catch {
          _ => false
        }
      } else {
        false
      }
      if exists_as_dir {
        return Ok(())
      }
      return Err("Error creating directory '\{path}': \{e}")
    }
  }
  Ok(())
}

///|
fn dump_input_for_file(
  input_path : String,
  out_dir : String,
  dump_engine : DumpInputEngine,
) -> Result[String, String] {
  let source = @fs.read_file_to_string(input_path) catch {
    e => return Err("Error reading file '\{input_path}': \{e}")
  }
  let (ast, parse_errors) = @compiler.parse(source)
  if !parse_errors.is_empty() {
    return Err("Parse errors in '\{input_path}': \{parse_errors}")
  }

  let resolver = @diago_fs.import_resolver(base_path=get_dir_path(input_path))
  let ir = @ir.compile_with_imports(ast, resolver) catch {
    e => return Err("IR error in '\{input_path}': \{e}")
  }
  let graph_input = @exporter.to_graph("diagram", ir) catch {
    e => return Err("Graph error in '\{input_path}': \{e}")
  }

  let input_json = match dump_engine {
    Elk =>
      @engine_elk.debug_build_elk_input_json(
        graph_input,
        @engine_api.LayoutConfig::new(),
        Down,
      )
    Dagre =>
      @engine_dagre.debug_build_dagre_input_json(
        graph_input,
        @engine_api.LayoutConfig::new(),
        Down,
      ) catch {
        e => return Err("Dagre input build error in '\{input_path}': \{e}")
      }
  }
  let output_name = replace_extension(basename_string(input_path), ".json")
  let out_path = @path.Path(out_dir).join(Path(output_name)).to_string()
  @fs.write_string_to_file(out_path, input_json.stringify(escape_slash=false)) catch {
    e => return Err("Error writing file '\{out_path}': \{e}")
  }
  Ok(out_path)
}

///|
fn basename_string(path : String) -> String {
  @path.Path(path).basename().to_owned()
}

///|
/// Run the watch subcommand
fn parse_interval_ms(s : String, default_value : Int) -> Int {
  match parse_uint(s) {
    Some(v) => if v <= 0 { default_value } else { v }
    None => default_value
  }
}

///|
fn parse_uint(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  let mut acc = 0
  for c in s {
    if c < '0' || c > '9' {
      return None
    }
    acc = acc * 10 + (c.to_int() - '0'.to_int())
  }
  Some(acc)
}

///|
fn parse_theme_id_option(value : String, fallback : Int?) -> Int? {
  match parse_uint(value.trim().to_owned()) {
    Some(v) => Some(v)
    None => fallback
  }
}

///|
fn parse_scale_option(value : String, fallback : Double?) -> Double? {
  let parsed = parse_non_negative_double(value.trim().to_owned())
  match parsed {
    Some(v) => if v > 0.0 { Some(v) } else { fallback }
    None => fallback
  }
}

///|
fn merge_theme_overrides(
  dst : @diagram.ThemeOverrides?,
  src : @diagram.ThemeOverrides?,
) -> @diagram.ThemeOverrides? {
  @diagram.merge_theme_overrides(dst, src)
}

///|
fn parse_override_pairs(raw : String) -> @diagram.ThemeOverrides? {
  let mut out = @diagram.ThemeOverrides::new()
  let mut s = raw.trim().to_owned()
  if s.has_prefix("{") {
    s = s.strip_prefix("{").unwrap().to_owned()
  }
  if s.has_suffix("}") {
    s = s.strip_suffix("}").unwrap().to_owned()
  }
  for pair_raw in s.split(",") {
    let pair = pair_raw.trim().to_owned()
    if pair == "" {
      continue
    }
    let sep = find_pair_separator(pair)
    if sep <= 0 {
      continue
    }
    let key = normalize_override_component(string_slice(pair, 0, sep))
    let value = normalize_override_component(
      string_slice(pair, sep + 1, pair.length()),
    )
    if key != "" && value != "" {
      out = out.with_code(key, value)
    }
  }
  if out.is_empty() {
    None
  } else {
    Some(out)
  }
}

///|
fn find_pair_separator(s : String) -> Int {
  for i in 0..<s.length() {
    let ch = s.code_unit_at(i).to_int().unsafe_to_char()
    if ch == '=' || ch == ':' {
      return i
    }
  }
  -1
}

///|
fn normalize_override_component(s : String) -> String {
  let mut out = s.trim().to_owned()
  if out.has_prefix("\"") && out.has_suffix("\"") && out.length() >= 2 {
    out = string_slice(out, 1, out.length() - 1)
  } else if out.has_prefix("'") && out.has_suffix("'") && out.length() >= 2 {
    out = string_slice(out, 1, out.length() - 1)
  }
  out.trim().to_owned()
}

///|
fn string_slice(s : String, start : Int, end : Int) -> String {
  if start < 0 || end < start || end > s.length() {
    return ""
  }
  let sb = StringBuilder::new()
  for i in start..<end {
    sb.write_char(s.code_unit_at(i).to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
fn parse_non_negative_double(s : String) -> Double? {
  if s.length() == 0 {
    return None
  }
  let mut int_part = 0
  let mut frac_part = 0
  let mut frac_scale = 1
  let mut seen_dot = false
  for c in s {
    if c == '.' {
      if seen_dot {
        return None
      }
      seen_dot = true
      continue
    }
    if c < '0' || c > '9' {
      return None
    }
    let digit = c.to_int() - '0'.to_int()
    if seen_dot {
      frac_part = frac_part * 10 + digit
      frac_scale = frac_scale * 10
    } else {
      int_part = int_part * 10 + digit
    }
  }
  Some(int_part.to_double() + frac_part.to_double() / frac_scale.to_double())
}

///|
fn list_themes() -> Unit {
  println("Available themes:")
  for name in @renderer_svg.list_themes() {
    println("  \{name}")
  }
}

///|
fn compile_source(
  source : String,
  output_mode : OutputMode,
  theme_name : String?,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
  dark_theme_id? : Int? = None,
  sketch? : Bool? = None,
  pad? : Double? = None,
  center? : Bool? = None,
  theme_overrides? : @diagram.ThemeOverrides? = None,
  dark_theme_overrides? : @diagram.ThemeOverrides? = None,
  scale? : Double? = None,
  no_xml_tag? : Bool? = None,
  salt? : String? = None,
  omit_version? : Bool? = None,
) -> Result[String, String] {
  match
    compile_source_with_warnings(
      source,
      output_mode,
      theme_name,
      base_path,
      layout_engine,
      layout_explicit,
      target_spec,
      dark_theme_id~,
      sketch~,
      pad~,
      center~,
      theme_overrides~,
      dark_theme_overrides~,
      scale~,
      no_xml_tag~,
      salt~,
      omit_version~,
    ) {
    Ok(result) =>
      match result.warning {
        Some(warning) => Err(warning)
        None => Ok(result.output)
      }
    Err(err) => Err(err)
  }
}

///|
fn compile_source_with_warnings(
  source : String,
  output_mode : OutputMode,
  theme_name : String?,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
  dark_theme_id? : Int? = None,
  sketch? : Bool? = None,
  pad? : Double? = None,
  center? : Bool? = None,
  theme_overrides? : @diagram.ThemeOverrides? = None,
  dark_theme_overrides? : @diagram.ThemeOverrides? = None,
  scale? : Double? = None,
  no_xml_tag? : Bool? = None,
  salt? : String? = None,
  omit_version? : Bool? = None,
) -> Result[CompiledSourceResult, String] {
  match output_mode {
    Svg =>
      compile_diago_svg_with_warnings(
        source,
        theme_name,
        base_path,
        layout_engine,
        layout_explicit,
        target_spec,
        dark_theme_id~,
        sketch~,
        pad~,
        center~,
        theme_overrides~,
        dark_theme_overrides~,
        scale~,
        no_xml_tag~,
        salt~,
        omit_version~,
      )
    Ascii =>
      match
        compile_diago_ascii(
          source, base_path, layout_engine, layout_explicit, target_spec,
        ) {
        Ok(output) => Ok({ output, warning: None })
        Err(err) => Err(err)
      }
    Unicode =>
      match
        compile_diago_unicode(
          source, base_path, layout_engine, layout_explicit, target_spec,
        ) {
        Ok(output) => Ok({ output, warning: None })
        Err(err) => Err(err)
      }
  }
}

///|
fn compile_diago_svg_with_warnings(
  source : String,
  theme_name : String?,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
  dark_theme_id? : Int? = None,
  sketch? : Bool? = None,
  pad? : Double? = None,
  center? : Bool? = None,
  theme_overrides? : @diagram.ThemeOverrides? = None,
  dark_theme_overrides? : @diagram.ThemeOverrides? = None,
  scale? : Double? = None,
  no_xml_tag? : Bool? = None,
  salt? : String? = None,
  omit_version? : Bool? = None,
) -> Result[CompiledSourceResult, String] {
  match
    compile_with_facade(
      source,
      Svg,
      theme_name,
      base_path,
      layout_engine,
      layout_explicit,
      target_spec,
      dark_theme_id~,
      sketch~,
      pad~,
      center~,
      theme_overrides~,
      dark_theme_overrides~,
      scale~,
      no_xml_tag~,
      salt~,
      omit_version~,
    ) {
    Ok(svg) => {
      let cache_images = bundle_cache_enabled()
      let local_result = bundle_local_svg_images(svg, base_path, cache_images~)
      Ok({ output: local_result.svg, warning: local_result.error })
    }
    Err(err) => Err(err)
  }
}

///|
fn bundle_cache_enabled() -> Bool {
  match @sys.get_env_var("IMG_CACHE") {
    Some(value) => value == "1"
    None => false
  }
}

///|
fn combine_compilation_warning(first : String?, second : String?) -> String? {
  match first {
    Some(a) =>
      match second {
        Some(b) => Some(a + "; " + b)
        None => Some(a)
      }
    None => second
  }
}

///|
/// Compile diago source to ASCII art
fn compile_diago_ascii(
  source : String,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
) -> Result[String, String] {
  compile_with_facade(
    source,
    Ascii,
    None,
    base_path,
    layout_engine,
    layout_explicit,
    target_spec,
  )
}

///|
/// Compile diago source to Unicode box-drawing text
fn compile_diago_unicode(
  source : String,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
) -> Result[String, String] {
  compile_with_facade(
    source,
    Unicode,
    None,
    base_path,
    layout_engine,
    layout_explicit,
    target_spec,
  )
}

///|
fn compile_with_facade(
  source : String,
  output_mode : OutputMode,
  theme_name : String?,
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
  dark_theme_id? : Int? = None,
  sketch? : Bool? = None,
  pad? : Double? = None,
  center? : Bool? = None,
  theme_overrides? : @diagram.ThemeOverrides? = None,
  dark_theme_overrides? : @diagram.ThemeOverrides? = None,
  scale? : Double? = None,
  no_xml_tag? : Bool? = None,
  salt? : String? = None,
  omit_version? : Bool? = None,
) -> Result[String, String] {
  let options = base_compile_options(
      base_path, layout_engine, layout_explicit, target_spec,
    )
    .with_output_mode(to_diago_output_mode(output_mode))
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
  try @diago_core.compile(source, options~) catch {
    err => Err(diago_error_message(err))
  } noraise {
    output => Ok(output)
  }
}

///|
fn base_compile_options(
  base_path : String?,
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
  target_spec : String?,
) -> @diago_core.CompileOptions {
  let parse_options = @diago_core.ParseOptions::new().with_import_resolver(
    Some(@diago_fs.import_resolver(base_path~)),
  )
  @diago_core.CompileOptions::new()
  .with_layout_engine(to_diago_layout_engine(layout_engine, layout_explicit))
  .with_target_spec(target_spec)
  .with_parse_options(parse_options)
}

///|
fn to_diago_output_mode(output_mode : OutputMode) -> @diago_core.OutputMode {
  match output_mode {
    Svg => Svg
    Ascii => Ascii
    Unicode => Unicode
  }
}

///|
fn to_diago_layout_engine(
  layout_engine : LayoutEngineChoice,
  layout_explicit : Bool,
) -> @diago_core.LayoutEngine {
  if !layout_explicit {
    return Auto
  }
  match layout_engine {
    Dagre => Dagre
    Elk => Elk
    Railway => Railway
  }
}

///|
fn diago_error_message(err : @diago_core.DiagoError) -> String {
  match err {
    ParseError(message) => "Parse errors: \{message}"
    IOError(message) => message
    IrError(message) => "IR error: \{message}"
    GraphError(message) => "Graph error: \{message}"
    LayoutError(message) => "Layout error: \{message}"
    RenderError(message) => "Render error: \{message}"
    ConfigError(message) => "Config error: \{message}"
    TargetError(message) => message
  }
}

///|
/// Get directory of a file path
fn get_dir_path(file_path : String) -> String? {
  let path = @path.Path(file_path)
  let dir = path.dirname()
  let dir_str = dir.to_string()
  if dir_str.length() > 0 {
    Some(dir_str)
  } else {
    None
  }
}
