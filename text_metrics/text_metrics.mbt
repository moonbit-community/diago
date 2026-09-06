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
/// Text measurement module
///
/// This module implements text dimension calculation following the reference approach:
/// - Uses the reference constant CODE_LINE_HEIGHT = 1.3
/// - Handles empty lines (leading/trailing) the same way
/// - Uses pre-generated glyph bounds and advances from the embedded fonts

///|
/// Text dimensions (width and height)
pub struct TextDimensions {
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// Text measurement result with line information
pub struct MeasuredText {
  dimensions : TextDimensions
  line_count : Int
  max_line_width : Double
} derive(Eq, Debug)

///|
pub impl Show for TextDimensions with fn output(self, logger) {
  logger.write_string("{width: ")
  logger.write_object(self.width)
  logger.write_string(", height: ")
  logger.write_object(self.height)
  logger.write_char('}')
}

///|
pub impl Show for MeasuredText with fn output(self, logger) {
  logger.write_string("{dimensions: ")
  logger.write_object(self.dimensions)
  logger.write_string(", line_count: ")
  logger.write_object(self.line_count)
  logger.write_string(", max_line_width: ")
  logger.write_object(self.max_line_width)
  logger.write_char('}')
}

///|
/// Reference CODE_LINE_HEIGHT constant.
const CODE_LINE_HEIGHT : Double = 1.3

///|
/// Reference TAB_SIZE constant.
const TAB_SIZE : Double = 4.0

///|
/// Approximation for the reference line height scaling.
///
/// The reference ruler computes line heights from font metrics at each size
/// (with hinting), which is not perfectly linear. For the embedded Source Sans
/// Pro / Source Code Pro fonts, the measured line height for a single line is
/// well-approximated by `ceil(font_size * 101 / 80)`.
///
/// This constant is chosen to match the reference's `ruler.Measure` heights across common
/// sizes (e.g. 16 -> 21, 24 -> 31).
const LINE_HEIGHT_FACTOR : Double = 101.0 / 80.0

///|
priv enum FontKind {
  SansRegular
  SansBold
  SansSemibold
  SansItalic
  MonoRegular
  MonoBold
  MonoItalic
  HandRegular
  HandBold
}

///|
fn select_font_kind(
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> FontKind {
  if is_mono {
    if is_bold {
      MonoBold
    } else if is_italic {
      MonoItalic
    } else {
      MonoRegular
    }
  } else if is_bold {
    SansBold
  } else if is_italic {
    SansItalic
  } else {
    SansRegular
  }
}

///|
priv struct GlyphMetrics {
  x_min : Int
  x_max : Int
  advance_fixed : Int
}

///|
fn packed_i16_at(data : Bytes, index : Int) -> Int {
  let offset = index * 2
  let bits = data[offset].to_int() | (data[offset + 1].to_int() << 8)
  if bits >= 0x8000 {
    bits - 0x10000
  } else {
    bits
  }
}

///|
fn font_units_per_em(kind : FontKind) -> Int {
  match kind {
    SansRegular => FONT_UNITS_PER_EM_SANS_REGULAR
    SansBold => FONT_UNITS_PER_EM_SANS_BOLD
    SansSemibold => FONT_UNITS_PER_EM_SANS_SEMIBOLD
    SansItalic => FONT_UNITS_PER_EM_SANS_ITALIC
    MonoRegular => FONT_UNITS_PER_EM_MONO_REGULAR
    MonoBold => FONT_UNITS_PER_EM_MONO_BOLD
    MonoItalic => FONT_UNITS_PER_EM_MONO_ITALIC
    HandRegular => FONT_UNITS_PER_EM_HAND_REGULAR
    HandBold => FONT_UNITS_PER_EM_HAND_BOLD
  }
}

///|
fn scale_font_unit(value : Int, font_size : Int, units_per_em : Int) -> Int {
  let scaled = value * font_size * 64
  if scaled >= 0 {
    (scaled + units_per_em / 2) / units_per_em
  } else {
    (scaled - units_per_em / 2) / units_per_em
  }
}

///|
fn floor_fixed(value : Int) -> Int {
  if value >= 0 {
    value / 64
  } else {
    -((-value + 63) / 64)
  }
}

///|
fn ceil_fixed(value : Int) -> Int {
  if value >= 0 {
    (value + 63) / 64
  } else {
    -(-value / 64)
  }
}

///|
fn lookup_kerning_fixed(
  _kind : FontKind,
  _left_codepoint : Int,
  _right_codepoint : Int,
  _font_size : Int,
) -> Int {
  0
}

///|
fn packed_glyph_metrics(
  x_mins : Bytes,
  x_maxs : Bytes,
  advances : Bytes,
  index : Int,
) -> GlyphMetrics {
  {
    x_min: packed_i16_at(x_mins, index),
    x_max: packed_i16_at(x_maxs, index),
    advance_fixed: packed_i16_at(advances, index),
  }
}

///|
fn packed_replacement_metrics(data : Bytes, index : Int) -> GlyphMetrics {
  let offset = index * 3
  {
    x_min: packed_i16_at(data, offset),
    x_max: packed_i16_at(data, offset + 1),
    advance_fixed: packed_i16_at(data, offset + 2),
  }
}

///|
fn lookup_base_glyph_metrics(kind : FontKind, codepoint : Int) -> GlyphMetrics {
  if codepoint >= 0 && codepoint < 256 {
    match kind {
      SansRegular =>
        packed_glyph_metrics(
          glyph_x_mins_sans_regular, glyph_x_maxs_sans_regular, glyph_advances_fixed_sans_regular,
          codepoint,
        )
      SansBold =>
        packed_glyph_metrics(
          glyph_x_mins_sans_bold, glyph_x_maxs_sans_bold, glyph_advances_fixed_sans_bold,
          codepoint,
        )
      SansSemibold =>
        packed_glyph_metrics(
          glyph_x_mins_sans_semibold, glyph_x_maxs_sans_semibold, glyph_advances_fixed_sans_semibold,
          codepoint,
        )
      SansItalic =>
        packed_glyph_metrics(
          glyph_x_mins_sans_italic, glyph_x_maxs_sans_italic, glyph_advances_fixed_sans_italic,
          codepoint,
        )
      MonoRegular =>
        packed_glyph_metrics(
          glyph_x_mins_mono_regular, glyph_x_maxs_mono_regular, glyph_advances_fixed_mono_regular,
          codepoint,
        )
      MonoBold =>
        packed_glyph_metrics(
          glyph_x_mins_mono_bold, glyph_x_maxs_mono_bold, glyph_advances_fixed_mono_bold,
          codepoint,
        )
      MonoItalic =>
        packed_glyph_metrics(
          glyph_x_mins_mono_italic, glyph_x_maxs_mono_italic, glyph_advances_fixed_mono_italic,
          codepoint,
        )
      HandRegular =>
        packed_glyph_metrics(
          glyph_x_mins_hand_regular, glyph_x_maxs_hand_regular, glyph_advances_fixed_hand_regular,
          codepoint,
        )
      HandBold =>
        packed_glyph_metrics(
          glyph_x_mins_hand_bold, glyph_x_maxs_hand_bold, glyph_advances_fixed_hand_bold,
          codepoint,
        )
    }
  } else if codepoint >= GEO_START && codepoint <= GEO_END {
    let idx = codepoint - GEO_START
    match kind {
      SansRegular =>
        packed_glyph_metrics(
          glyph_x_mins_sans_regular_geo, glyph_x_maxs_sans_regular_geo, glyph_advances_fixed_sans_regular_geo,
          idx,
        )
      SansBold =>
        packed_glyph_metrics(
          glyph_x_mins_sans_bold_geo, glyph_x_maxs_sans_bold_geo, glyph_advances_fixed_sans_bold_geo,
          idx,
        )
      SansSemibold =>
        packed_glyph_metrics(
          glyph_x_mins_sans_semibold_geo, glyph_x_maxs_sans_semibold_geo, glyph_advances_fixed_sans_semibold_geo,
          idx,
        )
      SansItalic =>
        packed_glyph_metrics(
          glyph_x_mins_sans_italic_geo, glyph_x_maxs_sans_italic_geo, glyph_advances_fixed_sans_italic_geo,
          idx,
        )
      MonoRegular =>
        packed_glyph_metrics(
          glyph_x_mins_mono_regular_geo, glyph_x_maxs_mono_regular_geo, glyph_advances_fixed_mono_regular_geo,
          idx,
        )
      MonoBold =>
        packed_glyph_metrics(
          glyph_x_mins_mono_bold_geo, glyph_x_maxs_mono_bold_geo, glyph_advances_fixed_mono_bold_geo,
          idx,
        )
      MonoItalic =>
        packed_glyph_metrics(
          glyph_x_mins_mono_italic_geo, glyph_x_maxs_mono_italic_geo, glyph_advances_fixed_mono_italic_geo,
          idx,
        )
      HandRegular =>
        packed_glyph_metrics(
          glyph_x_mins_hand_regular_geo, glyph_x_maxs_hand_regular_geo, glyph_advances_fixed_hand_regular_geo,
          idx,
        )
      HandBold =>
        packed_glyph_metrics(
          glyph_x_mins_hand_bold_geo, glyph_x_maxs_hand_bold_geo, glyph_advances_fixed_hand_bold_geo,
          idx,
        )
    }
  } else {
    let replacement = match kind {
      SansRegular => glyph_replacement_sans_regular
      SansBold => glyph_replacement_sans_bold
      SansSemibold => glyph_replacement_sans_semibold
      SansItalic => glyph_replacement_sans_italic
      MonoRegular => glyph_replacement_mono_regular
      MonoBold => glyph_replacement_mono_bold
      MonoItalic => glyph_replacement_mono_italic
      HandRegular => glyph_replacement_hand_regular
      HandBold => glyph_replacement_hand_bold
    }
    packed_replacement_metrics(replacement, 0)
  }
}

///|
fn scaled_glyph_metrics(
  kind : FontKind,
  codepoint : Int,
  font_size : Int,
) -> GlyphMetrics {
  if codepoint >= 0 && codepoint < 256 {
    match size_specific_font_index(font_size) {
      Some(size_index) => {
        let index = size_index * 256 + codepoint
        return match kind {
          SansRegular =>
            packed_glyph_metrics(
              glyph_x_mins_sans_regular_by_size, glyph_x_maxs_sans_regular_by_size,
              glyph_advances_fixed_sans_regular_by_size, index,
            )
          SansBold =>
            packed_glyph_metrics(
              glyph_x_mins_sans_bold_by_size, glyph_x_maxs_sans_bold_by_size, glyph_advances_fixed_sans_bold_by_size,
              index,
            )
          SansSemibold =>
            packed_glyph_metrics(
              glyph_x_mins_sans_semibold_by_size, glyph_x_maxs_sans_semibold_by_size,
              glyph_advances_fixed_sans_semibold_by_size, index,
            )
          SansItalic =>
            packed_glyph_metrics(
              glyph_x_mins_sans_italic_by_size, glyph_x_maxs_sans_italic_by_size,
              glyph_advances_fixed_sans_italic_by_size, index,
            )
          MonoRegular =>
            packed_glyph_metrics(
              glyph_x_mins_mono_regular_by_size, glyph_x_maxs_mono_regular_by_size,
              glyph_advances_fixed_mono_regular_by_size, index,
            )
          MonoBold =>
            packed_glyph_metrics(
              glyph_x_mins_mono_bold_by_size, glyph_x_maxs_mono_bold_by_size, glyph_advances_fixed_mono_bold_by_size,
              index,
            )
          MonoItalic =>
            packed_glyph_metrics(
              glyph_x_mins_mono_italic_by_size, glyph_x_maxs_mono_italic_by_size,
              glyph_advances_fixed_mono_italic_by_size, index,
            )
          HandRegular =>
            packed_glyph_metrics(
              glyph_x_mins_hand_regular_by_size, glyph_x_maxs_hand_regular_by_size,
              glyph_advances_fixed_hand_regular_by_size, index,
            )
          HandBold =>
            packed_glyph_metrics(
              glyph_x_mins_hand_bold_by_size, glyph_x_maxs_hand_bold_by_size, glyph_advances_fixed_hand_bold_by_size,
              index,
            )
        }
      }
      None => ()
    }
  }
  if (codepoint < 0 || codepoint >= 256) &&
    (codepoint < GEO_START || codepoint > GEO_END) {
    match size_specific_font_index(font_size) {
      Some(index) => {
        let replacement = match kind {
          SansRegular => glyph_replacement_sans_regular_by_size
          SansBold => glyph_replacement_sans_bold_by_size
          SansSemibold => glyph_replacement_sans_semibold_by_size
          SansItalic => glyph_replacement_sans_italic_by_size
          MonoRegular => glyph_replacement_mono_regular_by_size
          MonoBold => glyph_replacement_mono_bold_by_size
          MonoItalic => glyph_replacement_mono_italic_by_size
          HandRegular => glyph_replacement_hand_regular_by_size
          HandBold => glyph_replacement_hand_bold_by_size
        }
        return packed_replacement_metrics(replacement, index)
      }
      None => ()
    }
  }
  let raw = lookup_base_glyph_metrics(kind, codepoint)
  let units_per_em = font_units_per_em(kind)
  {
    x_min: floor_fixed(scale_font_unit(raw.x_min, font_size, units_per_em)),
    x_max: ceil_fixed(scale_font_unit(raw.x_max, font_size, units_per_em)),
    advance_fixed: scale_font_unit(raw.advance_fixed, font_size, units_per_em),
  }
}

///|
fn size_specific_font_index(font_size : Int) -> Int? {
  for index, size in size_specific_font_sizes {
    if size == font_size {
      return Some(index)
    }
  }
  None
}

///|
fn line_height_for(font_size : Int, is_mono : Bool) -> Double {
  let mut height = font_size.to_double() * LINE_HEIGHT_FACTOR
  if is_mono {
    height = height * CODE_LINE_HEIGHT
  }
  height
}

///|
let hand_line_heights_by_size : Array[Int] = [
  2, 3, 11, 13, 16, 17, 18, 21, 23, 25, 27, 31, 36, 37, 38, 41, 44, 46, 50, 54, 61,
  69, 94, 107, 113, 125,
]

///|
fn hand_line_height_for(font_size : Int) -> Double {
  match size_specific_font_index(font_size) {
    Some(index) => hand_line_heights_by_size[index].to_double()
    None => @math.ceil(font_size.to_double() * 1.25)
  }
}

///|
fn regular_text_height_like_reference(
  text : String,
  font_size : Int,
  kind : FontKind,
) -> Double {
  let lines = text.split("\n")
  let mut first_content_line = -1
  let mut last_content_line = -1
  for i, line in lines {
    if line.to_owned().trim() == "" {
      continue
    }
    if first_content_line < 0 {
      first_content_line = i
    }
    last_content_line = i
  }
  if first_content_line < 0 || last_content_line < 0 {
    return 0.0
  }
  let first_line_height = match kind {
    HandRegular | HandBold => hand_line_height_for(font_size)
    _ => line_height_for(font_size, false)
  }
  first_line_height +
  (last_content_line - first_content_line).to_double() * font_size.to_double()
}

///|
fn decode_utf8_codepoints(text : String) -> Array[Int] {
  let bytes = @utf8.encode(text[:]).to_array()
  let codepoints : Array[Int] = []
  let mut i = 0
  while i < bytes.length() {
    let b0 = bytes[i].to_int()
    if b0 < 0x80 {
      codepoints.push(b0)
      i = i + 1
    } else if (b0 & 0xe0) == 0xc0 && i + 1 < bytes.length() {
      let b1 = bytes[i + 1].to_int()
      codepoints.push(((b0 & 0x1f) << 6) | (b1 & 0x3f))
      i = i + 2
    } else if (b0 & 0xf0) == 0xe0 && i + 2 < bytes.length() {
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      codepoints.push(((b0 & 0x0f) << 12) | ((b1 & 0x3f) << 6) | (b2 & 0x3f))
      i = i + 3
    } else if (b0 & 0xf8) == 0xf0 && i + 3 < bytes.length() {
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      let b3 = bytes[i + 3].to_int()
      codepoints.push(
        ((b0 & 0x07) << 18) |
        ((b1 & 0x3f) << 12) |
        ((b2 & 0x3f) << 6) |
        (b3 & 0x3f),
      )
      i = i + 4
    } else {
      codepoints.push(0xfffd)
      i = i + 1
    }
  }
  codepoints
}

///|
fn is_d2_wide_codepoint(codepoint : Int) -> Bool {
  (codepoint >= 0x1100 && codepoint <= 0x115f) ||
  codepoint == 0x2329 ||
  codepoint == 0x232a ||
  (codepoint >= 0x2e80 && codepoint <= 0xa4cf && codepoint != 0x303f) ||
  (codepoint >= 0xac00 && codepoint <= 0xd7a3) ||
  (codepoint >= 0xf900 && codepoint <= 0xfaff) ||
  (codepoint >= 0xfe10 && codepoint <= 0xfe19) ||
  (codepoint >= 0xfe30 && codepoint <= 0xfe6f) ||
  (codepoint >= 0xff00 && codepoint <= 0xff60) ||
  (codepoint >= 0xffe0 && codepoint <= 0xffe6) ||
  (codepoint >= 0x20000 && codepoint <= 0x3fffd)
}

///|
fn is_d2_emoji_codepoint(codepoint : Int) -> Bool {
  (codepoint >= 0x1f000 && codepoint <= 0x1faff) ||
  (codepoint >= 0x2600 && codepoint <= 0x27bf)
}

///|
fn d2_replacement_cluster_width(
  kind : FontKind,
  font_size : Int,
  rune_count : Int,
) -> Double {
  if rune_count <= 0 {
    return 0.0
  }
  let glyph = scaled_glyph_metrics(kind, 0xfffd, font_size)
  let advance = glyph.advance_fixed.to_double() / 64.0
  let kern = lookup_kerning_fixed(kind, 0xfffd, 0xfffd, font_size).to_double() /
    64.0
  let left = if glyph.x_min < 0 { glyph.x_min.to_double() } else { 0.0 }
  let right = if glyph.x_max > 0 {
    glyph.x_max.to_double() + (rune_count - 1).to_double() * (advance + kern)
  } else {
    0.0
  }
  right - left
}

///|
fn d2_unicode_line_delta(
  line : String,
  font_size : Int,
  kind : FontKind,
) -> Double {
  let mono_kind = match kind {
    SansBold | SansSemibold | MonoBold | HandBold => MonoBold
    SansItalic | MonoItalic => MonoItalic
    _ => MonoRegular
  }
  let mono_space = scaled_glyph_metrics(mono_kind, ' '.to_int(), font_size).advance_fixed.to_double() /
    64.0
  let mut delta = 0.0
  let mut emoji_runes = 0
  let mut emoji_join_pending = false

  fn flush_emoji(
    count : Int,
    width : Double,
    kind : FontKind,
    font_size : Int,
  ) -> Double {
    if count > 0 {
      width * 2.0 - d2_replacement_cluster_width(kind, font_size, count)
    } else {
      0.0
    }
  }

  for cp in decode_utf8_codepoints(line) {
    if is_d2_emoji_codepoint(cp) {
      if emoji_runes == 0 || emoji_join_pending {
        emoji_runes = emoji_runes + 1
      } else {
        delta = delta + flush_emoji(emoji_runes, mono_space, kind, font_size)
        emoji_runes = 1
      }
      emoji_join_pending = false
    } else if emoji_runes > 0 &&
      (cp == 0x200d || cp == 0xfe0f || (cp >= 0x1f3fb && cp <= 0x1f3ff)) {
      emoji_runes = emoji_runes + 1
      emoji_join_pending = cp == 0x200d
    } else {
      delta = delta + flush_emoji(emoji_runes, mono_space, kind, font_size)
      emoji_runes = 0
      emoji_join_pending = false
      if is_d2_wide_codepoint(cp) {
        delta = delta +
          mono_space * 2.0 -
          d2_replacement_cluster_width(kind, font_size, 1)
      }
    }
  }
  delta + flush_emoji(emoji_runes, mono_space, kind, font_size)
}

///|
fn d2_scale_unicode_width(
  text : String,
  font_size : Int,
  kind : FontKind,
  base_width : Double,
  raw_line_widths : Array[Double],
) -> Double {
  let mut width = base_width
  for index, line in text.split("\n") {
    let raw = if index < raw_line_widths.length() {
      raw_line_widths[index]
    } else {
      0.0
    }
    let scaled = raw + d2_unicode_line_delta(line.to_owned(), font_size, kind)
    if scaled > width {
      width = scaled
    }
  }
  width
}

///|
fn measure_text_with_mode(
  text : String,
  font_size : Int,
  kind : FontKind,
  bounds_with_dot : Bool,
  use_code_line_height : Bool,
) -> MeasuredText {
  let space = scaled_glyph_metrics(kind, ' '.to_int(), font_size)
  let tab_width = space.advance_fixed.to_double() / 64.0 * TAB_SIZE
  let mut line_count = 0
  let mut has_area = false
  let mut bounds_left = 0.0
  let mut bounds_right = 0.0
  let mut dot_x = 0.0
  let mut prev_cp = -1
  let raw_line_widths : Array[Double] = []
  let mut line_has_area = false
  let mut line_bounds_left = 0.0
  let mut line_bounds_right = 0.0

  // Analyze each character following the ruler.drawBuf approach.
  for cp in decode_utf8_codepoints(text) {
    match cp {
      0x0a => {
        raw_line_widths.push(line_bounds_right - line_bounds_left)
        line_has_area = false
        line_bounds_left = 0.0
        line_bounds_right = 0.0
        dot_x = 0.0
        line_count = line_count + 1
      }
      0x0d =>
        // Carriage return moves to line origin without advancing lines.
        dot_x = 0.0
      0x09 => {
        // Mirror the reference tab behavior.
        // NOTE: This does not reset `prevR`; keep kerning behavior aligned.
        let mut rem = dot_x % tab_width
        rem = rem % (rem + tab_width)
        if rem == 0.0 {
          rem = tab_width
        }
        dot_x = dot_x + rem
      }
      _ => {
        if prev_cp >= 0 {
          let k_fixed = lookup_kerning_fixed(kind, prev_cp, cp, font_size)
          dot_x = dot_x + k_fixed.to_double() / 64.0
        }
        let m = scaled_glyph_metrics(kind, cp, font_size)
        let left = dot_x + m.x_min.to_double()
        let right = dot_x + m.x_max.to_double()
        let is_area = left != right

        if bounds_with_dot {
          if left < bounds_left {
            bounds_left = left
          }
          if right > bounds_right {
            bounds_right = right
          }
        } else if !has_area {
          bounds_left = left
          bounds_right = right
          if is_area {
            has_area = true
          }
        } else {
          if left < bounds_left {
            bounds_left = left
          }
          if right > bounds_right {
            bounds_right = right
          }
        }

        if bounds_with_dot {
          if left < line_bounds_left {
            line_bounds_left = left
          }
          if right > line_bounds_right {
            line_bounds_right = right
          }
        } else if !line_has_area {
          line_bounds_left = left
          line_bounds_right = right
          if is_area {
            line_has_area = true
          }
        } else {
          if left < line_bounds_left {
            line_bounds_left = left
          }
          if right > line_bounds_right {
            line_bounds_right = right
          }
        }

        dot_x = dot_x + m.advance_fixed.to_double() / 64.0
        prev_cp = cp

        if bounds_with_dot {
          if dot_x < bounds_left {
            bounds_left = dot_x
          }
          if dot_x > bounds_right {
            bounds_right = dot_x
          }
          if dot_x < line_bounds_left {
            line_bounds_left = dot_x
          }
          if dot_x > line_bounds_right {
            line_bounds_right = dot_x
          }
        }
      }
    }
  }

  raw_line_widths.push(line_bounds_right - line_bounds_left)

  let max_line_width = d2_scale_unicode_width(
    text,
    font_size,
    kind,
    bounds_right - bounds_left,
    raw_line_widths,
  )

  // Handle empty lines using the reference logic.
  let lines_iter = text.split("\n")
  let lines : Array[String] = []

  // Convert iter to array for indexing
  for line in lines_iter {
    lines.push(line.to_owned())
  }

  let total_height = if use_code_line_height {
    // The first line occupies the precise Source Code Pro glyph bounds; only
    // subsequent baselines are separated by CODE_LINE_HEIGHT. Treating every
    // line as a full 1.3em makes two-line code blocks one pixel too tall.
    let base_height = font_size.to_double()
    let precise_first_line_height = base_height * 161.0 / 128.0
    let mut total_height = precise_first_line_height +
      line_count.to_double() * base_height * CODE_LINE_HEIGHT
    // Add one font-size line when there is a leading blank line.
    let has_leading = if lines.length() > 0 {
      lines[0].trim() == ""
    } else {
      false
    }
    let mut num_trailing = 0
    if lines.length() > 0 {
      let mut j = lines.length() - 1
      while j >= 0 {
        if lines[j].trim() == "" {
          num_trailing = num_trailing + 1
        } else {
          break
        }
        j = j - 1
      }
    }
    // reference behavior for language-tagged code snippets.
    if has_leading && num_trailing < lines.length() {
      total_height = total_height + base_height
    }

    // Add trailing blank lines using CODE_LINE_HEIGHT.
    let trailing_height = CODE_LINE_HEIGHT *
      base_height *
      num_trailing.to_double()
    total_height = total_height + trailing_height
    total_height
  } else {
    regular_text_height_like_reference(text, font_size, kind)
  }

  // Text measurement returns raw text dimensions.
  // Shape padding / size-to-fit is applied later by the shape sizing layer.
  // The measured bounds are rounded up with `math.Ceil`.
  let width = @math.ceil(max_line_width)
  let height = @math.ceil(total_height)
  { dimensions: { width, height, }, line_count, max_line_width, }
}

///|
/// Calculate text dimensions following the reference approach (from d2graph.GetTextDimensionsWithMono)
///
/// Key aspects from the reference implementation:
/// 1. For code/mono text: use CODE_LINE_HEIGHT (1.3)
/// 2. For regular text: use DEFAULT_LINE_HEIGHT_FACTOR (1.0)
/// 3. Handle empty lines (leading/trailing) by adding font_size for each
/// 4. Consider font style: bold adds ~10% width, italic adds ~5%
pub fn measure_text(
  text : String,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> MeasuredText {
  let kind = select_font_kind(is_mono, is_bold, is_italic)
  measure_text_with_mode(text, font_size, kind, false, false)
}

///|
/// Measure text with D2's hand-drawn font used by sketch diagrams.
pub fn measure_text_hand_drawn(
  text : String,
  font_size : Int,
  is_bold : Bool,
) -> MeasuredText {
  let kind = if is_bold { HandBold } else { HandRegular }
  measure_text_with_mode(text, font_size, kind, false, false)
}

///|
/// Measure text using precise bounds that include the pen position ("dot").
///
/// The Markdown measuring path sets `ruler.boundsWithDot = true`. In the
/// MoonBit metrics pipeline we apply the equivalent trailing-dot correction per
/// line without changing the base line-height behavior.
pub fn measure_text_with_dot_bounds(
  text : String,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> MeasuredText {
  let kind = select_font_kind(is_mono, is_bold, is_italic)
  measure_text_with_dot_bounds_kind(text, font_size, kind)
}

///|
fn measure_text_with_dot_bounds_kind(
  text : String,
  font_size : Int,
  kind : FontKind,
) -> MeasuredText {
  measure_text_with_mode(text, font_size, kind, true, false)
}

///|
/// Measure code text using monospace font and CODE_LINE_HEIGHT semantics.
pub fn measure_text_code(
  text : String,
  font_size : Int,
  is_bold : Bool,
  is_italic : Bool,
) -> MeasuredText {
  let kind = select_font_kind(true, is_bold, is_italic)
  measure_text_with_mode(text, font_size, kind, true, true)
}

///|
/// Measure text using monospace glyph metrics with regular (non-code) line height.
///
/// This matches the reference's `ruler.Measure(SourceCodePro, ...)` behavior used by
/// UML class sizing: monospace font, but without code-block line-height logic.
pub fn measure_text_mono_plain(text : String, font_size : Int) -> MeasuredText {
  measure_text_with_mode(text, font_size, MonoRegular, false, false)
}

///|
/// Measure label width with padding
pub fn measure_label(
  text : String,
  font_size : Int,
  is_mono : Bool,
  is_bold : Bool,
  is_italic : Bool,
) -> TextDimensions {
  measure_text(text, font_size, is_mono, is_bold, is_italic).dimensions
}

///|
/// Measure label dimensions with D2's hand-drawn font.
pub fn measure_label_hand_drawn(
  text : String,
  font_size : Int,
  is_bold : Bool,
) -> TextDimensions {
  measure_text_hand_drawn(text, font_size, is_bold).dimensions
}

///|
/// Measure label dimensions for code snippets (language-tagged block strings).
pub fn measure_label_code(
  text : String,
  font_size : Int,
  is_bold : Bool,
  is_italic : Bool,
) -> TextDimensions {
  measure_text_code(text, font_size, is_bold, is_italic).dimensions
}

///|
/// Measure edge label width
pub fn measure_edge_label(text : String, font_size : Int) -> TextDimensions {
  measure_label(text, font_size, false, false, false)
}
