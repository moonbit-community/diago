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
/// SVG-specific legend layout.
///
/// This package computes legend geometry so the SVG renderer only draws.

///|
using @graph {
  type ArrowheadType,
  type Box,
  type LegendInput,
  type ShapeType,
  type StyleInput,
}

///|
pub struct LegendLayoutConfig {
  font_size : Int
  margin : Double
} derive(Debug)

///|
pub fn LegendLayoutConfig::new(font_size : Int) -> LegendLayoutConfig {
  { font_size, margin: 20.0, }
}

///|
pub struct LegendLayout {
  x : Double
  y : Double
  width : Double
  height : Double
  fill : String
  stroke : String
  title : TitleLayout?
  entries : Array[LegendEntryLayout]
} derive(Debug)

///|
pub struct TitleLayout {
  x : Double
  y : Double
  text : String
} derive(Debug)

///|
/// Pre-positioned legend entry layout.
///
/// The renderer should not compute positions (label alignment, icon placement,
/// separators). It only renders based on this layout.
pub enum LegendEntryLayout {
  Shape(
    id~ : String,
    icon_box~ : Box,
    shape~ : ShapeType,
    label~ : String,
    style~ : StyleInput?,
    label_x~ : Double,
    label_y~ : Double
  )
  Connection(
    src_id~ : String,
    dst_id~ : String,
    index~ : Int,
    line_start_x~ : Double,
    line_end_x~ : Double,
    line_y~ : Double,
    src_arrow_enabled~ : Bool,
    dst_arrow_enabled~ : Bool,
    src_arrow~ : ArrowheadType,
    dst_arrow~ : ArrowheadType,
    label~ : String,
    style~ : StyleInput?,
    label_x~ : Double,
    label_y~ : Double
  )
  Custom(
    icon_x~ : Double,
    icon_y~ : Double,
    icon_size~ : Double,
    icon~ : String,
    label~ : String,
    label_x~ : Double,
    label_y~ : Double
  )
  Separator(x1~ : Double, x2~ : Double, y~ : Double)
} derive(Debug)

///|
fn legend_text_dimensions(text : String) -> @text_metrics.TextDimensions {
  @text_metrics.measure_text(text, 14, false, false, false).dimensions
}

///|
fn calculate_size(legend : LegendInput) -> (Double, Double, Int, Int) {
  if legend.is_empty() {
    return (0.0, 0.0, 0, 0)
  }
  let mut max_label_width = 0
  let mut total_height = 20 + 14 + 15
  let mut shape_count = 0
  let mut connection_count = 0
  for entry in legend.entries {
    match entry {
      ShapeEntry(label~, ..) => {
        if label == "" {
          continue
        }
        let dims = legend_text_dimensions(label)
        let label_width = dims.width.to_int()
        max_label_width = if label_width > max_label_width {
          label_width
        } else {
          max_label_width
        }
        total_height = total_height + max_int(dims.height.to_int(), 24) + 15
        shape_count += 1
      }
      ConnectionEntry(label~, ..) => {
        if label == "" {
          continue
        }
        let dims = legend_text_dimensions(label)
        let label_width = dims.width.to_int()
        max_label_width = if label_width > max_label_width {
          label_width
        } else {
          max_label_width
        }
        total_height = total_height + max_int(dims.height.to_int(), 24) + 15
        connection_count += 1
      }
      CustomEntry(label~, ..) => {
        if label == "" {
          continue
        }
        let dims = legend_text_dimensions(label)
        max_label_width = max_int(max_label_width, dims.width.to_int())
        total_height = total_height + max_int(dims.height.to_int(), 24) + 15
        shape_count += 1
      }
      Separator => ()
    }
  }
  let item_count = shape_count + connection_count
  if item_count > 0 {
    total_height -= 15 / 2
  }
  if connection_count > 0 {
    total_height += 30
  } else {
    total_height += 24
  }
  let width = 20 * 2 + 24 + 20 + max_label_width
  (width.to_double(), total_height.to_double(), shape_count, connection_count)
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Compute legend layout in SVG coordinates.
///
/// The bounds should be the diagram bounds in the same coordinate system.
pub fn compute_legend_layout(
  legend : LegendInput,
  bounds : (Double, Double, Double, Double),
  config : LegendLayoutConfig,
) -> LegendLayout? {
  if legend.is_empty() || legend.position == Hidden {
    return None
  }
  let (_, min_y, max_x, max_y) = bounds
  ignore(config)
  let (width, height, shape_count, connection_count) = calculate_size(legend)
  let x = max_x + 10.0
  let y = if max_y - height < min_y { min_y } else { max_y - height }
  let fill = "#ffffff"
  let stroke = "#DEE1EB"
  let title_text = legend.title.unwrap_or("Legend")
  let title = Some({ x: x + 20.0, y: y + 34.0, text: title_text, })
  let mut current_y = y + 54.0
  let entries : Array[LegendEntryLayout] = []
  let mut emitted_separator = false
  for entry in legend.entries {
    match entry {
      ShapeEntry(id~, shape~, label~, style~) => {
        if label == "" {
          continue
        }
        let dims = legend_text_dimensions(label)
        let row_height = max_int(dims.height.to_int(), 24)
        let icon_box = Box::new(x + 20.0, current_y, 24.0, 24.0)
        let label_x = x + 64.0
        let label_y = current_y +
          (row_height / 2 + (dims.height * 0.3).to_int()).to_double()
        entries.push(
          Shape(id~, icon_box~, shape~, label~, style~, label_x~, label_y~),
        )
        current_y = current_y + row_height.to_double() + 15.0
      }
      ConnectionEntry(
        src_id~,
        dst_id~,
        index~,
        src_arrow_enabled~,
        dst_arrow_enabled~,
        src_arrow~,
        dst_arrow~,
        label~,
        style~
      ) => {
        if label == "" {
          continue
        }
        if shape_count > 0 && connection_count > 0 && !emitted_separator {
          current_y += 7.0
          entries.push(Separator(x1=x + 20.0, x2=x + width - 20.0, y=current_y))
          current_y += 15.0
          emitted_separator = true
        }
        let dims = legend_text_dimensions(label)
        let row_height = max_int(dims.height.to_int(), 24)
        let line_y = current_y + 12.0
        let line_start_x = x + 20.0
        let line_end_x = line_start_x + 24.0
        let label_x = x + 64.0
        let label_y = current_y +
          (row_height / 2 + (dims.height * 0.2).to_int()).to_double()
        entries.push(
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
            label_y~,
          ),
        )
        current_y = current_y + row_height.to_double() + 15.0
      }
      CustomEntry(icon~, label~) => {
        let icon_x = x + 20.0
        let icon_y = current_y
        let icon_size = 24.0
        let label_x = x + 64.0
        let dims = legend_text_dimensions(label)
        let row_height = max_int(dims.height.to_int(), 24)
        let label_y = current_y +
          (row_height / 2 + (dims.height * 0.3).to_int()).to_double()
        entries.push(
          Custom(
            icon_x~,
            icon_y~,
            icon_size~,
            icon~,
            label~,
            label_x~,
            label_y~,
          ),
        )
        current_y = current_y + row_height.to_double() + 15.0
      }
      Separator => ()
    }
  }
  Some({ x, y, width, height, fill, stroke, title, entries, })
}
