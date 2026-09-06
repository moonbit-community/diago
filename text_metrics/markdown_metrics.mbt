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
/// Markdown measurement approximating the reference markdown sizing logic.
///
/// The upstream implementation renders Markdown into HTML and measures the
/// resulting block tree. Diago does not yet have the same HTML measurement
/// stack, so this package mirrors the reference block-level constants and composition
/// rules over the parsed CommonMark AST. This keeps layout and SVG
/// `foreignObject` sizing aligned with upstream fixtures such as
/// `constant_near_title`.

///|
const D2_MARKDOWN_LINE_HEIGHT : Double = 1.5

///|
const D2_MARKDOWN_LINE_HEIGHT_HEADING : Double = 1.25

///|
const D2_MARKDOWN_UL_OL_PADDING_LEFT_EM : Double = 2.0

///|
const D2_MARKDOWN_UL_MARGIN_BOTTOM : Double = 16.0

///|
const D2_MARKDOWN_LI_P_MARGIN_TOP : Double = 16.0

///|
const D2_MARKDOWN_LI_MARGIN_TOP_EM : Double = 0.25

///|
const D2_MARKDOWN_P_MARGIN_BOTTOM : Double = 16.0

///|
const D2_MARKDOWN_H_MARGIN_TOP : Double = 24.0

///|
const D2_MARKDOWN_H_MARGIN_BOTTOM : Double = 16.0

///|
const D2_MARKDOWN_H1_H2_PADDING_BOTTOM_EM : Double = 0.3

///|
const D2_MARKDOWN_H1_H2_BORDER_BOTTOM : Double = 1.0

///|
priv struct MarkdownBlockMetrics {
  width : Double
  height : Double
  margin_top : Double
  margin_bottom : Double
}

///|
fn markdown_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn markdown_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn markdown_block_metrics_empty() -> MarkdownBlockMetrics {
  { width: 0.0, height: 0.0, margin_top: 0.0, margin_bottom: 0.0, }
}

///|
fn markdown_header_font_size(base_font_size : Int, level : Int) -> Int {
  let base = base_font_size.to_double()
  let scaled = match level {
    1 => base * 2.0
    2 => base * 1.5
    3 => base * 1.25
    4 => base * 1.0
    5 => base * 0.875
    6 => base * 0.85
    _ => base
  }
  let out = scaled.to_int()
  if out > 0 {
    out
  } else {
    1
  }
}

///|
fn markdown_inline_dimensions(
  inline : @cmark.Inline,
  font_size : Int,
  line_height : Double,
  kind : FontKind,
) -> (Double, Double) {
  let lines = [0.0]
  markdown_add_inline_widths(inline, font_size, kind, lines)
  let mut max_width = 0.0
  for width in lines {
    if width > max_width {
      max_width = width
    }
  }
  let css_line_height = line_height * font_size.to_double()
  // D2 enables boundsWithDot while measuring Markdown. Source Sans then has
  // precise vertical bounds of 161/128 em. Normal lines are still governed by
  // their taller CSS line-height, while headings retain the fractional excess
  // (40px -> 40.25px and 30px -> 30.1875px).
  let precise_font_height = font_size.to_double() * 161.0 / 128.0
  let rendered_line_height = markdown_max_double(
    css_line_height, precise_font_height,
  )
  (max_width, rendered_line_height * lines.length().to_double())
}

///|
fn markdown_add_inline_widths(
  inline : @cmark.Inline,
  font_size : Int,
  kind : FontKind,
  lines : Array[Double],
) -> Unit {
  let add_width = fn(width : Double) {
    let last = lines.length() - 1
    lines[last] = lines[last] + width
  }
  match inline {
    Text(node) => {
      let measured = measure_text_with_dot_bounds_kind(node.v, font_size, kind)
      add_width(measured.max_line_width)
    }
    Autolink(node) => {
      let measured = measure_text_with_dot_bounds_kind(
        node.v.link.v,
        font_size,
        kind,
      )
      add_width(measured.max_line_width)
    }
    Break(node) =>
      match node.v.ty {
        Hard => lines.push(markdown_space_width(font_size, kind))
        Soft => add_width(markdown_space_width(font_size, kind))
      }
    CodeSpan(node) => {
      let measured = measure_text_with_dot_bounds_kind(
        node.v.code(),
        font_size,
        MonoRegular,
      )
      add_width(
        measured.max_line_width * 0.85 + 2.0 * 0.4 * font_size.to_double(),
      )
    }
    Emphasis(node) =>
      markdown_add_inline_widths(node.v.inline, font_size, SansItalic, lines)
    StrongEmphasis(node) =>
      markdown_add_inline_widths(node.v.inline, font_size, SansBold, lines)
    Inlines(node) =>
      for child in node.v.to_array() {
        markdown_add_inline_widths(child, font_size, kind, lines)
      }
    Link(node) =>
      markdown_add_inline_widths(node.v.text, font_size, kind, lines)
    ExtStrikethrough(node) =>
      markdown_add_inline_widths(node.v.0, font_size, kind, lines)
    ExtMathSpan(node) => {
      let measured = measure_text_with_dot_bounds_kind(
        node.v.tex(),
        font_size,
        kind,
      )
      add_width(measured.max_line_width)
    }
    Image(_) | RawHtml(_) => ()
  }
}

///|
fn markdown_space_width(font_size : Int, kind : FontKind) -> Double {
  let glyph = scaled_glyph_metrics(kind, ' '.to_int(), font_size)
  glyph.advance_fixed.to_double() / 64.0
}

///|
fn markdown_combine_blocks(
  blocks : Array[MarkdownBlockMetrics],
) -> MarkdownBlockMetrics {
  let nonempty : Array[MarkdownBlockMetrics] = []
  for block in blocks {
    if block.width != 0.0 ||
      block.height != 0.0 ||
      block.margin_top != 0.0 ||
      block.margin_bottom != 0.0 {
      nonempty.push(block)
    }
  }
  if nonempty.is_empty() {
    return markdown_block_metrics_empty()
  }
  let mut width = 0.0
  let mut height = 0.0
  let mut margin_top = 0.0
  let mut margin_bottom = 0.0
  let mut prev_margin_bottom = 0.0
  for i in 0..<nonempty.length() {
    let block = nonempty[i]
    if i == 0 {
      margin_top = markdown_max_double(margin_top, block.margin_top)
    } else {
      let margin_diff = block.margin_top - prev_margin_bottom
      if margin_diff > 0.0 {
        height = height + margin_diff
      }
    }
    if i == nonempty.length() - 1 {
      margin_bottom = markdown_max_double(margin_bottom, block.margin_bottom)
    } else {
      height = height + block.margin_bottom
      prev_margin_bottom = block.margin_bottom
    }
    height = height + block.height
    width = markdown_max_double(width, block.width)
  }
  { width, height, margin_top, margin_bottom, }
}

///|
fn markdown_measure_block(
  block : @cmark.Block,
  base_font_size : Int,
  list_depth : Int,
  in_list_item : Bool,
) -> MarkdownBlockMetrics {
  match block {
    BlankLine(_) | HtmlBlock(_) | LinkRefDefinition(_) =>
      markdown_block_metrics_empty()
    Blocks(node) => {
      let parts : Array[MarkdownBlockMetrics] = []
      for child in node.v.to_array() {
        parts.push(
          markdown_measure_block(
            child, base_font_size, list_depth, in_list_item,
          ),
        )
      }
      markdown_combine_blocks(parts)
    }
    Paragraph(node) => {
      let (width, height) = markdown_inline_dimensions(
        node.v.inline,
        base_font_size,
        D2_MARKDOWN_LINE_HEIGHT,
        SansRegular,
      )
      {
        width,
        height,
        margin_top: if in_list_item {
          D2_MARKDOWN_LI_P_MARGIN_TOP
        } else {
          0.0
        },
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    Heading(node) => {
      let heading_font_size = markdown_header_font_size(
        base_font_size,
        node.v.level,
      )
      let (width, inline_height) = markdown_inline_dimensions(
        node.v.inline,
        heading_font_size,
        D2_MARKDOWN_LINE_HEIGHT_HEADING,
        SansSemibold,
      )
      let mut height = inline_height
      if node.v.level == 1 || node.v.level == 2 {
        height = height +
          D2_MARKDOWN_H1_H2_PADDING_BOTTOM_EM * heading_font_size.to_double() +
          D2_MARKDOWN_H1_H2_BORDER_BOTTOM
      }
      {
        width,
        height,
        margin_top: D2_MARKDOWN_H_MARGIN_TOP,
        margin_bottom: D2_MARKDOWN_H_MARGIN_BOTTOM,
      }
    }
    List(node) => {
      let item_blocks : Array[MarkdownBlockMetrics] = []
      for i in 0..<node.v.items.length() {
        let item = node.v.items[i].v
        let inner = markdown_measure_block(
          item.block,
          base_font_size,
          list_depth + 1,
          true,
        )
        item_blocks.push({
          width: inner.width +
          D2_MARKDOWN_UL_OL_PADDING_LEFT_EM * base_font_size.to_double(),
          height: inner.height,
          margin_top: if i == 0 {
            0.0
          } else {
            D2_MARKDOWN_LI_MARGIN_TOP_EM * base_font_size.to_double()
          },
          margin_bottom: 0.0,
        })
      }
      let merged = markdown_combine_blocks(item_blocks)
      if list_depth == 0 {
        return {
          ..merged,
          margin_bottom: markdown_max_double(
            merged.margin_bottom,
            D2_MARKDOWN_UL_MARGIN_BOTTOM,
          ),
        }
      }
      merged
    }
    CodeBlock(node) | ExtMathBlock(node) => {
      let mut line_count = 0
      let mut max_line_width = 0.0
      let code_font_size = markdown_max_int(
        1,
        (base_font_size.to_double() * 0.85).to_int(),
      )
      for line in node.v.code.to_array() {
        let measured = measure_text_with_dot_bounds(
          line.v,
          code_font_size,
          true,
          false,
          false,
        )
        if measured.max_line_width > max_line_width {
          max_line_width = measured.max_line_width
        }
        line_count = line_count + 1
      }
      if line_count == 0 {
        line_count = 1
      }
      {
        width: max_line_width + 32.0,
        height: line_count.to_double() *
        base_font_size.to_double() *
        0.85 *
        1.45 +
        32.0,
        margin_top: 0.0,
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    ThematicBreak(_) =>
      {
        width: 0.0,
        height: 0.25 * base_font_size.to_double(),
        margin_top: D2_MARKDOWN_H_MARGIN_TOP,
        margin_bottom: D2_MARKDOWN_H_MARGIN_TOP,
      }
    BlockQuote(node) => {
      let inner = markdown_measure_block(
        node.v.block,
        base_font_size,
        list_depth,
        false,
      )
      {
        width: inner.width + 2.25 * base_font_size.to_double(),
        height: inner.height,
        margin_top: 0.0,
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    ExtTable(node) => {
      let column_widths : Array[Double] = []
      let mut row_count = 0
      for row in node.v.rows.to_array() {
        match row.0.v {
          Header(cols) | Data(cols) => {
            row_count += 1
            for i, col in cols.to_array() {
              let (cell_width, _) = markdown_inline_dimensions(
                col.0,
                base_font_size,
                D2_MARKDOWN_LINE_HEIGHT,
                SansRegular,
              )
              while column_widths.length() <= i {
                column_widths.push(0.0)
              }
              if cell_width > column_widths[i] {
                column_widths[i] = cell_width
              }
            }
          }
          Sep(_) => ()
        }
      }
      let mut table_width = 6.0
      for column_width in column_widths {
        table_width = table_width + column_width + 27.0
      }
      let row_height = D2_MARKDOWN_LINE_HEIGHT * base_font_size.to_double() +
        13.0
      {
        width: table_width,
        height: row_height * row_count.to_double() + 2.0,
        margin_top: 0.0,
        margin_bottom: D2_MARKDOWN_P_MARGIN_BOTTOM,
      }
    }
    ExtFootnoteDefinition(node) =>
      markdown_measure_block(node.v.block, base_font_size, list_depth, false)
  }
}

///|
/// Measure a markdown label using compatibility block layout constants.
pub fn markdown_source_like_d2(text : String) -> String {
  let out = StringBuilder()
  let mut preceding_backslashes = 0
  for i = 0; i < text.length(); i = i + 1 {
    match text[i].to_char() {
      Some('\\') => {
        out.write_char('\\')
        preceding_backslashes += 1
      }
      Some('$') => {
        if preceding_backslashes % 2 == 0 {
          out.write_string("&#36;")
        } else {
          out.write_char('$')
        }
        preceding_backslashes = 0
      }
      Some(ch) => {
        out.write_char(ch)
        preceding_backslashes = 0
      }
      None => preceding_backslashes = 0
    }
  }
  out.to_string()
}

///|
/// Measure a markdown label using compatibility block layout constants.
pub fn measure_label_markdown(text : String, font_size : Int) -> TextDimensions {
  if text == "" {
    return { width: 1.0, height: 1.0, }
  }
  let doc = @cmark.Doc::from_string(strict=false, markdown_source_like_d2(text))
  let metrics = markdown_measure_block(doc.block, font_size, 0, false)
  { width: @math.ceil(metrics.width), height: @math.ceil(metrics.height), }
}
