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
/// Highlight one UTF-8 source body from the shared transfer arena.
///
/// The result body is a JSON array of code-point ranges and token kind names.
pub fn highlight(request_len : Int) -> Int {
  reset_result_state()
  let source = match read_request(request_len) {
    Ok(text) => text
    Err(failure) => return finish_error(failure.error_kind, failure.message)
  }
  finish_success(syntax_tokens_to_json(@diago.get_syntax_tokens(source)))
}

///|
fn syntax_tokens_to_json(tokens : Array[@diago.SyntaxToken]) -> String {
  let output = StringBuilder()
  output.write_char('[')
  for index, token in tokens {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"from\":")
    output.write_string(token.start.to_string())
    output.write_string(",\"to\":")
    output.write_string(token.end.to_string())
    output.write_string(",\"kind\":\"")
    output.write_string(syntax_token_kind_name(token.kind))
    output.write_string("\"}")
  }
  output.write_char(']')
  output.to_string()
}

///|
fn syntax_token_kind_name(kind : @diago.SyntaxTokenKind) -> String {
  match kind {
    Comment => "comment"
    String => "string"
    Number => "number"
    Boolean => "boolean"
    Keyword => "keyword"
    Identifier => "identifier"
    Operator => "operator"
    Punctuation => "punctuation"
  }
}
