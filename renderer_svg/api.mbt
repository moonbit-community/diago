///|
pub using @svg_core {
  type RenderPass,
  type SvgConfig,
  type SvgShapeContext,
  add_arrowhead_markers_to_svg,
  arrowhead_to_ascii,
  build_marker_attributes,
  get_arrowhead_marker_url,
  list_themes,
  needs_end_marker,
  needs_start_marker,
  render_connection_ascii,
  render_legend_svg,
  render_shape_svg,
}

///|
pub fn render_svg(
  diagram : @diagram.Diagram,
  config : SvgConfig,
) -> String raise @render_api.RenderError {
  @svg_core.render_svg(diagram, config, fonts=@builtin_fonts.resolve)
}
