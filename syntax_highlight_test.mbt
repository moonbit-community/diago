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
test "get_syntax_tokens classifies the language lexer output" {
  let source =
    #|# comment
    #|vars: {
    #|  enabled: true
    #|  count: 42
    #|}
    #|client -> server
    #|
  let tokens = get_syntax_tokens(source)
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  { start: 0, end: 9, kind: Comment },
      #|  { start: 10, end: 14, kind: Keyword },
      #|  { start: 14, end: 15, kind: Punctuation },
      #|  { start: 16, end: 17, kind: Punctuation },
      #|  { start: 20, end: 27, kind: Identifier },
      #|  { start: 27, end: 28, kind: Punctuation },
      #|  { start: 29, end: 33, kind: Boolean },
      #|  { start: 36, end: 41, kind: Identifier },
      #|  { start: 41, end: 42, kind: Punctuation },
      #|  { start: 43, end: 45, kind: Number },
      #|  { start: 46, end: 47, kind: Punctuation },
      #|  { start: 48, end: 54, kind: Identifier },
      #|  { start: 55, end: 57, kind: Operator },
      #|  { start: 58, end: 64, kind: Identifier },
      #|]
    ),
  )
}

///|
test "get_syntax_tokens keeps block strings whole when source is incomplete" {
  let source =
    #|note: |md
    #|  **still editing
  let tokens = get_syntax_tokens(source)
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  { start: 0, end: 4, kind: Identifier },
      #|  { start: 4, end: 5, kind: Punctuation },
      #|  { start: 6, end: 27, kind: String },
      #|]
    ),
  )
}

///|
test "get_syntax_tokens offsets count Unicode code points" {
  let tokens = get_syntax_tokens("\"🌙\": true")
  debug_inspect(
    tokens,
    content=(
      #|[
      #|  { start: 0, end: 3, kind: String },
      #|  { start: 3, end: 4, kind: Punctuation },
      #|  { start: 5, end: 9, kind: Boolean },
      #|]
    ),
  )
}
