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
test "measure text width - short" {
  let dims = @text_metrics.measure_text("Hello", 16, false, false, false)
  assert_true(dims.dimensions.width >= 30.0)
  assert_true(dims.dimensions.height > 10.0)
  @debug.assert_eq(dims.line_count, 0)
}

///|
test "measure text width - long" {
  let dims = @text_metrics.measure_text(
    "This is a longer text for testing", 16, false, false, false,
  )
  assert_true(dims.dimensions.width > 100.0)
  @debug.assert_eq(dims.line_count, 0)
}

///|
test "measure arbitrary font sizes with D2 fixed-point rounding" {
  inspect(
    @text_metrics.measure_label("A better world", 40, false, false, false),
    content="{width: 234, height: 51}",
  )
  inspect(
    @text_metrics.measure_label("A winning strategy", 55, false, false, true),
    content="{width: 423, height: 70}",
  )
}

///|
test "measure geometric glyph labels like D2" {
  inspect(
    @text_metrics.measure_label("⬤ Forge CLI", 10, false, false, false),
    content="{width: 47, height: 13}",
  )
  inspect(
    @text_metrics.measure_label("⬤ Required", 10, false, false, false),
    content="{width: 47, height: 13}",
  )
  inspect(
    @text_metrics.measure_label("⬤ Optional", 10, false, false, false),
    content="{width: 46, height: 13}",
  )
}

///|
test "measure text with newlines" {
  let dims = @text_metrics.measure_text(
    "Line 1\nLine 2\nLine 3", 14, false, false, false,
  )
  @debug.assert_eq(dims.line_count, 2)
  @debug.assert_eq(dims.dimensions.height, 46.0)
}

///|
test "measure two-line code uses precise first-line bounds" {
  let measured = @text_metrics.measure_text_code(
    "declare function getSmallPet(): Fish | Bird;\nconst works = (a > 1) || (b < 2)",
    16, false, false,
  )
  @debug.assert_eq(measured.dimensions.width, 423.0)
  @debug.assert_eq(measured.dimensions.height, 41.0)
}

///|
test "measure text with leading empty line" {
  let dims = @text_metrics.measure_text("\nLine 1", 14, false, false, false)
  @debug.assert_eq(dims.line_count, 1)
  @debug.assert_eq(dims.dimensions.height, 18.0)
}

///|
test "measure text with trailing empty lines" {
  let dims = @text_metrics.measure_text("Line 1\n\n", 14, false, false, false)
  @debug.assert_eq(dims.line_count, 2)
  @debug.assert_eq(dims.dimensions.height, 18.0)
}

///|
test "measure multiline note text like the reference ruler" {
  inspect(
    @text_metrics.measure_label(
      "just\na\nlong\nnote\nhere", 16, false, false, false,
    ),
    content="{width: 32, height: 85}",
  )
}

///|
test "measure label probe for empty nested grid parity" {
  inspect(
    @text_metrics.measure_label("inner", 24, false, true, false),
    content="{width: 56, height: 31}",
  )
}

///|
test "measure styled mono labels with D2 font faces" {
  let bold = @text_metrics.measure_text("x", 16, true, true, false)
  @debug.assert_eq(bold.max_line_width, 9.0)
  @debug.assert_eq(bold.dimensions.width, 9.0)
  @debug.assert_eq(bold.dimensions.height, 21.0)
  let italic = @text_metrics.measure_text("hi", 16, true, false, true)
  @debug.assert_eq(italic.max_line_width, 17.59375)
  @debug.assert_eq(italic.dimensions.width, 18.0)
  @debug.assert_eq(italic.dimensions.height, 21.0)
}

///|
test "measure short bold labels with Source Sans Pro" {
  inspect(
    @text_metrics.measure_label("x", 16, false, true, false),
    content="{width: 8, height: 21}",
  )
  inspect(
    @text_metrics.measure_label("y", 16, false, true, false),
    content="{width: 9, height: 21}",
  )
}

///|
test "measure short bold labels with D2 hand-drawn font" {
  inspect(
    @text_metrics.measure_label_hand_drawn("x", 16, true),
    content="{width: 9, height: 21}",
  )
  inspect(
    @text_metrics.measure_label_hand_drawn("y", 16, true),
    content="{width: 9, height: 21}",
  )
}

///|
test "measure terminal theme labels with Source Code Pro" {
  inspect(
    @text_metrics.measure_label("API SERVER", 16, true, true, false),
    content="{width: 97, height: 21}",
  )
  inspect(
    @text_metrics.measure_label("TRANSMITTER", 16, true, true, false),
    content="{width: 106, height: 21}",
  )
  inspect(
    @text_metrics.measure_label("NETWORK", 28, true, false, false),
    content="{width: 116, height: 36}",
  )
}

///|
test "unicode width follows D2 grapheme scaling" {
  inspect(
    @text_metrics.measure_text(
      "トマトが赤くなったのはなぜですか？", 55, false, true, false,
    ).dimensions,
    content="{width: 1182, height: 70}",
  )
  inspect(
    @text_metrics.measure_text(
      "Because it saw the salad dressing!👩‍👩‍👧‍👶👩‍👩‍👧‍👶",
      55, false, true, false,
    ).dimensions,
    content="{width: 1348, height: 70}",
  )
  inspect(
    @text_metrics.measure_text("床前明月光，", 16, false, false, false).dimensions,
    content="{width: 117, height: 21}",
  )
}

///|
test "measure markdown heading like the reference constant_near_title" {
  inspect(
    @text_metrics.measure_label_markdown("# A winning strategy", 16),
    content="{width: 257, height: 51}",
  )
}

///|
test "measure markdown table dollars like D2" {
  inspect(
    @text_metrics.markdown_source_like_d2("| $80 | -$120 |"),
    content="| &#36;80 | -&#36;120 |",
  )
  inspect(
    @text_metrics.measure_label_markdown(
      (
        #|| Month    | Savings | Expenses | Balance |
        #|| -------- | ------- | -------- | ------- |
        #|| January  | $250    | $150     | $100    |
        #|| February | $80     | $200     | -$120   |
        #|| March    | $420    | $180     | $240    |
      ),
      16,
    ),
    content="{width: 343, height: 150}",
  )
}

///|
test "measure markdown unicode with dot bounds like the reference" {
  inspect(
    @text_metrics.measure_label_markdown(
      (
        #|床前明月光，
        #|
        #|疑是地上霜。
        #|
        #|举头望明月，
        #|
        #|低头思故乡。
      ),
      16,
    ),
    content="{width: 118, height: 144}",
  )
}

///|
test "measure markdown hard-break continuation whitespace like D2" {
  inspect(
    @text_metrics.measure_label_markdown(
      (
        #|# LLMs
        #|short\
        #|This cutting-edge technology enables LLM to generate human-like text,
      ),
      16,
    ),
    content="{width: 477, height: 115}",
  )
}

///|
test "measure markdown mixed blocks like D2" {
  inspect(
    @text_metrics.measure_label_markdown(
      (
        #|# I can do headers
        #|- lists
        #|- lists
        #|
        #|And other normal markdown stuff
      ),
      16,
    ),
    content="{width: 228, height: 159}",
  )
}

///|
test "measure markdown inline emphasis runs like D2" {
  inspect(
    @text_metrics.measure_label_markdown(
      (
        #|# What is a cult?
        #|- *Definition*: A group or movement with a shared devotion to a charismatic leader, an ideology, or a set of rituals and beliefs
        #|- *Characteristics*: Totalitarian control, manipulative practices, and exploitation of members
      ),
      16,
    ),
    content="{width: 839, height: 119}",
  )
}

///|
test "markdown blank lines preserve CSS margin collapsing" {
  inspect(
    @text_metrics.measure_label_markdown(
      (
        #|# Charismatic Leader
        #|
        #|## Role
        #|
        #|Cult leaders have a strong, magnetic personality, and are typically seen as an authority figure
        #|
        #|## Tips:
        #|
        #|- Cultivate a unique and compelling persona
        #|- Be convincing and persuasive
        #|- Establish yourself as an authority figure with exclusive knowledge or abilities
      ),
      16,
    ),
    content="{width: 619, height: 312}",
  )
}

///|
test "markdown mixed headings and list preserve reference rounding" {
  inspect(
    @text_metrics.measure_label_markdown(
      (
        #|# Control and manipulation
        #|
        #|## Purpose
        #|To maintain power over members and ensure loyalty
        #|
        #|## Techniques
        #|Information control, emotional manipulation, and behavior control
        #|
        #|## Tips:
        #|
        #|- Limit members' access to outside information and discourage critical thinking
        #|- Use guilt, shame, and fear to manipulate members' emotions
        #|- Create strict rules and rituals to control behavior
      ),
      16,
    ),
    content="{width: 552, height: 415}",
  )
}

///|
