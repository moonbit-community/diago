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
pub(all) struct LatexOutput {
  svg : String
  width : Int
  height : Int
} derive(Debug, Eq)

///|
pub(all) suberror LatexError {
  RuntimeError(String)
  InvalidSvg(String)
} derive(Debug, Eq)

///|
pub impl Show for LatexError with fn output(self, logger) {
  match self {
    RuntimeError(message) => logger.write_string(message)
    InvalidSvg(svg) =>
      logger.write_string("MathJax returned invalid SVG: \{svg}")
  }
}

///|
priv struct LatexSession {
  interp : @interpreter.Interpreter
}

///|
let latex_sessions : Array[LatexSession] = []

///|
let latex_output_cache : Map[String, LatexOutput] = Map([])

///|
fn latex_run_source(
  interp : @interpreter.Interpreter,
  name : String,
  source : String,
) -> @interpreter.Value raise LatexError {
  let program = @parser.parse(source) catch {
    e => raise RuntimeError("MathJax \{name} parse failed: \{e}")
  }
  let result = interp.run(program.stmts) catch {
    e => raise RuntimeError("MathJax \{name} execution failed: \{e}")
  }
  interp.run_microtasks() catch {
    e => raise RuntimeError("MathJax \{name} microtask failed: \{e}")
  }
  interp.run_timers() catch {
    e => raise RuntimeError("MathJax \{name} timer failed: \{e}")
  }
  result
}

///|
fn LatexSession::new() -> LatexSession raise LatexError {
  let interp = @interpreter.new_interpreter()
  ignore(
    latex_run_source(
      interp, "polyfills prelude", "var XML_ENTITIES, HTML_ENTITIES, __set__, __DOMHandler, entities;",
    ),
  )
  ignore(latex_run_source(interp, "polyfills", latex_polyfills_source))
  ignore(
    latex_run_source(
      interp, "polyfills epilogue", "entities = { XML_ENTITIES: XML_ENTITIES, HTML_ENTITIES: HTML_ENTITIES };",
    ),
  )
  ignore(
    latex_run_source(
      interp, "bundle prelude", "var MathJax = { version: '3.2.2', _: {}, config: {} }; globalThis.MathJax = MathJax;",
    ),
  )
  ignore(latex_run_source(interp, "bundle", latex_mathjax_source))
  ignore(latex_run_source(interp, "setup", latex_setup_source))
  { interp, }
}

///|
fn parse_ex_dimension(svg : String, name : String) -> Double? {
  let marker = name + "=\""
  guard string_index_of(svg, marker, 0) is Some(start) else { return None }
  let value_start = start + marker.length()
  guard string_index_of(svg, "ex\"", value_start) is Some(value_end) else {
    return None
  }
  try @string.parse_double(svg[value_start:value_end].to_owned()) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn string_index_of(text : String, pattern : String, start : Int) -> Int? {
  if pattern.length() == 0 {
    return Some(start)
  }
  if start < 0 || text.length() - start < pattern.length() {
    return None
  }
  for i in start..<(text.length() - pattern.length() + 1) {
    let mut matches = true
    for j in 0..<pattern.length() {
      if text.code_unit_at(i + j) != pattern.code_unit_at(j) {
        matches = false
        break
      }
    }
    if matches {
      return Some(i)
    }
  }
  None
}

///|
pub fn render(source : String) -> Result[LatexOutput, LatexError] {
  match latex_output_cache.get(source) {
    Some(output) => return Ok(output)
    None => ()
  }
  if latex_sessions.is_empty() {
    let session = LatexSession::new() catch { e => return Err(e) }
    latex_sessions.push(session)
  }
  let session = latex_sessions[0]
  let source_literal = Json::string(source).stringify(escape_slash=false)
  let value = latex_run_source(
    session.interp,
    "render",
    "adaptor.innerHTML(html.convert(\{source_literal}, { em: 16, ex: 8 }))",
  ) catch {
    e => return Err(e)
  }
  let svg = value.to_string()
  guard parse_ex_dimension(svg, "width") is Some(width_ex) &&
    parse_ex_dimension(svg, "height") is Some(height_ex) else {
    return Err(InvalidSvg(svg))
  }
  let output = {
    svg,
    width: (width_ex * 8.0).ceil().to_int(),
    height: (height_ex * 8.0).ceil().to_int(),
  }
  latex_output_cache[source] = output
  Ok(output)
}
