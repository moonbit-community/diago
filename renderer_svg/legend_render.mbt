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
/// Legend rendering for SVG output.
///
/// Legend geometry (size/position/alignment) is computed in `layout_svg`.
/// This module only draws the pre-laid-out legend.

///|
using @layout_svg {type LegendLayout}

///|

///|
/// Render a pre-laid-out legend to SVG.
pub fn render_legend_svg(
  svg : @svg.Svg,
  layout : LegendLayout,
  diagram_hash : String,
  config : SvgConfig,
  theme : @themes.Theme,
) -> Unit raise @render_api.RenderError {
  svg.add(
    @xml_emit.Element::new("rect")
    .attr("x", d2_fixed6(layout.x))
    .attr("y", d2_fixed6(layout.y))
    .attr("width", d2_fixed6(layout.width))
    .attr("height", d2_fixed6(layout.height))
    .attr("rx", d2_fixed6(4.0))
    .attr("fill", "#F7F7FA")
    .attr("stroke", "#DEE1EB")
    .attr(
      "style", "stroke-width: 1px; filter: drop-shadow(0px 2px 3px rgba(0, 0, 0, 0.1))",
    )
    .build(),
  )
  svg.add(
    @xml_emit.Element::new("rect")
    .attr("x", d2_fixed6(layout.x))
    .attr("y", d2_fixed6(layout.y))
    .attr("width", d2_fixed6(layout.width))
    .attr("height", d2_fixed6(layout.height))
    .attr("rx", d2_fixed6(4.0))
    .attr("fill", "#ffffff")
    .attr("stroke", "#DEE1EB")
    .attr("style", "stroke-width: 1px")
    .build(),
  )
  match layout.title {
    Some(title) =>
      svg.add(
        @xml_emit.Element::new("text")
        .attr("class", "text-bold")
        .attr_int("x", title.x.to_int())
        .attr_int("y", title.y.to_int())
        .attr("style", "font-size: 16px;")
        .text(title.text)
        .build(),
      )
    None => ()
  }
  for entry in layout.entries {
    match entry {
      Shape(id~, icon_box~, shape~, label~, style~, label_x~, label_y~) =>
        render_shape_entry(
          svg, id, icon_box, shape, label, style, label_x, label_y, diagram_hash,
          config, theme,
        )
      Connection(
        src_id~,
        dst_id~,
        index~,
        line_start_x~,
        line_end_x~,
        line_y~,
        src_arrow_enabled~,
        dst_arrow_enabled~,
        src_arrow~,
        dst_arrow~,
        label~,
        style~,
        label_x~,
        label_y~
      ) =>
        render_connection_entry(
          svg, src_id, dst_id, index, line_start_x, line_end_x, line_y, src_arrow_enabled,
          dst_arrow_enabled, src_arrow, dst_arrow, label, style, label_x, label_y,
          config, theme,
        )
      Custom(icon_x~, icon_y~, icon_size~, icon~, label~, label_x~, label_y~) =>
        render_custom_entry(
          svg, icon_x, icon_y, icon_size, icon, label, label_x, label_y, config,
        )
      Separator(x1~, x2~, y~) =>
        svg.add(
          @xml_emit.Element::new("line")
          .attr("x1", d2_fixed6(x1))
          .attr("y1", d2_fixed6(y))
          .attr("x2", d2_fixed6(x2))
          .attr("y2", d2_fixed6(y))
          .attr("stroke", "#DEE1EB")
          .attr("stroke-dasharray", "2,2")
          .build(),
        )
    }
  }
}

///|
fn render_shape_entry(
  svg : @svg.Svg,
  id : String,
  icon_box : @graph.Box,
  shape : @graph.ShapeType,
  label : String,
  style : @graph.StyleInput?,
  label_x : Double,
  label_y : Double,
  diagram_hash : String,
  config : SvgConfig,
  theme : @themes.Theme,
) -> Unit raise @render_api.RenderError {
  let icon_style = style.unwrap_or(@graph.StyleInput::new())
  let icon_shape = Shape::legend_icon(id, shape, icon_style)
  svg.add(
    @xml_emit.Element::new("g")
    .attr(
      "transform",
      "translate(\{icon_box.x.to_int()}, \{icon_box.y.to_int()}) scale(0.200000)",
    )
    .open_tag(),
  )
  let appendix_items : Array[String] = []
  render_svg_object(
    svg,
    diagram_hash,
    appendix_items,
    icon_shape,
    [],
    None,
    config,
    theme,
    false,
    "",
    pass=Background,
  )
  render_svg_object(
    svg,
    diagram_hash,
    appendix_items,
    icon_shape,
    [],
    None,
    config,
    theme,
    false,
    "",
    pass=Foreground,
  )
  svg.add("</g>")
  svg.add(
    @xml_emit.Element::new("text")
    .attr("class", "text")
    .attr_int("x", label_x.to_int())
    .attr_int("y", label_y.to_int())
    .attr("style", "font-size: 14px;")
    .text(label)
    .build(),
  )
}

///|
fn render_connection_entry(
  svg : @svg.Svg,
  src_id : String,
  dst_id : String,
  index : Int,
  line_start_x : Double,
  _line_end_x : Double,
  line_y : Double,
  src_arrow_enabled : Bool,
  dst_arrow_enabled : Bool,
  src_arrow : @graph.ArrowheadType,
  dst_arrow : @graph.ArrowheadType,
  label : String,
  style : @graph.StyleInput?,
  label_x : Double,
  label_y : Double,
  config : SvgConfig,
  theme : @themes.Theme,
) -> Unit raise @render_api.RenderError {
  let edge_style = style.unwrap_or(@graph.StyleInput::new())
  let edge = Connection::legend_icon(
    src_id, dst_id, index, src_arrow_enabled, dst_arrow_enabled, src_arrow, dst_arrow,
    edge_style,
  )
  let connection_id = d2_connection_abs_id(edge, index)
  let icon_x = line_start_x.to_int()
  let icon_y = line_y.to_int()
  let legend_hash = "legend-\{d2_secret_hash("\{connection_id}-\{icon_x}-\{icon_y}")}"
  svg.add(
    @xml_emit.Element::new("g")
    .attr("transform", "translate(\{icon_x}, \{icon_y}) scale(0.500000)")
    .open_tag(),
  )
  let marker_ids : Map[String, String] = Map([])
  render_svg_edge(
    svg,
    edge,
    index,
    [],
    None,
    "url(#\{legend_hash})",
    marker_ids,
    legend_hash,
    config,
    theme,
    false,
  )
  svg.add("</g>")
  svg.add(
    @xml_emit.Element::new("text")
    .attr("class", "text")
    .attr_int("x", label_x.to_int())
    .attr_int("y", label_y.to_int())
    .attr("style", "font-size: 14px;")
    .text(label)
    .build(),
  )
}

///|
fn render_custom_entry(
  svg : @svg.Svg,
  icon_x : Double,
  icon_y : Double,
  icon_size : Double,
  icon : String,
  label : String,
  label_x : Double,
  label_y : Double,
  config : SvgConfig,
) -> Unit {
  if icon.has_prefix("http") || icon.contains(".") {
    svg.add(
      @xml_emit.Element::new("image")
      .attr("href", icon)
      .attr_num("x", icon_x)
      .attr_num("y", icon_y)
      .attr_num("width", icon_size)
      .attr_num("height", icon_size)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .self_close()
      .build(),
    )
  } else {
    let cx = icon_x + icon_size / 2.0
    // Note: text y-position is provided by layout via label_y, so reuse the same baseline offset style.
    let cy = icon_y + icon_size / 2.0 + config.font_size.to_double() * 0.35
    svg.add(
      @xml_emit.Element::new("text")
      .attr_num("x", cx)
      .attr_num("y", cy)
      .attr("font-family", "Arial, sans-serif")
      .attr_int("font-size", config.font_size + 4)
      .attr("fill", config.default_stroke)
      .attr("text-anchor", "middle")
      .text(icon)
      .build(),
    )
  }
  svg.add(
    @xml_emit.Element::new("text")
    .attr_num("x", label_x)
    .attr_num("y", label_y)
    .attr("font-family", "Arial, sans-serif")
    .attr_int("font-size", config.font_size)
    .attr("fill", config.default_stroke)
    .text(label)
    .build(),
  )
}
