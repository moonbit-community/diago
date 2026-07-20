# diago

`diago` renders fenced Diago diagrams as inline SVG during Markdown builds. It
ships one version-matched Diago WebAssembly renderer and adapters for
markdown-it, remark, and VitePress.

The package requires Node.js 20 or newer and ESM. It recognizes only a fenced
block whose trimmed info string is exactly lowercase `diago`:

````markdown
```diago
client -> server: request
server -> database: query
```
````

## Security

Only use this package with trusted Markdown and trusted `diago` fence contents.
It inserts active inline SVG/HTML and is not a sanitizer. Diagrams may contain
raw XHTML labels, links, external images, inline style, and embedded data fonts.
The adapters do not change the host's HTML, sanitizer, link, router, or CSP
configuration.

Inline Diago SVG currently needs an inline-style-compatible `style-src` policy.
Images and fonts additionally need the origins or `data:` schemes actually used
by the diagram. Diago does not require weakening `script-src`.

## markdown-it

```js
import MarkdownIt from 'markdown-it'
import diago from 'diago/markdown-it'

const md = new MarkdownIt().use(diago, {
  diagram: { layout: 'dagre' },
})
const env = { path: 'docs/architecture.md' }
const html = md.render(markdown, env)
console.log(env.diagoDiagnostics ?? [])
```

Failed diagrams remain ordinary rendered code fences. Diagnostics are appended
to `env.diagoDiagnostics`.

## remark

```js
import { remark } from 'remark'
import html from 'remark-html'
import diago from 'diago/remark'

const file = await remark()
  .use(diago, { diagram: { layout: 'elk' } })
  .use(html, { sanitize: false })
  .process({ value: markdown, path: 'docs/architecture.md' })

console.log(String(file))
console.log(file.data.diagoDiagnostics ?? [])
```

The remark adapter produces an mdast `html` node. A downstream HTML pipeline
must already allow raw HTML; the adapter never enables it or changes a
sanitizer. Diagnostics are stored in `file.data.diagoDiagnostics` and mirrored
as non-fatal VFile messages.

## VitePress

```js
import { defineConfig } from 'vitepress'
import diago from 'diago/vitepress'

export default defineConfig({
  markdown: { config: diago() },
})
```

VitePress uses its page-relative path for stable SVG namespaces. By default,
diagram diagnostics are printed to stderr without stopping other diagrams. To
make a documentation build fail after the first diagram error, provide a
callback that throws:

```js
markdown: {
  config: diago({
    onDiagnostic(diagnostic) {
      throw new Error(`${diagnostic.code}: ${diagnostic.message}`)
    },
  }),
}
```

## Shared options

All adapters accept:

- `diagram`: `layout`, `direction`, `target`, and SVG render options
  (`themeName`, `darkThemeId`, `pad`, `center`, theme overrides, and `scale`).
- `documentId`: a stable logical string or host-context resolver used to
  namespace SVG definitions.
- `onDiagnostic`: called after the diagnostic is stored by the host adapter.
- `renderer`: an independently created renderer, mainly for isolation.

Fence-local options are deliberately unsupported. `output`, `source`, SVG
`salt`, XML declaration removal, sketch, and version metadata are owned by the
adapter.

## Direct renderer

```js
import { createRenderer } from 'diago'

const renderer = await createRenderer()
const result = renderer.render({
  source: 'a -> b',
  output: 'svg',
  layout: 'dagre',
})

if (result.ok) {
  // result.body is a copied Uint8Array containing the UTF-8 SVG.
  console.log(result.text)
} else {
  console.error(result.error, result.text)
}
```

`getDefaultRenderer()` returns the shared instance used by adapters.
`createRenderer()` creates an independent instance while reusing the compiled
bundled Wasm module.

## Unsupported imports and features

File imports inside `diago` fences are not supported. The package does not read
diagram-relative files or make network requests. An import reports `DIAGO_IR`
and leaves the code fence in place. Sketch rendering and LaTeX labels are also
unsupported and report `DIAGO_UNSUPPORTED_FEATURE`.
