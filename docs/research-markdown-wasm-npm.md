# Bundled Wasm loading and npm layout for Diago Markdown adapters

## Decision

Publish one Node.js 20+, ESM-only npm package from `markdown/`. Bundle exactly one release-built `diago.wasm` beside the JavaScript runtime, expose the runtime plus three explicit adapter subpaths, and keep the Wasm file and ABI glue private:

```text
markdown/
├── package.json
├── README.md
├── src/
│   ├── runtime.js
│   ├── markdown-it.js
│   ├── remark.js
│   └── vitepress.js
└── dist/
    ├── index.js
    ├── index.d.ts
    ├── internal/
    │   └── diago-wasm.js
    ├── markdown-it.js
    ├── markdown-it.d.ts
    ├── remark.js
    ├── remark.d.ts
    ├── vitepress.js
    ├── vitepress.d.ts
    └── diago.wasm
```

The package name is intentionally left to a separate naming decision. Its public shape should be:

```json
{
  "type": "module",
  "engines": { "node": ">=20" },
  "files": ["dist", "README.md", "LICENSE"],
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js"
    },
    "./markdown-it": {
      "types": "./dist/markdown-it.d.ts",
      "import": "./dist/markdown-it.js"
    },
    "./remark": {
      "types": "./dist/remark.d.ts",
      "import": "./dist/remark.js"
    },
    "./vitepress": {
      "types": "./dist/vitepress.d.ts",
      "import": "./dist/vitepress.js"
    }
  }
}
```

Explicit subpath exports make these four entry points the complete public surface; Node documents that `exports` supports multiple entry points and encapsulates unlisted package files. npm's `files` allowlist makes `dist/` the only payload directory rather than publishing the MoonBit repository or build intermediates. [Node package entry points](https://nodejs.org/download/release/latest-v20.x/docs/api/packages.html#package-entry-points), [npm `files`](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/#files)

Do not export `./diago.wasm` or `./internal/diago-wasm.js`. They are implementation details tied to the package's JavaScript facade and ABI. Consumers needing lower-level control should use the root runtime API, not construct paths into the package.

## Loading in Node.js

The default loader should locate the binary relative to the installed ESM module, not relative to `process.cwd()`:

```js
import { readFile } from "node:fs/promises";

const wasmUrl = new URL("./diago.wasm", import.meta.url);
const bytes = await readFile(wasmUrl);
const module = await WebAssembly.compile(bytes);
```

`import.meta.url` is the absolute URL of the current ESM module and is explicitly intended for relative resource loading; `fsPromises.readFile` accepts a `file:` URL and returns a promise containing the bytes. This remains correct after installation, symlinking, or a caller changing its working directory. [Node 20 ESM `import.meta.url`](https://nodejs.org/download/release/latest-v20.x/docs/api/esm.html#importmetaurl), [Node 20 `fsPromises.readFile`](https://nodejs.org/download/release/latest-v20.x/docs/api/fs.html#fspromisesreadfilepath-options)

Do not use `fetch(fileUrl)` in the Node entry point. Diago's current browser-oriented helper treats every string or URL as a fetch source, so passing the package's `file:` URL to it is not the Node loading path. Instead, read the bytes and pass the compiled module into the existing instantiator. The WebAssembly JS API distinguishes compiling bytes from instantiating an already compiled `WebAssembly.Module`, which lets the package compile once and create additional instances without rereading or recompiling the 16 MB payload. [WebAssembly JS API](https://webassembly.github.io/spec/js-api/#dom-webassembly-compile), [current Diago loader](https://github.com/moonbit-community/diago/blob/ea13a8cdbc69e198c209d2c7045d4025c28f0a0a/web/diago-wasm.js#L179-L204)

## Lifecycle: one default instance, explicit factories

The root entry point should expose both:

- `getDefaultRenderer(): Promise<Renderer>`: memoizes the initialization promise and returns one renderer per Node ESM realm.
- `createRenderer(options?): Promise<Renderer>`: creates an independent instance, optionally from an injected `WebAssembly.Module` for tests or isolation.

Internally, cache the bundled module promise separately from the default renderer promise. That lets independent instances reuse the one file read and compilation while retaining separate linear memories. Cache promises, not only fulfilled values, so concurrent first callers share work and receive the same rejection. A rejected default promise should stay rejected; silently retrying on every fence would repeat a costly deterministic failure. A fresh attempt with an explicitly injected module is available through `createRenderer`.

One default instance is safe for the agreed build-time use case because the current facade's `render()` transaction is synchronous: it writes the request, calls the exported render function, and copies the result before returning. There is no `await` at which two calls can interleave in the shared transfer arena. Node worker threads have separate ESM realms and therefore receive separate defaults. Callers that intentionally need isolation can use the factory. [current synchronous transaction](https://github.com/moonbit-community/diago/blob/ea13a8cdbc69e198c209d2c7045d4025c28f0a0a/web/diago-wasm.js#L117-L175)

The adapter modules should export normal ecosystem plugins, not promise-shaped renderer hooks. They can use top-level `await getDefaultRenderer()` during ESM evaluation and then export a synchronous markdown-it fence rule, a normal remark plugin, or a VitePress Markdown configurator. This matters because markdown-it renderer rules have a synchronous return value. VitePress explicitly permits top-level await and async site config, then exposes its underlying markdown-it instance through `markdown.config`. [markdown-it renderer rule contract](https://markdown-it.github.io/markdown-it/#Renderer), [VitePress async config](https://vitepress.dev/reference/site-config#config-resolution), [VitePress markdown configuration](https://vitepress.dev/guide/markdown#advanced-configuration)

The remark subpath should default-export the plugin function so it remains directly usable with `.use()`, as required by unified's plugin publication guidance. It may use the already initialized renderer synchronously while transforming the tree. [unified plugin publication guidance](https://unifiedjs.com/learn/guide/publish-plugin/)

## ABI and version checks

Keep the existing two-level versioning and make it a release gate:

1. JavaScript expects `DIAGO_WASM_ABI_VERSION = 1`.
2. The Wasm module exports `abi_version()` and receives request JSON with `version: 1`.
3. Instance creation verifies the required export set, exported memory, transfer arena bounds, and exact ABI version before returning a renderer.
4. Each render validates status and structured result metadata.

The current facade already performs all four checks, so the npm runtime should reuse that code rather than fork it. [export and ABI validation](https://github.com/moonbit-community/diago/blob/ea13a8cdbc69e198c209d2c7045d4025c28f0a0a/web/diago-wasm.js#L1-L78), [result validation](https://github.com/moonbit-community/diago/blob/ea13a8cdbc69e198c209d2c7045d4025c28f0a0a/web/diago-wasm.js#L141-L175), [MoonBit ABI definition](https://github.com/moonbit-community/diago/blob/ea13a8cdbc69e198c209d2c7045d4025c28f0a0a/cmd/wasm/abi.mbt#L16-L29)

The npm package version and MoonBit release should be produced by the same release job. ABI changes require a new ABI number and a package major-version review; ordinary renderer changes do not. Runtime hashing of the bundled Wasm is unnecessary: npm already delivers the JavaScript and binary as one immutable package version, while the semantic ABI/export checks detect the mismatch that matters.

## Handling the bundled binary

The release build at commit `ea13a8c` is 16,809,470 bytes (16.03 MiB), measured with:

```sh
moon build cmd/wasm --target wasm --release
stat -f '%z' _build/wasm/release/build/cmd/wasm/wasm.wasm
```

Accept that cost for the first package because bundling was an explicit product decision, but contain it:

- Ship one binary only, at `dist/diago.wasm`; all adapters share it through `dist/index.js`.
- Never embed it as base64 in JavaScript: that duplicates/generated text, increases decoded memory pressure, and prevents direct file reads.
- Load and compile lazily on first import of an adapter/runtime request; do not run compilation during npm installation and do not add a `postinstall` script.
- Do not add compression logic inside the package. Registry tarballs already compress package contents; runtime must ultimately supply the uncompressed Wasm bytes to `WebAssembly.compile`.
- Treat size as a release budget. CI should record raw Wasm size and fail only against an intentionally chosen ceiling, rather than promising the initial measured size forever.

## Release verification

Before publishing each version:

1. Build `cmd/wasm` once in release mode and copy that exact artifact to `markdown/dist/diago.wasm`.
2. Run the existing Wasm smoke test against that artifact.
3. Run adapter integration tests from a temporary consumer project on Node 20.
4. Run `npm pack --dry-run --json`; assert there is exactly one `.wasm`, no `_build/` or source tree, and the four documented export entry points are present. npm documents `npm pack` as creating the package tarball, making this the correct artifact boundary to inspect. [npm pack](https://docs.npmjs.com/cli/v11/commands/npm-pack)
5. Install the produced tarball into a clean temporary project and render at least one `diago` fence through markdown-it, remark, and VitePress configuration.

## Rejected alternatives

- **Caller supplies the Wasm path:** contradicts the agreed install-and-use package and reintroduces JS/Wasm version drift.
- **Use `process.cwd()` or package-manager paths:** breaks when invoked from another directory and relies on package layout outside the module's own URL.
- **One instance per fence or per document:** rereads/instantiates a large immutable renderer unnecessarily; the existing synchronous transaction does not require it.
- **Only a singleton with no factory:** makes tests, fault isolation, and future worker-oriented hosts need private imports.
- **Conditional browser export:** browser runtime support is outside the agreed Node 20 ESM scope; adding it now would create untested URL, CSP, and bundler contracts.
- **Expose the Wasm subpath:** freezes a low-level artifact location as public API and lets consumers bypass ABI validation.
