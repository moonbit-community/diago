///|
fn write_test_request(request : String) -> Int {
  let bytes = @utf8.encode(request)
  for index in 0..<bytes.length() {
    wasm_store_u8(transfer_start + index, bytes[index].to_int())
  }
  bytes.length()
}

///|
fn read_test_result() -> String raise {
  let bytes : Array[Byte] = []
  for index in 0..<result_len() {
    bytes.push(wasm_load_u8(transfer_start + index).to_byte())
  }
  @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => fail("result must be valid UTF-8")
  }
}

///|
test "wasm ABI exposes one versioned render transaction" {
  @debug.assert_eq(abi_version(), 1)
  @debug.assert_eq(transfer_ptr(), 1048576)
  @debug.assert_eq(transfer_capacity(), 15728640)
  let length = write_test_request(
    "{\"version\":1,\"source\":\"a -> b\",\"output\":\"svg\",\"layout\":\"dagre\"}",
  )
  @debug.assert_eq(render(length), status_ok)
  @debug.assert_eq(result_error_kind(), error_none)
  assert_true(read_test_result().contains("<svg"))
}

///|
test "wasm ABI returns structured parse errors" {
  let length = write_test_request(
    "{\"version\":1,\"source\":\"a: {\",\"output\":\"svg\"}",
  )
  @debug.assert_eq(render(length), status_error)
  @debug.assert_eq(result_error_kind(), error_parse)
  assert_true(read_test_result().contains("expected }"))
}

///|
test "wasm ABI returns structured unsupported feature errors" {
  let length = write_test_request(
    "{\"version\":1,\"source\":\"formula: |tex\\n  x^2\\n|\",\"output\":\"svg\"}",
  )
  @debug.assert_eq(render(length), status_error)
  @debug.assert_eq(result_error_kind(), error_unsupported_feature)
  @debug.assert_eq(read_test_result(), "LaTeX labels are not supported")
}

///|
test "wasm ABI validates request metadata without trapping" {
  @debug.assert_eq(render(-1), status_error)
  @debug.assert_eq(result_error_kind(), error_request_length)
  @debug.assert_eq(render(transfer_capacity() + 1), status_error)
  @debug.assert_eq(result_error_kind(), error_request_length)
  wasm_store_u8(transfer_start, 255)
  @debug.assert_eq(render(1), status_error)
  @debug.assert_eq(result_error_kind(), error_invalid_utf8)
  let invalid_json = write_test_request("{")
  @debug.assert_eq(render(invalid_json), status_error)
  @debug.assert_eq(result_error_kind(), error_invalid_json)
  let invalid_version = write_test_request(
    "{\"version\":2,\"source\":\"a -> b\"}",
  )
  @debug.assert_eq(render(invalid_version), status_error)
  @debug.assert_eq(result_error_kind(), error_unsupported_version)
  let invalid_layout = write_test_request(
    "{\"version\":1,\"source\":\"a -> b\",\"layout\":\"unknown\"}",
  )
  @debug.assert_eq(render(invalid_layout), status_error)
  @debug.assert_eq(result_error_kind(), error_invalid_request)
  let unknown_field = write_test_request(
    "{\"version\":1,\"source\":\"a -> b\",\"layuot\":\"dagre\"}",
  )
  @debug.assert_eq(render(unknown_field), status_error)
  @debug.assert_eq(result_error_kind(), error_invalid_request)
  assert_true(read_test_result().contains("unknown request field"))
}

///|
test "wasm ABI defaults layout to auto" {
  let length = write_test_request(
    "{\"version\":1,\"source\":\"vars: { d2-config: { layout-engine: invalid } }\\na -> b\"}",
  )
  @debug.assert_eq(render(length), status_error)
  @debug.assert_eq(result_error_kind(), error_config)
  assert_true(read_test_result().contains("unsupported layout engine"))
}
