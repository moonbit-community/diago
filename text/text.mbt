///|
/// Text output formats. This package does not depend on SVG rendering or fonts.
#derive(Debug, Eq)
pub(all) enum OutputMode {
  Ascii
  Unicode
}

///|
#derive(Debug)
pub(all) suberror TextError {
  CompileError(@compiler.CompileError)
  LayoutError(@engine_api.LayoutError)
  UnsupportedFeature(String)
}

///|
/// Compile source to text using Dagre. Other engines can be supplied explicitly
/// through `compile_with_engine`, without adding them to this package's imports.
pub fn compile(
  source : String,
  mode~ : OutputMode = Ascii,
  direction~ : @engine_api.Direction = Down,
  parse_options~ : @compiler.ParseOptions = @compiler.ParseOptions::new(),
) -> String raise TextError {
  let compiled = compile_source(source, parse_options)
  match compiled.source_config() {
    Some({ layout_engine: Some(name), .. }) if name.to_lower() != "auto" &&
      name.to_lower() != "dagre" =>
      raise UnsupportedFeature(
        "text.compile uses dagre; use text.compile_with_engine for '\{name}'",
      )
    _ => ()
  }
  render_compiled(compiled, @engine_dagre.DagreEngine::new(), mode, direction)
}

///|
#deprecated
pub extend OutputMode with Debug::{to_repr}

///|
#deprecated
pub extend OutputMode with Eq::{equal, not_equal}

///|
#deprecated
pub extend TextError with Debug::{to_repr}

///|
/// Compile with a caller-selected engine. The explicit engine takes precedence
/// over `vars.d2-config.layout-engine` in the source.
pub fn[Engine : @engine_api.LayoutEngine] compile_with_engine(
  source : String,
  engine : Engine,
  mode~ : OutputMode = Ascii,
  direction~ : @engine_api.Direction = Down,
  parse_options~ : @compiler.ParseOptions = @compiler.ParseOptions::new(),
) -> String raise TextError {
  render_compiled(
    compile_source(source, parse_options),
    engine,
    mode,
    direction,
  )
}

///|
fn compile_source(
  source : String,
  options : @compiler.ParseOptions,
) -> @compiler.CompileResult raise TextError {
  match @compiler.compile_graph("diagram", source, options~) {
    Ok(compiled) => compiled
    Err(error) => raise CompileError(error)
  }
}

///|
fn[Engine : @engine_api.LayoutEngine] render_compiled(
  compiled : @compiler.CompileResult,
  engine : Engine,
  mode : OutputMode,
  direction : @engine_api.Direction,
) -> String raise TextError {
  let graph = compiled.graph_input()
  let source_config = compiled.source_config()
  if graph.uses_latex_labels() {
    raise UnsupportedFeature("LaTeX labels are not supported")
  }
  if graph.uses_sketch_styles() ||
    source_config
    .map(fn(config) { config.sketch.unwrap_or(false) })
    .unwrap_or(false) {
    raise UnsupportedFeature("sketch rendering is not supported")
  }
  let graph = match source_config {
    Some({ theme_id: Some(id), .. }) => {
      let theme = @themes.get_theme(id)
      let graph = if theme.rules.mono {
        graph.with_default_font("mono")
      } else {
        graph
      }
      if theme.rules.caps_lock {
        graph.with_caps_lock()
      } else {
        graph
      }
    }
    _ => graph
  }
  let laid_out = @engine_api.layout_with_engine(
    engine,
    graph,
    @engine_api.LayoutConfig::new(),
    direction,
  ) catch {
    error => raise LayoutError(error)
  }
  let diagram = @diagram.from_graph(laid_out, source_config)
  let config = match mode {
    Ascii => @renderer_ascii.AsciiConfig::new()
    Unicode => @renderer_ascii.AsciiConfig::unicode()
  }
  @renderer_ascii.render(diagram, config)
}
