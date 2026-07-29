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
/// A lexical category used by source editors.
pub(all) enum SyntaxTokenKind {
  Comment
  String
  Number
  Boolean
  Keyword
  Identifier
  Operator
  Punctuation
} derive(Eq, Debug)

///|
/// A highlighted source range.
///
/// `start` and `end` are zero-based Unicode code point offsets. The range is
/// half-open: it includes `start` and excludes `end`.
pub struct SyntaxToken {
  start : Int
  end : Int
  kind : SyntaxTokenKind
} derive(Eq, Debug)

///|
priv struct BlockStringSpan {
  start : Int
  end : Int
}

///|
/// Tokenize Diago source for syntax highlighting.
///
/// The result is available even when the source is incomplete or contains
/// syntax errors.
pub fn get_syntax_tokens(source : String) -> Array[SyntaxToken] {
  let (lexer_tokens, _) = @lexer.tokenize(source)
  let block_strings = find_block_string_spans(source, lexer_tokens)
  let highlighted : Array[SyntaxToken] = []
  let mut block_index = 0
  for token in lexer_tokens {
    while block_index < block_strings.length() &&
          token.range.start.offset >= block_strings[block_index].end {
      block_index += 1
    }
    if block_index < block_strings.length() {
      let block = block_strings[block_index]
      if token.range.start.offset >= block.start {
        if token.range.start.offset == block.start {
          highlighted.push({ start: block.start, end: block.end, kind: String })
        }
        if token.range.start.offset < block.end {
          continue
        }
      }
    }
    match syntax_kind_for_lexer_token(token.kind) {
      Some(kind) =>
        highlighted.push({
          start: token.range.start.offset,
          end: token.range.end.offset,
          kind,
        })
      None => ()
    }
  }
  highlighted
}

///|
fn syntax_kind_for_lexer_token(kind : @lexer.TokenKind) -> SyntaxTokenKind? {
  match kind {
    Comment(_) | BlockComment(_) => Some(Comment)
    StringLit(_, _) => Some(String)
    Number(_) => Some(Number)
    Ident(value) =>
      if value == "true" || value == "false" || value == "null" {
        Some(Boolean)
      } else if @ast.is_reserved_keyword(value) {
        Some(Keyword)
      } else {
        Some(Identifier)
      }
    Arrow
    | ReverseArrow
    | BidirectionalArrow
    | DoubleDash
    | At
    | DotDotDot
    | Dollar
    | DollarBrace
    | Star
    | DoubleStar
    | TripleStar
    | Ampersand => Some(Operator)
    Colon
    | Semicolon
    | Dot
    | Comma
    | LeftBrace
    | RightBrace
    | LeftBracket
    | RightBracket
    | LeftParen
    | RightParen
    | Pipe => Some(Punctuation)
    Newline | Eof => None
  }
}

///|
fn find_block_string_spans(
  source : String,
  tokens : Array[@lexer.Token],
) -> Array[BlockStringSpan] {
  let chars = source.to_array()
  let spans : Array[BlockStringSpan] = []
  let mut previous : @lexer.TokenKind? = None
  let mut covered_until = 0
  for token in tokens {
    let token_start = token.range.start.offset
    if token_start < covered_until {
      continue
    }
    match token.kind {
      Newline => previous = None
      Eof => ()
      Pipe =>
        if previous is Some(Colon) {
          let span = scan_block_string_span(chars, token_start)
          spans.push(span)
          covered_until = span.end
          previous = None
        } else {
          previous = Some(token.kind)
        }
      _ => previous = Some(token.kind)
    }
  }
  spans
}

///|
fn scan_block_string_span(chars : Array[Char], start : Int) -> BlockStringSpan {
  let mut cursor = start + 1
  let quote = StringBuilder::new()
  while cursor < chars.length() {
    let char = chars[cursor]
    if is_block_string_tag_char_for_highlight(char) ||
      is_block_string_space_for_highlight(char) {
      break
    }
    quote.write_char(char)
    cursor += 1
  }
  while cursor < chars.length() &&
        !is_block_string_space_for_highlight(chars[cursor]) {
    cursor += 1
  }
  while cursor < chars.length() {
    let char = chars[cursor]
    if !is_block_string_space_for_highlight(char) {
      break
    }
    cursor += 1
    if char == '\n' {
      break
    }
  }
  let marker = (quote.to_string() + "|").to_array()
  let mut close_start = -1
  let mut candidate = cursor
  while candidate + marker.length() <= chars.length() {
    if chars_start_with(chars, candidate, marker) {
      close_start = candidate
      break
    }
    candidate += 1
  }
  let end = if close_start < 0 {
    chars.length()
  } else {
    close_start + marker.length()
  }
  { start, end }
}

///|
fn is_block_string_tag_char_for_highlight(char : Char) -> Bool {
  (char >= 'a' && char <= 'z') ||
  (char >= 'A' && char <= 'Z') ||
  (char >= '0' && char <= '9') ||
  char == '_'
}

///|
fn is_block_string_space_for_highlight(char : Char) -> Bool {
  char == ' ' || char == '\t' || char == '\r' || char == '\n'
}

///|
fn chars_start_with(
  chars : Array[Char],
  start : Int,
  pattern : Array[Char],
) -> Bool {
  for index in 0..<pattern.length() {
    if chars[start + index] != pattern[index] {
      return false
    }
  }
  true
}
