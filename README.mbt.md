# Diago

Diago is a diagram toolkit for MoonBit.
It supports a D2-compatible text format and renders diagrams through multiple layout engines.

## Overview

This repository contains:

- A backend-independent library facade (`Milky2018/diago`) for parsing, layout, and rendering
- A native filesystem adapter (`Milky2018/diago/fs`) for file loading and relative imports
- A CLI (`cmd/diago`) with explicit subcommands (`render`, `fmt`, `validate`, `layout`, `themes`, `version`)
- A WASM-based playground (`web/`) deployed via GitHub Pages
- A Node.js Markdown package (`markdown/`) for markdown-it, remark, and VitePress
- Multiple layout engines: `dagre`, `elk`, and `railway`

## Installation

```bash
moon update
moon build
```

## Quick Start

```bash
moon run cmd/diago -- render diagram.txt
```

## Library API

The root package is supported on all MoonBit targets. It accepts source text and never reads the local filesystem implicitly:

```moonbit check
///|
test {
  let ascii = @diago.compile(
    "a -> b",
    options=@diago.CompileOptions::new().with_output_mode(Ascii),
  )
  inspect(
    ascii,
    content=(
      #|+----+
      #|| a  |
      #||    |
      #|+----+
      #|   |  
      #|+----+
      #|| b  |
      #||    |
      #|+----+
      #|
    ),
  )
}
```

Imports are explicit and backend-independent through `ParseOptions::with_import_resolver`.

### Unsupported D2 features

Diago does not currently support LaTeX labels (`|tex` or `|latex`) or sketch
rendering (`style.sketch`, `vars.d2-config.sketch`, or the `sketch` render
option). These inputs return `UnsupportedFeature` instead of silently falling
back to plain text or ordinary SVG rendering. They can be reconsidered when
backend-independent community implementations are available for all MoonBit
targets.

Native applications can opt into local file access through the filesystem adapter:

```moonbit nocheck
///|
async fn main {
  let svg = @diago_fs.compile_file("diagram.d2")
}
```

`compile_file` and `parse_file` use `moonbitlang/async/fs`, resolve imports
relative to the input file, and preserve a custom resolver supplied by the
caller.

## Markdown package

The `diago` npm package renders exact lowercase `diago` fences to inline SVG at
build time. It is Node.js 20+ and ESM-only and bundles the matching Diago Wasm:

```js
import MarkdownIt from 'markdown-it'
import diago from 'diago/markdown-it'

const md = new MarkdownIt().use(diago)
const html = md.render('```diago\na -> b\n```', {
  path: 'docs/example.md',
})
```

The package also exports `diago/remark` and `diago/vitepress`. Failed diagrams
remain code fences and produce structured diagnostics. File imports, sketch,
and LaTeX are not supported in Markdown fences. Only use the adapters with
trusted project-authored Markdown: generated inline SVG is active HTML and is
not sanitized by the package. See [`markdown/README.md`](markdown/README.md) for
the complete interface and CSP notes.

## CLI

Show help:

```bash
moon run cmd/diago -- --help
```

Common usage:

```bash
# Render SVG (default output: input.svg)
moon run cmd/diago -- render diagram.txt
moon run cmd/diago -- render diagram.txt diagram.svg
moon run cmd/diago -- render diagram.txt --output diagram.svg

# Choose layout engine
moon run cmd/diago -- render --layout elk diagram.txt diagram.svg
moon run cmd/diago -- render -l dagre diagram.txt diagram.svg

# ASCII / Unicode text
moon run cmd/diago -- render --format ascii diagram.txt --output diagram.ascii.txt
moon run cmd/diago -- render --format unicode diagram.txt --output diagram.unicode.txt

# Format / validate
moon run cmd/diago -- fmt diagram.txt
moon run cmd/diago -- fmt --check diagram.txt
moon run cmd/diago -- validate diagram.txt

# Watch mode (rebuilds output on file changes)
moon run cmd/diago -- render --watch diagram.txt

# Introspection
moon run cmd/diago -- layout
moon run cmd/diago -- layout elk
moon run cmd/diago -- themes
moon run cmd/diago -- version
```

## Example

Create a file `example.txt`:

```text
server: Web Server
database: Database {
  shape: cylinder
}
cache: Cache {
  shape: oval
}

server -> database: queries
server -> cache: reads
cache -> database: fallback
```

Compile it:

```bash
moon run cmd/diago -- render example.txt example.svg
```

## Pipeline

At a high level:

```
Source → Lexer → Parser → AST → IR → Graph → Layout (dagre/elk/railway) → Render (SVG/ASCII/Unicode)
```

## Tests

```bash
moon check --target all --deny-warn
moon test --target all
moon build cmd/diago --target native --release
moon build cmd/wasm --target wasm --release
node scripts/wasm_smoke.mjs _build/wasm/release/build/cmd/wasm/wasm.wasm
npm ci --prefix markdown
npm test --prefix markdown
npm run test:corpus --prefix markdown
npm run test:package --prefix markdown
```

## License

Apache-2.0 (see `LICENSE`).
