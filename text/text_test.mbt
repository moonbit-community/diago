///|
test "text output matches the full facade for both formats" {
  let sources = [
    "a -> b", "direction: right\na: Hello\na -> b: label", "group: { a -> b }\ngroup.b -> c",
    "shape: sequence_diagram\na -> b: Hello\nb -> a: Reply", "grid: { grid-columns: 2; a; b; c; d }",
    "vars: { d2-config: { theme-id: 300 } }\na -> b",
  ]
  for source in sources {
    assert_eq(
      @text.compile(source),
      @diago.compile(
        source,
        options=@diago.CompileOptions::new().with_output_mode(Ascii),
      ),
      msg=source,
    )
    assert_eq(
      @text.compile(source, mode=Unicode),
      @diago.compile(
        source,
        options=@diago.CompileOptions::new().with_output_mode(Unicode),
      ),
      msg=source,
    )
  }
}

///|
test "text allows explicit layout engines" {
  let source = "vars: { d2-config: { layout-engine: elk } }\na -> b"
  assert_eq(
    @text.compile_with_engine(source, @engine_elk.ElkEngine::new()),
    @diago.compile(
      source,
      options=@diago.CompileOptions::new().with_output_mode(Ascii),
    ),
  )
  let rejected = try @text.compile(source) catch {
    UnsupportedFeature(message) => message.contains("compile_with_engine")
    _ => false
  } noraise {
    _ => false
  }
  inspect(rejected, content="true")
}

///|
test "text reports source and unsupported feature errors" {
  let invalid = try @text.compile("a ->") catch {
    CompileError(_) => true
    _ => false
  } noraise {
    _ => false
  }
  inspect(invalid, content="true")
  let unsupported = try @text.compile("a: { style.sketch: true }") catch {
    UnsupportedFeature(message) => message
    _ => "unexpected error"
  } noraise {
    _ => "unexpected success"
  }
  inspect(unsupported, content="sketch rendering is not supported")
}

///|
test "text keeps explicit import resolution backend independent" {
  let resolver = @ir.ImportResolver::new(fn(path) {
    if path == "common" || path == "common.d2" {
      Some("a -> b")
    } else {
      None
    }
  })
  let source = "group: @common"
  assert_eq(
    @text.compile(
      source,
      parse_options=@compiler.ParseOptions::new().with_import_resolver(
        Some(resolver),
      ),
    ),
    @diago.compile(
      source,
      options=@diago.CompileOptions::new()
        .with_output_mode(Ascii)
        .with_parse_options(
          @diago.ParseOptions::new().with_import_resolver(Some(resolver)),
        ),
    ),
  )
}
