///|
test "bytes_to_string decodes utf8 input" {
  let bytes = @utf8.encode("你好 -> y"[:]).to_array()
  @debug.assert_eq(bytes_to_string(bytes), "你好 -> y")
}

///|
test "string_to_bytes encodes utf8 output" {
  let out : Array[Byte] = []
  string_to_bytes("你好 -> y", out)
  @debug.assert_eq(
    @utf8.decode_lossy(Bytes::from_array(out[:]).view()),
    "你好 -> y",
  )
}

///|
test "wasm facade renders svg ascii and unicode" {
  string_to_bytes("a -> b", input_buffer)
  assert_eq(render_svg(), 0)
  assert_true(bytes_to_string(output_buffer).contains("<svg"))
  assert_eq(render_ascii(), 0)
  assert_true(bytes_to_string(output_buffer).contains("a"))
  assert_eq(render_unicode(), 0)
  assert_true(bytes_to_string(output_buffer).contains("a"))
}
