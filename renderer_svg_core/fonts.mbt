///|
fn resolve_font_data_url(
  fonts : @fonts.Resolver,
  face : @fonts.Face,
  corpus : String,
) -> String raise @render_api.RenderError {
  match fonts(face) {
    Some(Ttf(data)) => d2_subset_font_data_url(data, corpus)
    Some(Url(url)) => {
      if url.is_empty() {
        raise @render_api.render_failed("empty URL for font '\{face.name()}'")
      }
      css_string_content(url)
    }
    None => raise @render_api.render_failed("missing font '\{face.name()}'")
  }
}

///|
fn css_string_content(value : String) -> String {
  let output = StringBuilder()
  for char in value {
    match char {
      '\\' => output.write_string("\\\\")
      '"' => output.write_string("\\\"")
      '\n' => output.write_string("\\a ")
      '\r' => output.write_string("\\d ")
      '\u000C' => output.write_string("\\c ")
      '\u0000' => output.write_char('\uFFFD')
      _ => output.write_char(char)
    }
  }
  output.to_string()
}

///|
/// Render without bundled font assets. The caller supplies sources for the
/// requested font roles, for example loaded TTF bytes or external font URLs.
pub fn render(
  diagram : @diagram.Diagram,
  config : SvgConfig,
  fonts~ : @fonts.Resolver,
) -> String raise @render_api.RenderError {
  render_svg(diagram, config, fonts~)
}
