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
/// Browser-facing wasm1 ABI.
///
/// JavaScript writes one versioned JSON request into the exported transfer
/// arena, calls `render`, and reads the UTF-8 result body from the same arena.

///|
let abi_version_number : Int32 = 2

///|
let transfer_start : Int32 = 1048576

///|
let transfer_size : Int32 = 15728640

///|
let status_ok : Int32 = 0

///|
let status_error : Int32 = 1

///|
let error_none : Int32 = 0

///|
let error_request_length : Int32 = 1

///|
let error_invalid_utf8 : Int32 = 2

///|
let error_invalid_json : Int32 = 3

///|
let error_unsupported_version : Int32 = 4

///|
let error_invalid_request : Int32 = 5

///|
let error_parse : Int32 = 10

///|
let error_io : Int32 = 11

///|
let error_ir : Int32 = 12

///|
let error_graph : Int32 = 13

///|
let error_config : Int32 = 14

///|
let error_layout : Int32 = 15

///|
let error_render : Int32 = 16

///|
let error_target : Int32 = 17

///|
let error_result_too_large : Int32 = 18

///|
let error_unsupported_feature : Int32 = 19

///|
priv struct WasmResultState {
  mut length : Int32
  mut error_kind : Int32
  mut required_length : Int32
}

///|
let wasm_result_state : WasmResultState = {
  length: 0,
  error_kind: error_none,
  required_length: 0,
}

///|
pub fn abi_version() -> Int32 {
  abi_version_number
}

///|
pub fn transfer_ptr() -> Int32 {
  transfer_start
}

///|
pub fn transfer_capacity() -> Int32 {
  transfer_size
}

///|
pub fn result_len() -> Int32 {
  wasm_result_state.length
}

///|
pub fn result_error_kind() -> Int32 {
  wasm_result_state.error_kind
}

///|
pub fn result_required_len() -> Int32 {
  wasm_result_state.required_length
}

///|
pub fn render(request_len : Int32) -> Int32 {
  reset_result_state()
  let request_text = match read_request(request_len) {
    Ok(text) => text
    Err(failure) => return finish_error(failure.error_kind, failure.message)
  }
  let request_json = @json.parse(request_text) catch {
    error => return finish_error(error_invalid_json, error.to_string())
  }
  let request = match decode_render_request(request_json) {
    Ok(request) => request
    Err(failure) => return finish_error(failure.error_kind, failure.message)
  }
  let output = @diago.compile(request.source, options=request.options) catch {
    error => {
      let (error_kind, message) = diago_error_metadata(error)
      return finish_error(error_kind, message)
    }
  }
  finish_success(output)
}

///|
fn reset_result_state() -> Unit {
  wasm_result_state.length = 0
  wasm_result_state.error_kind = error_none
  wasm_result_state.required_length = 0
}

///|
fn read_request(request_len : Int32) -> Result[String, WasmFailure] {
  if request_len < 0 || request_len > transfer_size {
    return Err({
      error_kind: error_request_length,
      message: "request length must be between 0 and \{transfer_size} bytes",
    })
  }
  let bytes : Array[Byte] = []
  for index in 0..<request_len {
    bytes.push(wasm_load_u8(transfer_start + index).to_byte())
  }
  try @utf8.decode(Bytes::from_array(bytes)) catch {
    _ =>
      Err({
        error_kind: error_invalid_utf8,
        message: "request body must be valid UTF-8",
      })
  } noraise {
    text => Ok(text)
  }
}

///|
fn finish_success(body : String) -> Int32 {
  finish_result(body, error_none)
}

///|
fn finish_error(error_kind : Int32, message : String) -> Int32 {
  finish_result(message, error_kind)
}

///|
fn finish_result(body : String, error_kind : Int32) -> Int32 {
  let bytes = @utf8.encode(body)
  wasm_result_state.required_length = bytes.length()
  if bytes.length() > transfer_size {
    let required_length = bytes.length()
    let fallback = @utf8.encode(
      "result body requires \{required_length} bytes, exceeding transfer capacity \{transfer_size}",
    )
    write_transfer_bytes(fallback)
    wasm_result_state.length = fallback.length()
    wasm_result_state.error_kind = error_result_too_large
    wasm_result_state.required_length = required_length
    return status_error
  }
  write_transfer_bytes(bytes)
  wasm_result_state.length = bytes.length()
  wasm_result_state.error_kind = error_kind
  if error_kind == error_none {
    status_ok
  } else {
    status_error
  }
}

///|
fn write_transfer_bytes(bytes : Bytes) -> Unit {
  for index in 0..<bytes.length() {
    wasm_store_u8(transfer_start + index, bytes[index].to_int())
  }
}

///|
fn diago_error_metadata(error : @diago.DiagoError) -> (Int32, String) {
  match error {
    ParseError(message) => (error_parse, message)
    IOError(message) => (error_io, message)
    IrError(message) => (error_ir, message)
    GraphError(message) => (error_graph, message)
    ConfigError(message) => (error_config, message)
    LayoutError(message) => (error_layout, message)
    RenderError(message) => (error_render, message)
    TargetError(message) => (error_target, message)
    UnsupportedFeature(message) => (error_unsupported_feature, message)
  }
}

///|
extern "wasm" fn wasm_load_u8(ptr : Int32) -> Int32 =
  #|(func (param i32) (result i32)
  #|  (i32.load8_u (local.get 0)))

///|
extern "wasm" fn wasm_store_u8(ptr : Int32, value : Int32) -> Unit =
  #|(func (param i32 i32)
  #|  (i32.store8 (local.get 0) (local.get 1)))
