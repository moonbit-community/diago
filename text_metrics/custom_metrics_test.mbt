///|
test "custom measurement receives style and preserves fractional width" {
  let requests : Array[@fonts.MeasureRequest] = []
  let measurer = Some(
    @fonts.Measurer::new(fn(request) {
      requests.push(request)
      { width: 42.25, height: 57.5, }
    }),
  )
  let measured = @text_metrics.measure_text(
    "a\nb",
    19,
    false,
    false,
    true,
    measurer~,
  )
  assert_eq(measured.dimensions.width, 43.0)
  assert_eq(measured.dimensions.height, 58.0)
  assert_eq(measured.max_line_width, 42.25)
  assert_eq(measured.line_count, 1)
  assert_eq(requests[0].text, "a\nb")
  assert_eq(requests[0].font_size, 19)
  assert_true(requests[0].face == SansItalic)
  assert_false(requests[0].bounds_with_dot)
  assert_false(requests[0].code_line_height)
  let _ = @text_metrics.measure_text_code("code", 13, true, false, measurer~)
  assert_true(requests[1].face == MonoBold)
  assert_true(requests[1].bounds_with_dot)
  assert_true(requests[1].code_line_height)
}

///|
test "custom measurement can fall back without leaking into other calls" {
  let original = @text_metrics.measure_text("same", 16, false, true, false)
  let measurer = Some(
    @fonts.Measurer::new(fn(request) {
      let fallback = @text_metrics.measure_builtin(request)
      {
        width: fallback.max_line_width * 3.0,
        height: fallback.dimensions.height * 2.0,
      }
    }),
  )
  let custom = @text_metrics.measure_text(
    "same",
    16,
    false,
    true,
    false,
    measurer~,
  )
  assert_true(custom.dimensions.width > original.dimensions.width)
  assert_true(custom.dimensions.height > original.dimensions.height)
  assert_eq(
    @text_metrics.measure_text("same", 16, false, true, false),
    original,
  )
}

///|
test "Markdown measures styled runs and reserves custom vertical bounds" {
  let faces : Map[@fonts.Face, Bool] = Map([])
  let measurer = Some(
    @fonts.Measurer::new(fn(request) {
      faces[request.face] = true
      { width: 300.0, height: 100.0, }
    }),
  )
  let documents = [
    "# Heading\n\nNormal **bold** *italic* `code`", "```js\nfirst\nsecond\n```",
    "| Heading |\n| --- |\n| Cell |",
  ]
  for source in documents {
    let custom = @text_metrics.measure_label_markdown(source, 16, measurer~)
    let original = @text_metrics.measure_label_markdown(source, 16)
    assert_true(custom.width > original.width, msg=source)
    assert_true(custom.height > original.height, msg=source)
  }
  for
    face in [
      @fonts.Face::SansSemibold,
      SansRegular,
      SansBold,
      SansItalic,
      MonoRegular,
    ] {
    assert_true(faces.contains(face), msg=face.name())
  }
}
