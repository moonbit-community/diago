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
/// WASM entry point for Diago
///
/// Exports render functions for browser usage.

///|
/// Shared buffer for input/output string passing
let input_buffer : Array[Byte] = []

///|
let output_buffer : Array[Byte] = []

///|
/// Set input string (called from JS before render)
pub fn set_input(len : Int) -> Int {
  input_buffer.resize(len, b'\x00')
  0 // Return pointer offset (always 0 for our simple buffer)
}

///|
/// Get pointer to input buffer
pub fn get_input_ptr() -> Int {
  0 // Using index-based access
}

///|
/// Write a byte to input buffer
pub fn write_input_byte(index : Int, byte : Int) -> Unit {
  if index < input_buffer.length() {
    input_buffer[index] = byte.to_byte()
  }
}

///|
/// Get output length after render
pub fn get_output_len() -> Int {
  output_buffer.length()
}

///|
/// Read a byte from output buffer
pub fn read_output_byte(index : Int) -> Int {
  if index < output_buffer.length() {
    output_buffer[index].to_int()
  } else {
    0
  }
}

///|
/// Render diago source to SVG
pub fn render_svg() -> Int {
  render_svg_with_engine(0)
}

///|
pub fn render_svg_with_engine(engine : Int) -> Int {
  let source = bytes_to_string(input_buffer)
  let result = compile_source(source, Svg, engine)
  match result {
    Ok(svg) => {
      string_to_bytes(svg, output_buffer)
      0 // Success
    }
    Err(e) => {
      string_to_bytes("Error: \{e}", output_buffer)
      1 // Error
    }
  }
}

///|
/// Render diago source to ASCII
pub fn render_ascii() -> Int {
  render_ascii_with_engine(0)
}

///|
pub fn render_ascii_with_engine(engine : Int) -> Int {
  let source = bytes_to_string(input_buffer)
  let result = compile_source(source, Ascii, engine)
  match result {
    Ok(ascii) => {
      string_to_bytes(ascii, output_buffer)
      0 // Success
    }
    Err(e) => {
      string_to_bytes("Error: \{e}", output_buffer)
      1 // Error
    }
  }
}

///|
/// Render diago source to Unicode box-drawing characters
pub fn render_unicode() -> Int {
  render_unicode_with_engine(0)
}

///|
pub fn render_unicode_with_engine(engine : Int) -> Int {
  let source = bytes_to_string(input_buffer)
  let result = compile_source(source, Unicode, engine)
  match result {
    Ok(text) => {
      string_to_bytes(text, output_buffer)
      0 // Success
    }
    Err(e) => {
      string_to_bytes("Error: \{e}", output_buffer)
      1 // Error
    }
  }
}

///|
fn bytes_to_string(bytes : Array[Byte]) -> String {
  let data = Bytes::from_array(bytes[:])
  @utf8.decode_lossy(data.view())
}

///|
/// Encode string to UTF-8 bytes
fn string_to_bytes(s : String, out : Array[Byte]) -> Unit {
  out.clear()
  let bytes = @utf8.encode(s[:])
  for i in 0..<bytes.length() {
    out.push(bytes[i])
  }
}

///|
/// Compile diago source through the backend-independent facade.
fn compile_source(
  source : String,
  output_mode : @diago.OutputMode,
  engine : Int,
) -> Result[String, String] {
  let options = @diago.CompileOptions::new()
    .with_output_mode(output_mode)
    .with_layout_engine(resolve_layout_engine(engine))
  try @diago.compile(source, options~) catch {
    err => Err(diago_error_message(err))
  } noraise {
    output => Ok(output)
  }
}

///|
fn resolve_layout_engine(engine : Int) -> @diago.LayoutEngine {
  if engine == 1 {
    Elk
  } else if engine == 2 {
    Railway
  } else {
    Dagre
  }
}

///|
fn diago_error_message(err : @diago.DiagoError) -> String {
  match err {
    ParseError(message) => message
    IOError(message) => message
    IrError(message) => message
    GraphError(message) => message
    ConfigError(message) => message
    LayoutError(message) => message
    RenderError(message) => message
    TargetError(message) => message
  }
}
