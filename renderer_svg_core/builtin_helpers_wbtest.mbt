///|
fn render_with_builtin(
  diagram : @diagram.Diagram,
  config : SvgConfig,
) -> String raise @render_api.RenderError {
  render_svg(diagram, config, fonts=@builtin_fonts.resolve)
}
