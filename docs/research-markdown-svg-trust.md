# Inline SVG trust boundary for the Diago Markdown package

## Decision

The first release must treat Markdown containing `diago` fences as **trusted,
project-authored build input**. It must not claim to safely render untrusted or
user-submitted Markdown.

The package will insert Diago's SVG output directly into the host document. It
will not sanitize or rewrite that SVG in the first release: doing so without a
Diago-specific allow-list would either leave security gaps or remove features
that Diago legitimately emits (`style`, `foreignObject`, links, images, and
embedded fonts). Supporting untrusted input therefore requires a separate safe
rendering mode in Diago and is outside this package's initial trust boundary.

The adapters must document this boundary prominently and consistently. They
must also document the CSP and resource-loading consequences below. They must
not imply that markdown-it's `html: false`, remark's default handling of raw
HTML, VitePress's link handling, or a downstream HTML sanitizer automatically
applies to the generated SVG.

## Why the generated SVG is active content

CommonMark defines HTML blocks as raw HTML that is not escaped in HTML output.
An inline `<svg>` is therefore HTML content, not an inert image reference
([CommonMark, HTML blocks](https://spec.commonmark.org/current/#html-blocks)).
The browser restrictions that disable JavaScript and external loads for SVG
used as an image do **not** apply to inline SVG; MDN explicitly limits those
restrictions to image contexts
([MDN, SVG as an image](https://developer.mozilla.org/en-US/docs/Web/SVG/Guides/SVG_as_an_image#restrictions)).

Diago's normal XML serialization does escape text and attribute values, which
prevents ordinary labels, URLs, and icons from breaking out of their XML
positions ([`xml_emit/xml_emit.mbt`](../xml_emit/xml_emit.mbt#L20-L40),
[`xml_emit/xml_emit.mbt`](../xml_emit/xml_emit.mbt#L185-L227)). That is necessary
but is not sanitization: a safely quoted `href="javascript:..."`, for example,
is still an unsafe navigation target.

More importantly, a Diago Markdown label is currently rendered with
`safe=false`, inserted as raw XHTML, and placed in an SVG `foreignObject`
([`renderer_svg/svg_render.mbt`](../renderer_svg/svg_render.mbt#L4213-L4295)).
Consequently, raw HTML accepted by the Markdown-label renderer can cross into
the final page. This is the decisive reason the npm package cannot support
untrusted diagram source merely by checking the outer `<svg>` tag.

## Host integration does not restore the boundary

### markdown-it

markdown-it defaults `html` to `false` and warns that enabling HTML in source is
unsafe. It also rejects `javascript:`, `vbscript:`, `file:`, and most `data:`
URLs in Markdown links by default
([markdown-it API](https://markdown-it.github.io/markdown-it/)). However, a
renderer rule returns rendered HTML directly; that return value is not parsed
again as author Markdown. A fence adapter that returns Diago's SVG therefore
bypasses both the raw-HTML option and normal Markdown-link validation. The
adapter must not weaken or overwrite the host's global `validateLink`, but that
validator is not a sanitizer for URLs already inside Diago SVG.

### remark

The unified ecosystem intentionally distinguishes raw HTML from parsed HAST.
`remark-rehype` says raw HTML is dangerous, requires explicit handling, and
recommends `rehype-raw` followed by `rehype-sanitize` for untrusted content
([remark-rehype: HTML and Security](https://github.com/remarkjs/remark-rehype#html)).
A remark adapter that inserts a raw SVG node creates the same trust transition.
Downstream sanitization is application-owned and may remove required SVG
features unless its schema is explicitly extended; the Diago package must not
silently reconfigure or bypass an application's sanitizer.

### VitePress

VitePress uses markdown-it, but every Markdown page is subsequently compiled as
a Vue single-file component. Its official documentation allows raw HTML,
Vue directives, and even root-level `<script>` and `<style>` in Markdown
([VitePress, Using Vue in Markdown](https://vitepress.dev/guide/using-vue.html)).
This already assumes trusted documentation authors. The Diago VitePress adapter
inherits that model; it must not advertise VitePress as a sandbox for
user-controlled Markdown.

VitePress also gives ordinary external Markdown links special treatment,
including `target="_blank"` and `rel="noreferrer"`
([VitePress, Markdown Extensions: Links](https://vitepress.dev/guide/markdown.html#links)).
Links emitted inside Diago's SVG do not pass through that Markdown token rule,
so callers must not expect VitePress routing or external-link behavior to be
applied to them.

## Capabilities present in current Diago output

| Capability | Current evidence | Consequence |
| --- | --- | --- |
| Inline CSS | Diago always emits a theme `<style>` block and emits additional Markdown-label CSS ([`renderer_svg/svg_emit.mbt`](../renderer_svg/svg_emit.mbt#L626-L639), [`renderer_svg/svg_emit.mbt`](../renderer_svg/svg_emit.mbt#L2288-L2307)). It also emits `style` attributes. | A strict CSP that rejects inline styles will break rendering. |
| Raw HTML in diagram labels | Markdown labels use `safe=false`, raw insertion, and `foreignObject` ([`renderer_svg/svg_render.mbt`](../renderer_svg/svg_render.mbt#L4213-L4295)). | Untrusted label content can become active page content; generic XML escaping is not sufficient. |
| Navigable links | Object and edge links are copied into SVG `<a href>` / `xlink:href` attributes ([`renderer_svg/svg_render.mbt`](../renderer_svg/svg_render.mbt#L4355-L4383), [`renderer_svg/svg_render.mbt`](../renderer_svg/svg_render.mbt#L9991-L9997)). | Diagram authors can control navigation targets. Host Markdown link rewriting and validation do not apply. |
| External or data-backed images | Object, edge, and legend icons become SVG `<image href>` values ([`renderer_svg/svg_render.mbt`](../renderer_svg/svg_render.mbt#L5400-L5426), [`renderer_svg/svg_render.mbt`](../renderer_svg/svg_render.mbt#L9647-L9659), [`renderer_svg/legend_render.mbt`](../renderer_svg/legend_render.mbt#L250-L264)). SVG `href` is a resource URL and can fetch images ([MDN, SVG `href`](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Attribute/href)). | Rendering may make network requests or load `data:` resources according to browser policy. |
| Embedded fonts | Generated SVG CSS embeds font data through `data:` URLs (visible in committed reference SVG fixtures, for example [`examples/reference-dagre-output/arrowheads.svg`](../examples/reference-dagre-output/arrowheads.svg)). | CSP must permit the generated font source or text appearance can differ. |

Diago's current link-safety check is not a general URL scheme allow-list. It
recognizes only `http://` and `https://`, and uses that recognition to reject a
specific URL-label-plus-link combination
([`exporter/compile.mbt`](../exporter/compile.mbt#L3337-L3377)). The SVG renderer
otherwise serializes the supplied link. This check must not be documented as
protection against `javascript:`, `data:`, or other active URL schemes.

## CSP contract

The package does not set HTTP headers and must not recommend disabling CSP
globally. It must document the resource classes consumers need to account for:

- `style-src`: Diago uses both `<style>` elements and `style` attributes. CSP
  blocks both unless the policy permits them. MDN documents `'unsafe-inline'`,
  nonces, and hashes, but a nonce on `<style>` does not authorize unrelated
  style attributes
  ([MDN, `style-src`](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Content-Security-Policy/style-src)).
  With current output, the broadly compatible setting is
  `style-src 'unsafe-inline'`; sites unwilling to accept that trade-off cannot
  use exact inline Diago SVG yet.
- `img-src`: must allow each origin or scheme used by diagram icons and Markdown
  label images. Keep it narrow (`'self'` and explicitly trusted hosts); add
  `data:` only when diagrams actually require data images.
- `font-src`: must allow `data:` for Diago's embedded fonts unless a later build
  mode externalizes or removes them.
- `script-src`: should remain strict and should not include `'unsafe-inline'` on
  Diago's account. Diago does not need script for ordinary SVG output. CSP is
  defense in depth, not a substitute for the trusted-input requirement: CSP
  also controls inline event handlers and `javascript:` URLs, but weakening it
  reactivates those vectors
  ([MDN, CSP guide](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP#inline_javascript)).

## Package requirements for the first release

The npm package must:

1. State near every adapter's setup example: **Only use this plugin with
   trusted Markdown and trusted `diago` fence contents. It inserts active inline
   SVG/HTML and is not a sanitizer.**
2. Preserve each host's existing raw-HTML and sanitization configuration. It
   must not turn on markdown-it `html`, set `allowDangerousHtml`, remove
   `rehype-sanitize`, or replace `validateLink` globally.
3. Explain that Diago SVG links do not inherit markdown-it/VitePress link
   validation, router rewriting, `target`, or `rel` behavior.
4. Explain that icons and Markdown-label images can initiate browser requests;
   site owners must constrain them with authoring policy and `img-src`.
5. Publish the CSP compatibility statement above and include a strict-CSP test
   fixture that demonstrates the expected blocked styles/resources. The test is
   documentation evidence, not a promise that CSP makes untrusted input safe.
6. Keep successful diagrams byte-for-byte as produced by Diago except for the
   separate ID-namespace transformation decided elsewhere. The package must not
   ship an undocumented regex sanitizer.
7. Fail closed if a future `safe` or `sanitize` option is introduced: it must be
   backed by a parsed SVG/XHTML allow-list, explicit URL-scheme policy, tests for
   `script`, event handlers, `javascript:` URLs, external images, CSS URLs, and
   `foreignObject`, and a clearly versioned compatibility contract.

## Future condition for untrusted Markdown

Untrusted input can only enter scope after Diago exposes a safe rendering mode
that disables or safely parses Markdown-label raw HTML, validates URL schemes
for every link/image/CSS URL sink, and defines which `foreignObject` and style
features remain. The JS package can then expose that mode, but must still let
the host own its final HTML sanitizer and CSP. WebAssembly isolation is not an
HTML security boundary: the dangerous artifact here is the SVG string inserted
into the browser document, not code execution inside the build-time Wasm
instance.
