# Text-only diagrams

Import `moonbit-community/diago/text` to compile ASCII or Unicode output without
the SVG renderer, bundled TTF assets, font subsetting, or ELK. The package works
on every MoonBit target and uses Dagre by default.

```moonbit check
///|
test {
  let ascii = @text.compile("a -> b")
  let unicode = @text.compile("a -> b", mode=Unicode)
  inspect(ascii.contains("+----+"), content="true")
  inspect(unicode.contains("┌"), content="true")
}
```

The default engine honors source direction and theme configuration. Source
that selects another layout engine reports an error instead of silently
falling back. Import the desired engine and call `compile_with_engine` to opt
into its implementation:

```moonbit check
///|
test {
  let output = @text.compile_with_engine(
    "a -> b",
    @engine_elk.ElkEngine::new(),
    mode=Unicode,
  )
  inspect(output.contains("┌"), content="true")
}
```

`parse_options` accepts `compiler.ParseOptions`, including an explicit import
resolver. This package performs no filesystem or network I/O. Its measurement
tables are retained to preserve layout and match the full facade's text output.
