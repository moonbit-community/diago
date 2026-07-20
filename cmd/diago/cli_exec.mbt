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
const CLI_VERSION : String = "0.3.0"

///|
async fn execute_cli_request(request : CliRequest) -> Result[Unit, String] {
  match request.command {
    Render =>
      match request.render {
        Some(render_req) => execute_render(render_req)
        None => Err("internal error: missing render request")
      }
    Fmt =>
      match request.fmt {
        Some(fmt_req) => execute_fmt(fmt_req)
        None => Err("internal error: missing fmt request")
      }
    Validate =>
      match request.validate {
        Some(validate_req) => execute_validate(validate_req)
        None => Err("internal error: missing validate request")
      }
    Layout =>
      match request.layout {
        Some(layout_req) => execute_layout(layout_req)
        None => Err("internal error: missing layout request")
      }
    Themes => {
      list_themes()
      Ok(())
    }
    Version => {
      println(CLI_VERSION)
      Ok(())
    }
    InternalDumpInput =>
      match request.dump_input {
        Some(dump_req) => execute_internal_dump_input(dump_req)
        None => Err("internal error: missing dump-input request")
      }
  }
}

///|
async fn execute_render(request : RenderRequest) -> Result[Unit, String] {
  if request.watch {
    execute_render_watch(request)
  } else {
    execute_render_once(request)
  }
}

///|
async fn execute_render_once(request : RenderRequest) -> Result[Unit, String] {
  if request.from_stdin {
    let source = @fs.read_file("/dev/stdin").text() catch {
      error => return Err("Error reading from stdin: \{error}")
    }
    let compiled = match compile_render_source(request, source, None) {
      Ok(v) => v
      Err(err) => return Err(err)
    }
    let output_target = normalize_output_target(request.output_path)
    return write_render_output(request.output_mode, output_target, compiled)
  }

  let input_path = match request.input_path {
    Some(path_raw) => normalize_input_path(path_raw)
    None => return Err("internal error: missing input path")
  }
  let source = @fs.read_file(input_path).text() catch {
    error => return Err("Error reading file '\{input_path}': \{error}")
  }
  let compiled = match
    compile_render_source(request, source, get_dir_path(input_path)) {
    Ok(v) => v
    Err(err) => return Err(err)
  }
  let output_target = normalize_output_target(request.output_path)
  write_render_output(request.output_mode, output_target, compiled)
}

///|
fn normalize_output_target(output_path : String?) -> String? {
  match output_path {
    Some(path) => if is_stdout_output_path(path) { None } else { Some(path) }
    None => None
  }
}

///|
async fn compile_render_source(
  request : RenderRequest,
  source : String,
  base_path : String?,
) -> Result[CompiledSourceResult, String] {
  let compiled = if request.output_mode == Svg {
    match
      compile_source_with_warnings(
        source,
        request.output_mode,
        request.theme_name,
        base_path,
        request.layout_engine,
        request.layout_explicit,
        request.target_spec,
        dark_theme_id=request.dark_theme_id,
        sketch=request.sketch,
        pad=request.pad,
        center=request.center,
        theme_overrides=request.theme_overrides,
        dark_theme_overrides=request.dark_theme_overrides,
        scale=request.scale,
        no_xml_tag=request.no_xml_tag,
        salt=request.salt,
        omit_version=request.omit_version,
      ) {
      Ok(result) => result
      Err(err) => return Err(err)
    }
  } else {
    match
      compile_source(
        source,
        request.output_mode,
        request.theme_name,
        base_path,
        request.layout_engine,
        request.layout_explicit,
        request.target_spec,
        dark_theme_id=request.dark_theme_id,
        sketch=request.sketch,
        pad=request.pad,
        center=request.center,
        theme_overrides=request.theme_overrides,
        dark_theme_overrides=request.dark_theme_overrides,
        scale=request.scale,
        no_xml_tag=request.no_xml_tag,
        salt=request.salt,
        omit_version=request.omit_version,
      ) {
      Ok(output) => { output, warning: None }
      Err(err) => return Err(err)
    }
  }
  if request.output_mode == Svg && request.bundle {
    let remote = bundle_remote_svg_images(
      compiled.output,
      cache_images=bundle_cache_enabled(),
    )
    Ok({
      output: remote.svg,
      warning: combine_compilation_warning(compiled.warning, remote.error),
    })
  } else {
    Ok(compiled)
  }
}

///|
enum RenderOutputWritePlan {
  WriteOnly
  WriteThenWarn(String)
  WarnOnly(String)
}

///|
fn render_output_write_plan(
  output_mode : OutputMode,
  compiled : CompiledSourceResult,
) -> RenderOutputWritePlan {
  match compiled.warning {
    Some(warning) =>
      if output_mode == Svg {
        WriteThenWarn(warning)
      } else {
        WarnOnly(warning)
      }
    None => WriteOnly
  }
}

///|
async fn write_render_output(
  output_mode : OutputMode,
  output_path : String?,
  compiled : CompiledSourceResult,
) -> Result[Unit, String] {
  match render_output_write_plan(output_mode, compiled) {
    WriteOnly =>
      write_compiled_output(output_mode, output_path, compiled.output)
    WriteThenWarn(warning) =>
      match write_compiled_output(output_mode, output_path, compiled.output) {
        Ok(_) => Err(warning)
        Err(err) => Err(err)
      }
    WarnOnly(warning) => Err(warning)
  }
}

///|
async fn normalize_input_path(input_path : String) -> String {
  if @fs.exists(input_path) {
    let is_dir = (@fs.kind(input_path) == @fs.Directory) catch { _ => false }
    if is_dir {
      @path.Path(input_path).join("index.d2").to_string()
    } else {
      input_path
    }
  } else {
    input_path
  }
}

///|
async fn execute_render_watch(request : RenderRequest) -> Result[Unit, String] {
  if request.from_stdin {
    return Err("--watch cannot be used with --stdin.")
  }
  let input = match request.input_path {
    Some(path_raw) => normalize_input_path(path_raw)
    None => return Err("internal error: missing input path for watch mode")
  }
  let out_path = match request.output_path {
    Some(path) =>
      if is_stdout_output_path(path) {
        return Err("--watch output path cannot be stdout ('-').")
      } else {
        path
      }
    None => replace_extension(input, output_extension(request.output_mode))
  }
  let base_path = get_dir_path(input)
  let mut last_source = @fs.read_file(input).text() catch {
    error => return Err("Error reading file '\{input}': \{error}")
  }
  let initial = compile_render_source(request, last_source, base_path)
  match initial {
    Ok(compiled) =>
      match write_render_output(request.output_mode, Some(out_path), compiled) {
        Ok(_) => ()
        Err(e) => println("Error: \{e}")
      }
    Err(e) => println("Error: \{e}")
  }
  let selected_layout = if request.layout_explicit {
    layout_engine_name(request.layout_engine)
  } else {
    "auto(config|default)"
  }
  println(
    "Watching \{input} (interval=\{request.watch_interval_ms}ms, layout=\{selected_layout})...",
  )

  while true {
    @async.sleep(request.watch_interval_ms)
    let maybe_source = Some(@fs.read_file(input).text()) catch {
      error => {
        let display = "Error reading file '\{input}': \{error}"
        println(display)
        None
      }
    }
    guard maybe_source is Some(source) else { continue }
    if source == last_source {
      continue
    }
    last_source = source
    let result = compile_render_source(request, last_source, base_path)
    match result {
      Ok(compiled) =>
        match
          write_render_output(request.output_mode, Some(out_path), compiled) {
          Ok(_) => ()
          Err(e) => println("Error: \{e}")
        }
      Err(e) => println("Error: \{e}")
    }
  }
  Ok(())
}

///|
async fn execute_fmt(request : FmtRequest) -> Result[Unit, String] {
  let mut unformatted_count = 0
  for file_path in request.files {
    let normalized = normalize_input_path(file_path)
    let source = @fs.read_file(normalized).text() catch {
      error => return Err("Error reading file '\{normalized}': \{error}")
    }
    let (ast, parse_errors) = @compiler.parse(source)
    if !parse_errors.is_empty() {
      return Err("Parse errors in \{normalized}:\n  \{parse_errors}")
    }
    let formatted = @formatter.format(ast, @formatter.FormatConfig::new())
    if source != formatted {
      if request.check {
        unformatted_count = unformatted_count + 1
      } else {
        @fs.write_file(normalized, formatted, create_mode=CreateOrTruncate) catch {
          error => return Err("Error writing file '\{normalized}': \{error}")
        }
      }
    }
  }
  if request.check && unformatted_count > 0 {
    let noun = if unformatted_count == 1 { "file" } else { "files" }
    return Err(
      "found \{unformatted_count} unformatted \{noun}. Run diago fmt to fix.",
    )
  }
  Ok(())
}

///|
async fn execute_validate(request : ValidateRequest) -> Result[Unit, String] {
  let source = if request.from_stdin {
    @fs.read_file("/dev/stdin").text() catch {
      error => return Err("Error reading from stdin: \{error}")
    }
  } else {
    let path_raw = match request.input_path {
      Some(path) => path
      None => return Err("internal error: missing validate input path")
    }
    let path = normalize_input_path(path_raw)
    @fs.read_file(path).text() catch {
      error => return Err("Error reading file '\{path}': \{error}")
    }
  }
  let (ast, parse_errors) = @compiler.parse(source)
  if !parse_errors.is_empty() {
    return Err("Parse errors: \{parse_errors}")
  }
  let ir = @ir.compile(ast) catch { e => return Err("Semantic error: \{e}") }
  let _ = @exporter.to_graph("diagram", ir) catch {
    e => return Err("Graph error: \{e}")
  }
  let display = if request.from_stdin {
    "Input"
  } else {
    request.input_path.unwrap_or("Input")
  }
  println("Success! [\{display}] is valid.")
  Ok(())
}

///|
priv struct LayoutEngineInfo {
  name : String
  short_help : String
  long_help : String
}

///|
let layout_engine_infos : Array[LayoutEngineInfo] = [
  {
    name: "dagre",
    short_help: "Layered graph layout via moon_dagre",
    long_help: (
      #|dagre:
      #|  Layered DAG-oriented layout engine.
      #|  Best for standard directed graph diagrams.
    ),
  },
  {
    name: "elk",
    short_help: "Layered graph layout via moon_elk",
    long_help: (
      #|elk:
      #|  Layered ELK layout engine.
      #|  Supports hierarchy-aware orthogonal routing for complex containers.
    ),
  },
  {
    name: "railway",
    short_help: "Custom railway-style orthogonal layout",
    long_help: (
      #|railway:
      #|  Diago-native experimental orthogonal railway layout engine.
      #|  Useful for deterministic local track routing experiments.
    ),
  },
]

///|
fn execute_layout(request : LayoutRequest) -> Result[Unit, String] {
  match request.engine_name {
    None => {
      println("Available layout engines:")
      for info in layout_engine_infos {
        println("  \{info.name} - \{info.short_help}")
      }
      println("")
      println("Usage:")
      println("  diago render --layout <name> ...")
      println("  diago layout <name>")
      Ok(())
    }
    Some(name) => {
      for info in layout_engine_infos {
        if info.name == name {
          println(info.long_help)
          return Ok(())
        }
      }
      Err(
        "unsupported layout engine '\{name}'. Expected dagre, elk, or railway.",
      )
    }
  }
}

///|
async fn execute_internal_dump_input(
  request : DumpInputRequest,
) -> Result[Unit, String] {
  let input_sources = if request.input_paths.is_empty() {
    match collect_default_dump_input_sources() {
      Ok(paths) => paths
      Err(e) => return Err(e)
    }
  } else {
    request.input_paths
  }
  match ensure_dir_recursive(request.out_dir) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  for input in input_sources {
    let dumped = match
      dump_input_for_file(input, request.out_dir, request.engine) {
      Ok(path) => path
      Err(e) => return Err(e)
    }
    println("dumped \{input} -> \{dumped}")
  }
  Ok(())
}
