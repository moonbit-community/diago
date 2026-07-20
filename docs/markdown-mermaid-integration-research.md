# How Mermaid Integrates with Markdown

## Question

Does Mermaid implement Markdown support by replacing fenced `mermaid` blocks
with inline SVG while leaving the rest of the Markdown source unchanged?

## Short answer

No. Mermaid does not have one universal Markdown-to-inline-SVG pipeline.
Its official components use different integration boundaries:

| Component | Input boundary | Output/integration behavior |
| --- | --- | --- |
| Mermaid core API | One Mermaid diagram definition | Returns SVG code; the caller decides where to put it. |
| Mermaid browser runtime | Existing HTML elements, normally `.mermaid` | Finds those DOM nodes and replaces each node's contents with SVG at runtime. |
| Mermaid documentation's Markdown integration | A Markdown parser's fenced-code renderer hook | Produces an HTML placeholder such as `<pre class="mermaid">...</pre>`; the browser runtime renders it later. |
| VitePress | Markdown-It, configurable through VitePress's Markdown hook | A plugin can intercept fence tokens during Markdown-to-HTML compilation; Mermaid support is an integration, not a Mermaid-core source rewrite. |
| Official Mermaid CLI | A Markdown file containing `mermaid` fences | Writes separate SVG files and replaces the fences with Markdown image references. It does not inline the SVG. |
| GitHub | A `mermaid` fenced code block understood by GitHub | GitHub documents the syntax and rendered result, but its public documentation does not describe this as a source-to-source Mermaid-core transformation. |

## Evidence

### Mermaid core renders diagrams, not Markdown documents

The official API documentation defines the central operation as passing a graph
definition string to `mermaid.render`, receiving SVG code, and leaving placement
of that SVG to the site integrator. Its example explicitly assigns the returned
SVG to `element.innerHTML`.

Sources:

- [Mermaid usage documentation: API usage](https://github.com/mermaid-js/mermaid/blob/f0ffb41c1ee1ff667b528e86c3b082249726eeef/docs/config/usage.md#L230-L250)
- [Mermaid interface documentation: `render`](https://mermaid.js.org/config/setup/mermaid/interfaces/Mermaid.html#render)

This means fenced-block recognition is outside the Mermaid core renderer.

### The default browser integration mutates the DOM at runtime

The official documentation says `mermaid.run` renders elements with the
`.mermaid` class. The implementation queries those elements, reads their HTML as
the diagram definition, calls the renderer, assigns the result back to
`element.innerHTML`, and marks the element as processed.

Sources:

- [Mermaid usage documentation: `mermaid.run`](https://github.com/mermaid-js/mermaid/blob/f0ffb41c1ee1ff667b528e86c3b082249726eeef/docs/config/usage.md#L160-L197)
- [Mermaid `run` implementation](https://github.com/mermaid-js/mermaid/blob/f0ffb41c1ee1ff667b528e86c3b082249726eeef/packages/mermaid/src/mermaid.ts#L144-L202)

This route starts from HTML/DOM nodes, not the original Markdown source.

### Mermaid's documented Markdown-parser integration uses a renderer hook

The official usage guide shows a Marked code-block renderer. It converts a
recognized diagram block into `<pre class="mermaid">...</pre>` while Marked is
converting the whole document from Markdown to HTML. The SVG is generated later
by the browser integration.

Source:

- [Mermaid usage documentation: Marked renderer example](https://github.com/mermaid-js/mermaid/blob/f0ffb41c1ee1ff667b528e86c3b082249726eeef/docs/config/usage.md#L298-L330)

This is a Markdown parser hook, but it is not a Mermaid-core AST API and it does
not return Markdown containing inline SVG.

### VitePress exposes the Markdown parser, so its natural seam is the fence rule

VitePress documents that it uses Markdown-It and lets a site configure that
parser through the `markdown` site option. Its current type declaration exposes
asynchronous `preConfig` and `config` hooks receiving a `MarkdownItAsync`
instance. A Diago integration can therefore recognize `diago` fence tokens and
return the rendered SVG while VitePress is compiling Markdown to HTML. It does
not need to rewrite the Markdown source first, and this route can await Diago's
asynchronous rendering API.

Sources:

- [VitePress site configuration: Markdown](https://vitepress.dev/reference/site-config#markdown)
- [VitePress `MarkdownOptions` hooks](https://github.com/vuejs/vitepress/blob/c39a85a2ac88dca978d6a7b07fac3353fe0ae7fe/src/node/markdown/markdown.ts#L50-L68)

VitePress does not provide the cross-ecosystem contract, however. This hook is
specific to a Markdown-to-HTML host, so it should be a thin adapter over Diago's
renderer rather than the only form of the proposed general converter.

### The official CLI performs source-to-source Markdown conversion, but emits assets

The official Mermaid CLI is the closest precedent for a general Markdown
converter. Its documentation says it creates SVG files and refers to them from
the output Markdown. The example replaces each fenced block with syntax such as
`![diagram](./readme-1.svg)`.

Source:

- [Mermaid CLI README: transform a Markdown file](https://github.com/mermaid-js/mermaid-cli/blob/c07b5204d43bc54adb2203b02149439a069a9a6d/README.md#L62-L111)

The current implementation finds fences with a regular expression, renders and
writes one image per block, then replaces the matching source ranges with
Markdown image references. It even contains a TODO asking whether it should use
a Markdown parser such as Remark instead of its own recognizer.

Source:

- [Mermaid CLI Markdown transformation implementation](https://github.com/mermaid-js/mermaid-cli/blob/c07b5204d43bc54adb2203b02149439a069a9a6d/src/index.js#L745-L858)

Therefore the official CLI is source-to-source, but not inline-SVG.

### Platform support is owned by the platform

GitHub documents `mermaid` as a fenced-code language that it renders in issues,
pull requests, wikis, and Markdown files. That establishes the author-facing
syntax, but not a Mermaid-core Markdown transformation contract.

Source:

- [GitHub Docs: creating Mermaid diagrams](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams#creating-mermaid-diagrams)

Mermaid's own integrations page also classifies Markdown-It, Remark, Rehype,
VitePress, and similar adapters as ecosystem integrations rather than the core
renderer.

Source:

- [Mermaid integrations](https://mermaid.js.org/ecosystem/integrations-community.html)

## Implication for Diago

Returning Markdown with inline SVG is a valid static preprocessing model, but
it should not be presented as "the Mermaid model." The Mermaid precedent helps
separate three implementation responsibilities:

1. Recognize `diago` fenced blocks in a Markdown document.
2. Render each extracted D2 definition to SVG through Diago's existing renderer.
3. Replace each successful fence with inline SVG while preserving failed fences.

This Diago effort deliberately supports only inline SVG. External assets,
browser-time placeholders, and a public pluggable embedding policy are out of
scope even though Mermaid integrations demonstrate those alternatives.

## Nested fences in conventional Markdown plugins

Yes: a parser-integrated plugin normally handles every valid fenced code block,
including blocks inside block quotes and list items. CommonMark defines block
quotes and list items as recursive container blocks whose contents may include
other blocks. Markdown-it consequently emits the same `fence` token for a
recognized fence regardless of its container, and its renderer dispatches every
such token through the `fence` render rule. Mermaid's own VitePress documentation
uses exactly this hook: it replaces `md.renderer.rules.fence`, recognizes a
Mermaid info string, and delegates all other fences to the previous renderer.

Sources:

- [CommonMark: container blocks and block quotes](https://spec.commonmark.org/current/#container-blocks)
- [Markdown-it fence parser](https://github.com/markdown-it/markdown-it/blob/master/lib/rules_block/fence.mjs)
- [Markdown-it fence renderer](https://github.com/markdown-it/markdown-it/blob/master/lib/renderer.mjs)
- [Mermaid's VitePress fence hook](https://github.com/mermaid-js/mermaid/blob/develop/packages/mermaid/src/docs/.vitepress/mermaid-markdown-all.ts)
- [Mermaid's VitePress Markdown configuration](https://github.com/mermaid-js/mermaid/blob/develop/packages/mermaid/src/docs/.vitepress/config.ts)

Remark/unified has the same natural behavior at the AST level. MDAST represents
a fenced block as a `code` flow node; both `blockquote` and `listItem` are parent
nodes whose children accept flow content. A normal `unist-util-visit` traversal
therefore reaches matching `code` nodes at any supported nesting depth.

Sources:

- [MDAST node and content model](https://github.com/syntax-tree/mdast#nodes)
- [`unist-util-visit`](https://github.com/syntax-tree/unist-util-visit#use)
- [Remark's plugin and AST model](https://github.com/remarkjs/remark#syntax-tree)

A regex source preprocessor does not get this behavior for free. It must
reimplement CommonMark's container-prefix and indentation rules, and replacing a
quoted or list-indented fence with unprefixed SVG can move the result outside
its original container. Mermaid CLI is an example of this tradeoff: its current
Markdown converter uses a regular expression and contains a TODO considering a
Markdown parser such as Remark instead. Diago therefore chooses parser-native
fence tokens/nodes rather than a source-to-source rewrite: supporting valid
nested `diago` fences is the conventional expectation, while the host parser
retains the original container context.

Source:

- [Mermaid CLI Markdown transformation](https://github.com/mermaid-js/mermaid-cli/blob/c07b5204d43bc54adb2203b02149439a069a9a6d/src/index.js#L745-L858)
