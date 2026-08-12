# Diago Markdown npm package design

Status: decision complete; ready for implementation review.

This document is the single design authority for the `diago` npm package under
`markdown/`. The package is a build-time Node.js integration that turns exact
`diago` fenced blocks into inline SVG through the existing Diago Wasm renderer.

## Product boundary

The package supports Node.js 20+ and ESM only. It provides integrations for
markdown-it, remark, and VitePress. It does not provide a browser runtime,
CommonJS build, generic Vite plugin, CLI command, source-to-source Markdown
rewriter, external SVG mode, or configurable embedding policy.

Only a fenced block whose trimmed info string is exactly lowercase `diago` is
recognized. `d2`, `Diago`, and `diago title=...` are ordinary code fences. All
diagram configuration is supplied when installing an adapter, never in the
fence info string.

On success, the host renders the SVG text returned by Diago directly, with no
wrapper element. On diagram failure, the original fence node is left in place
and the host receives a structured diagnostic. One failed fence does not stop
other fences in the same document from rendering. Wasm initialization and
invalid adapter configuration are setup failures and do throw.

The adapters operate at each Markdown parser's fence-node seam. They do not
rewrite the input Markdown string. “Preserve a failed fence” therefore means
that the original markdown-it token or remark node is delegated without
mutation; the original Markdown input remains untouched.

## Module shape

The package has one deep shared module and three thin host adapters:

```text
markdown-it adapter ─┐
remark adapter ──────┼─> fence compiler ─> Renderer ─> bundled diago.wasm
VitePress adapter ───┘
```

The fence compiler owns recognition, option normalization, deterministic
identity, Wasm request construction, result interpretation, and diagnostics.
Adapters own only host traversal, source locations, successful-node insertion,
failed-node delegation, and host-specific diagnostic storage. No adapter may
construct a Wasm request or translate a Wasm error independently.

The external seam is the npm export map. The Wasm loader, ABI glue, fence
compiler, hashing, and adapter helpers are private internal modules.

## Package identity and layout

The unscoped npm package name is `diago`. Registry lookup on 2026-07-20 found
the name unpublished. The package version always exactly matches `moon.mod` at
the release commit.

```text
markdown/
├── package.json
├── package-lock.json
├── README.md
├── LICENSE
├── src/
│   ├── index.js
│   ├── markdown-it.js
│   ├── remark.js
│   ├── vitepress.js
│   └── internal/
│       ├── wasm.js
│       ├── fence.js
│       ├── identity.js
│       ├── options.js
│       └── diagnostics.js
├── test/
└── dist/
    ├── index.js
    ├── index.d.ts
    ├── markdown-it.js
    ├── markdown-it.d.ts
    ├── remark.js
    ├── remark.d.ts
    ├── vitepress.js
    ├── vitepress.d.ts
    ├── internal/
    │   └── *.js
    └── diago.wasm
```

Source is modern ESM JavaScript with checked JSDoc. TypeScript checks the
JavaScript and generates declarations; no runtime bundler or transpiler is
used. Tests use `node:test`. The published `files` allowlist contains only
`dist`, `README.md`, and the root license copied to `markdown/LICENSE`.

The public export map contains exactly `.`, `./markdown-it`, `./remark`, and
`./vitepress`. Neither `diago.wasm` nor `internal/*` is exported.

## Root renderer interface

The root export is a Node loader around the existing Wasm ABI. It exposes two
factories and the render/result types:

```ts
export function getDefaultRenderer(): Promise<Renderer>
export function createRenderer(): Promise<Renderer>

export interface Renderer {
  readonly abiVersion: number
  readonly transferCapacity: number
  render(request: RenderRequest): RenderResult
}

export interface RenderRequest {
  source: string
  output?: 'svg' | 'ascii' | 'unicode'
  layout?: 'auto' | 'dagre' | 'elk' | 'railway'
  direction?: 'down' | 'up' | 'left' | 'right'
  target?: string | null
  render?: {
    themeName?: string | null
    darkThemeId?: number | null
    sketch?: boolean | null
    pad?: number | null
    center?: boolean | null
    themeOverrides?: Record<string, string> | null
    darkThemeOverrides?: Record<string, string> | null
    scale?: number | null
    noXmlTag?: boolean | null
    salt?: string | null
    omitVersion?: boolean | null
  }
}

export type RenderResult =
  | {
      ok: true
      body: Uint8Array
      text: string
      error: null
    }
  | {
      ok: false
      body: Uint8Array
      text: string
      error: WasmErrorMetadata
    }

export interface WasmErrorMetadata {
  kind: number
  name: WasmErrorName
  requiredLength: number
}

export type WasmErrorName =
  | 'request_length'
  | 'invalid_utf8'
  | 'invalid_json'
  | 'unsupported_version'
  | 'invalid_request'
  | 'parse'
  | 'io'
  | 'ir'
  | 'graph'
  | 'config'
  | 'layout'
  | 'render'
  | 'target'
  | 'result_too_large'
  | 'unsupported_feature'
  | 'unknown'
```

`RenderRequest` deliberately matches Wasm request version 1, except callers do
not supply the ABI request version. The result body remains a copied
`Uint8Array` of UTF-8 bytes; `text` is its decoded convenience view. Error
metadata remains structured and the human-readable message stays in `text`.

`getDefaultRenderer` returns one renderer per Node ESM realm. It memoizes both
the Wasm module promise and renderer promise, including rejection.
`createRenderer` creates an independent Wasm instance but reuses the compiled
module. It does not accept a path, URL, bytes, imports, or a foreign Wasm module;
those are private test seams and are not package compatibility promises.

The bundled binary is read with `node:fs/promises` from a URL relative to
`import.meta.url`, then compiled with `WebAssembly.compile`. It is never fetched
from `process.cwd()`, encoded into JavaScript, downloaded at install time, or
exposed as a public subpath.

## Adapter interface

Each adapter uses this shared option model, specialized only by its host
context type:

```ts
export interface DiagramOptions {
  layout?: 'auto' | 'dagre' | 'elk' | 'railway'
  direction?: 'down' | 'up' | 'left' | 'right'
  target?: string | null
  render?: {
    themeName?: string | null
    darkThemeId?: number | null
    pad?: number | null
    center?: boolean | null
    themeOverrides?: Record<string, string> | null
    darkThemeOverrides?: Record<string, string> | null
    scale?: number | null
  }
}

export interface AdapterOptions<Context> {
  renderer?: Renderer
  diagram?: DiagramOptions
  documentId?: string | ((context: Context) => string | undefined)
  onDiagnostic?: (diagnostic: DiagoDiagnostic) => void
}
```

The adapter owns `source`, `output: 'svg'`, `render.noXmlTag: true`, and
`render.salt`. Adapter users cannot override those fields. `sketch` is omitted
because Diago explicitly does not support it. `omitVersion` is not an adapter
option so emitted version metadata remains consistent across hosts.

Option shape and primitive values are validated once when the adapter is
installed. Invalid configuration throws `TypeError`. Diagram-specific compiler
or renderer failures are returned as diagnostics per fence.

Adapter modules initialize the default renderer with top-level await so the
exported plugin functions remain synchronous, as required by markdown-it fence
rendering. Supplying `renderer` uses that instance instead.

## Fence identity and SVG namespace

Every recognized fence gets a stable logical document ID and block ID.

Document ID resolution uses this order:

1. the non-empty result of the adapter's `documentId` option;
2. the host's repository-relative path (`env.relativePath` or `env.path` for
   markdown-it/VitePress, `file.path` for remark);
3. `content:` plus the SHA-256 digest of the original Markdown document.

Path separators are normalized to `/`. An absolute host path is made relative
to `process.cwd()` before hashing so checkout locations do not enter SVG IDs.
A caller-supplied ID is a logical ID and is used verbatim except for separator
normalization. It must be stable and unique among documents combined into the
same HTML page.

For each matching fence, the shared module computes:

```text
canonicalSource = normalize CRLF/CR to LF, then remove at most one final LF
sourceDigest = SHA-256(UTF-8(canonicalSource))
occurrence = zero-based index among earlier diago fences with the same digest
blockId = "diago-" + first 24 hex characters of
          SHA-256(UTF-8(documentId + NUL + sourceDigest + NUL + occurrence))
salt = "markdown:" + blockId
```

`canonicalSource` is also the source sent to Wasm. Removing one terminal line
feed accounts for the structural newline that parsers represent differently;
all other whitespace, including an intentional final blank line, is preserved.
This makes the three adapters render and namespace the same fence identically.

Changing one diagram changes only that diagram's namespace. Inserting or
editing a different diagram does not churn existing namespaces. Repeated
identical diagrams receive distinct namespaces. Reordering identical diagrams
may exchange occurrence identities, but their SVG output is identical.

The salt is passed through Diago's supported `render.salt` option before SVG
generation. The package does not rewrite SVG IDs, CSS, URL fragments, or XML
with regular expressions. The final namespace still uses Diago's D2-compatible
32-bit diagram hash; the package does not claim a stronger collision guarantee
than the renderer provides.

No rendered-SVG cache is kept in version 1. The package caches only the compiled
Wasm module and the default instance. This avoids unbounded build-process memory
and cache-key drift. Rendering is synchronous after initialization, so a
renderer instance is single-call-at-a-time without an async interleaving seam.
Worker threads receive independent ESM realms and default instances.

## Diagnostics

All diagram failures use one model:

```ts
export interface SourcePoint {
  line: number       // one-based
  column: number     // one-based
  offset?: number    // zero-based UTF-16 offset, when the host provides it
}

export interface SourceRange {
  start: SourcePoint
  end: SourcePoint   // exclusive
}

export interface DiagoDiagnostic {
  source: 'diago'
  severity: 'error'
  code: `DIAGO_${Uppercase<WasmErrorName>}`
  message: string
  documentId: string
  blockId: string
  range?: SourceRange
  wasm: WasmErrorMetadata
}
```

The range covers the whole fenced block. The current Wasm ABI does not expose a
structured inner D2 source location, and the JavaScript package must not parse
human-readable error messages to invent one. markdown-it/VitePress always
provide a line range and may omit offsets; remark normally provides its full
node position.

The shared module first records a diagnostic in the host channel and then calls
`onDiagnostic`, if supplied. A callback may throw to make a host build fail.
Without such a callback, per-fence failures remain non-throwing so other valid
diagrams are rendered. Invalid Wasm status, inconsistent lengths/metadata, or
invalid result UTF-8 is a runtime integrity failure and throws instead of being
misreported as a diagram diagnostic.

## markdown-it adapter

`diago/markdown-it` default-exports:

```ts
export default function markdownItDiago(
  md: MarkdownIt,
  options?: AdapterOptions<MarkdownItContext>,
): void
```

The plugin adds one core rule to compute document/block identities and wraps
the existing `fence` renderer. It recognizes `token.info.trim() === 'diago'`.
Non-matching and failed tokens delegate to the exact renderer that was installed
before Diago. Successful tokens return the SVG text unchanged.

Diagnostics are appended to `env.diagoDiagnostics`, creating the array when
needed. Existing entries are preserved. Installing the adapter twice on the
same markdown-it instance throws rather than stacking renderers.

Because recognition happens on parsed fence tokens, valid fences inside lists
and block quotes work at every CommonMark nesting depth without reconstructing
container prefixes.

## remark adapter

`diago/remark` default-exports a normal unified plugin:

```ts
export default function remarkDiago(
  options?: AdapterOptions<RemarkContext>,
): Transformer<Root>
```

It traverses every mdast `code` node and recognizes nodes with
`lang === 'diago'` and no non-whitespace `meta`. A successful node is replaced
at the same parent index by `{ type: 'html', value: svg }`. A failed node is not
mutated.

Diagnostics are appended to `file.data.diagoDiagnostics` and mirrored as
non-fatal VFile messages with `source: 'diago'` and the diagnostic code as the
rule ID. The structured diagnostic remains in `file.data`; the VFile message is
only the ecosystem presentation.

The adapter does not enable `allowDangerousHtml`, add `rehype-raw`, remove
`rehype-sanitize`, or modify any host HTML policy. A remark-to-HTML pipeline must
already permit raw HTML for the generated inline SVG to reach output.

## VitePress adapter

`diago/vitepress` default-exports a VitePress Markdown configuration hook:

```ts
export default function vitepressDiago(
  options?: AdapterOptions<VitePressContext>,
): MarkdownOptions['config']
```

Usage is deliberately one strategy:

```js
import { defineConfig } from 'vitepress'
import diago from 'diago/vitepress'

export default defineConfig({
  markdown: { config: diago() },
})
```

The hook installs the shared markdown-it adapter and prefers VitePress's
repository-relative page path as the document ID. Successful SVG is emitted as
a trusted `v-html` value inside `<div class="diago">`. This prevents Vue's
template compiler from rejecting the SVG's required `<style>` elements while
still producing inline SVG during development, SSR, and production builds.
This is an implementation detail of the single inline-SVG strategy, not a
browser renderer or alternate embedding mode.

Diagnostics remain available on the markdown environment. If `onDiagnostic`
is absent, this adapter also writes one concise `file:line:column error [CODE]
message` line to `console.error`; it does not set `process.exitCode` or abort
the rest of the page. Sites that require a failing build provide a callback
that throws. The adapter does not change VitePress routing, link, or sanitizer
behavior. Links inside generated SVG do not inherit VitePress link rewriting.

## Imports

File imports are explicitly unsupported inside npm Markdown fences in version
1. The package never reads a diagram-relative file, performs a network request,
or guesses a base directory. There is no JavaScript preprocessor or filesystem
resolver because the current Wasm ABI accepts only one source string and ABI
changes are outside this effort.

An importing diagram reaches the existing Wasm compiler, returns an `ir` error,
produces `DIAGO_IR`, remains as its original code fence, and does not prevent
other diagrams from rendering. The documentation must show this limitation.

Supporting imports later requires a separately reviewed Wasm request that
carries an explicit in-memory source map or resolver protocol. It must not be
added as implicit filesystem access in an adapter.

## Trust and CSP

Version 1 supports trusted project-authored Markdown only. Inline Diago SVG is
active document content. Diago Markdown labels can currently insert raw XHTML
through `foreignObject`, and diagrams may contain links, external images,
inline style, and embedded data fonts.

The package does not sanitize or rewrite SVG and must not claim that a host's
Markdown options sanitize generated output. Every setup example must state the
trusted-input requirement. Documentation must cover `style-src`, `img-src`,
and `font-src` consequences and must not recommend weakening `script-src`.
Untrusted Markdown remains out of scope until Diago itself has an explicit safe
render mode with URL and XHTML policy.

The detailed evidence is retained in the
[inline SVG trust report](https://github.com/moonbit-community/diago/blob/65dcee0b06941e28a32531fe145164a3678b43f6/docs/research-markdown-svg-trust.md).

## Compatibility and release policy

The initial compatibility contract is:

- Node.js `>=20` ESM;
- markdown-it `>=14 <16`;
- unified `>=11 <12`, tested through remark `>=15 <16`;
- VitePress `>=1 <2`.

Host packages are optional peer dependencies so installing one adapter does not
install all hosts. Runtime code has no third-party production dependency.
Development and CI pin exact versions in `package-lock.json`; the lowest and
latest releases inside each promised major range are tested before publication.

The npm and MoonBit packages use the same semantic version and release tag.
Public JavaScript interface changes follow SemVer. The bundled Wasm ABI is
private because callers cannot inject or address the binary; a matched internal
ABI change does not by itself require a JavaScript major version. An ABI
mismatch, missing export, or invalid transfer arena is a hard renderer
initialization error; inconsistent transaction metadata or result encoding is a
hard render-time integrity error.

The current release Wasm is 6,068,707 bytes. CI records its size and enforces
an 18 MiB raw ceiling (18,874,368 bytes). Raising the ceiling requires an
explicit reviewed change. The package contains exactly one Wasm file, no base64
copy, no `postinstall`, and no download step.

Publication is from GitHub Actions with npm provenance after both MoonBit and
npm gates pass. `npm pack --json` and an install of the produced tarball, not
the source directory, are the artifact acceptance boundary.

## Acceptance gates

Implementation is complete only when all of these pass:

1. `moon info && moon fmt`, `moon check --target all --deny-warn`, and
   `moon test --target all` remain green, followed by native and release Wasm
   builds and the existing Wasm smoke test.
2. JavaScript type checking, declaration generation, `node:test`, and package
   export tests pass on Node 20, 22, and 24.
3. The 171 import-free, non-sketch, non-LaTeX official D2 fixtures compile
   successfully through the packaged Wasm with Dagre, ELK, and Railway: 168
   produce SVG and three library/template fixtures intentionally produce an
   empty body.
4. Normalized Dagre and ELK SVG for those 171 fixtures matches D2 exactly. The
   adapter's deterministic salt and version metadata are normalized only by the
   same parity rules already used by this repository.
5. The 12 official import fixtures remain code fences and report `DIAGO_IR`;
   the four existing sketch/LaTeX skips remain code fences and report
   `DIAGO_UNSUPPORTED_FEATURE`.
6. All three adapters pass the same behavior table: exact language matching,
   trailing metadata rejection, uppercase rejection, multiple fences, repeated
   identical fences, partial success, CRLF input, no final newline, stable
   namespaces, and unchanged non-target fences.
7. Lists nested three levels, block quotes nested three levels, and mixed
   list/quote containers render successful SVG in place and retain failed code
   nodes in the same container.
8. Diagnostic tests cover every Wasm error kind, range conventions, host
   storage, callback ordering, callback throws, and continued rendering after a
   failure.
9. A strict-CSP browser fixture demonstrates the documented style, image, and
   font restrictions without claiming CSP makes untrusted SVG safe.
10. `npm pack --json` proves the export map, declarations, license, README, and
    exactly one Wasm file; it rejects `_build`, tests, source fixtures, and
    private entry points, and enforces the 18 MiB Wasm ceiling.
11. The produced tarball installs into clean markdown-it, remark, and VitePress
    consumer fixtures at both the lowest and latest supported host versions.
12. A real VitePress development server compiles a successful diagram without
    Vue side-effect-tag errors, and the production build retains the inline SVG.

The observed 171/12/4 corpus split was measured against the release Wasm at
commit `bcc51be`: 171 successful source-only fixtures (168 SVG and three empty
templates), 12 `ir` failures caused by imports, and the four tracked unsupported
sketch/LaTeX fixtures.

## Deliberate non-goals

- no compatibility aliases for `d2` or older plugin interfaces;
- no fence-local options;
- no source-map synthesis or parsing line numbers from error strings;
- no filesystem or network imports;
- no browser runtime, CommonJS, UMD, or generic Vite adapter;
- no external SVG files, placeholders, or embedding modes;
- no sanitizer, link rewriter, router integration, or CSP mutation;
- no rendered-output cache;
- no public Wasm path, module injection, or ABI glue;
- no sketch or LaTeX support.
