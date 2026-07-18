///|
test "code language aliases normalize" {
  assert_true(code_language_from_tag(Some("go")) == Go)
  assert_true(code_language_from_tag(Some("golang")) == Go)
  assert_true(code_language_from_tag(Some("js")) == JavaScript)
  assert_true(code_language_from_tag(Some("ts")) == TypeScript)
  assert_true(code_language_from_tag(Some("py")) == Python)
  assert_true(code_language_from_tag(Some("md")) == Markdown)
  assert_true(code_language_from_tag(Some("css")) == Css)
  assert_true(code_language_from_tag(Some("moonbit")) == MoonBit)
  assert_true(code_language_from_tag(Some("mbt")) == MoonBit)
}

///|
test "javascript line highlights keyword function number and comment" {
  let raw = code_line_svg_raw(
    "const x = foo(1) // comment",
    Some("javascript"),
    false,
  )
  assert_true(
    raw.contains("fill=\"#000000\" class=\"text-mono-bold\">const</tspan>"),
  )
  assert_true(
    raw.contains("fill=\"#990000\" class=\"text-mono-bold\">foo</tspan>"),
  )
  assert_true(raw.contains("fill=\"#009999\">1</tspan>"))
  assert_true(
    raw.contains(
      "fill=\"#999988\" class=\"text-mono-italic\">//&#160;comment</tspan>",
    ),
  )
}

///|
test "markup line highlights tag and attribute" {
  let raw = code_line_svg_raw("<div class=\"x\">ok</div>", Some("html"), false)
  assert_true(raw.contains("fill=\"#000080\">div</tspan>"))
  assert_true(raw.contains("fill=\"#008080\">class</tspan>"))
}

///|
test "unknown language uses dark text fallback style" {
  let raw = code_line_svg_raw("hello world", Some("unknown"), true)
  @debug.assert_eq(raw, "<tspan fill=\"#cdd6f4\">hello&#160;world</tspan>")
}

///|
test "go lexer preserves Chroma's empty capture on a blank line" {
  @debug.assert_eq(
    code_line_svg_raw("", Some("go"), true),
    "<tspan fill=\"#cdd6f4\"></tspan>",
  )
  @debug.assert_eq(code_line_svg_raw("", Some("css"), true), "")
}

///|
test "css lexer matches Chroma selector and media token boundaries" {
  @debug.assert_eq(
    code_line_svg_raw(".fill-N1: {", Some("css"), false),
    ".<tspan fill=\"#445588\" class=\"text-mono-bold\">fill-N1</tspan><tspan fill=\"#000000\" class=\"text-mono-bold\">:</tspan>&#160;{",
  )
  @debug.assert_eq(
    code_line_svg_raw(
      "@media (prefers-color-scheme: dark) {",
      Some("css"),
      false,
    ),
    "@<tspan fill=\"#000000\" class=\"text-mono-bold\">media</tspan>&#160;<tspan fill=\"#000000\" class=\"text-mono-bold\">(</tspan><tspan fill=\"#000080\">prefers-color-scheme</tspan><tspan fill=\"#000000\" class=\"text-mono-bold\">:</tspan>&#160;<tspan fill=\"#000080\">dark</tspan><tspan fill=\"#000000\" class=\"text-mono-bold\">)</tspan>&#160;{",
  )
  @debug.assert_eq(
    code_line_svg_raw("  fill: \"#000\"", Some("css"), true),
    "<tspan fill=\"#cdd6f4\">&#160;&#160;</tspan><tspan fill=\"#cdd6f4\">fill</tspan><tspan fill=\"#cdd6f4\"></tspan><tspan fill=\"#cdd6f4\">:</tspan><tspan fill=\"#cdd6f4\">&#160;</tspan><tspan fill=\"#a6e3a1\">&quot;#000&quot;</tspan>",
  )
  @debug.assert_eq(
    code_line_svg_raw("  ", Some("css"), true),
    "<tspan fill=\"#cdd6f4\">&#160;&#160;</tspan>",
  )
}

///|
test "html lexer matches Chroma error and continuation tokens" {
  let first = code_line_svg_raw(
    "<rect class=\"fill-N1\" ... />",
    Some("html"),
    false,
  )
  @debug.assert_eq(
    first, "&lt;<tspan fill=\"#000080\">rect</tspan>&#160;<tspan fill=\"#008080\">class</tspan><tspan fill=\"#000000\" class=\"text-mono-bold\">=</tspan><tspan fill=\"#dd1144\">&quot;fill-N1&quot;</tspan>&#160;<tspan fill=\"#a61717\">.</tspan><tspan fill=\"#a61717\">.</tspan><tspan fill=\"#a61717\">.</tspan>&#160;/&gt;",
  )
  let continuation = code_line_svg_raw(
    "  style=\"fill: red\" ... />",
    Some("html"),
    false,
  )
  @debug.assert_eq(
    continuation, "&#160;&#160;<tspan fill=\"#008080\">style</tspan><tspan fill=\"#000000\" class=\"text-mono-bold\">=</tspan><tspan fill=\"#dd1144\">&quot;fill:&#160;red&quot;</tspan>&#160;<tspan fill=\"#a61717\">.</tspan><tspan fill=\"#a61717\">.</tspan><tspan fill=\"#a61717\">.</tspan>&#160;/&gt;",
  )
}

///|
test "moonbit highlights keywords and brackets only" {
  let raw = code_line_svg_raw(
    "pub fn add(x : Int) -> Int { x + 1 }",
    Some("moonbit"),
    false,
  )
  assert_true(
    raw.contains("fill=\"#000000\" class=\"text-mono-bold\">pub</tspan>"),
  )
  assert_true(
    raw.contains("fill=\"#000000\" class=\"text-mono-bold\">fn</tspan>"),
  )
  assert_true(raw.contains("fill=\"#0550ae\">(</tspan>"))
  assert_true(raw.contains("fill=\"#0550ae\">)</tspan>"))
  assert_true(raw.contains("fill=\"#0550ae\">{</tspan>"))
  assert_true(raw.contains("fill=\"#0550ae\">}</tspan>"))
  assert_true(!raw.contains("fill=\"#990000\""))
}

///|
test "moonbit treats where as keyword and await as plain text" {
  let raw = code_line_svg_raw(
    "fn f[T] where T: Show { await x }",
    Some("mbt"),
    false,
  )
  assert_true(
    raw.contains("fill=\"#000000\" class=\"text-mono-bold\">where</tspan>"),
  )
  assert_true(
    !raw.contains("fill=\"#000000\" class=\"text-mono-bold\">await</tspan>"),
  )
}
