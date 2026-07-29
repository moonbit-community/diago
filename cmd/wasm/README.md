# Diago Wasm ABI

The wasm1 browser adapter exposes synchronous render and syntax-highlighting
transactions over an exported linear-memory transfer arena.

## Exports

- `memory`
- `abi_version() -> i32`
- `transfer_ptr() -> i32`
- `transfer_capacity() -> i32`
- `render(request_len: i32) -> i32`
- `highlight(request_len: i32) -> i32`
- `result_len() -> i32`
- `result_error_kind() -> i32`
- `result_required_len() -> i32`

For rendering, JavaScript writes a UTF-8 JSON request at `transfer_ptr`, calls
`render`, then reads the UTF-8 result body from the same address.

The adapter is single-call-at-a-time and not reentrant.

## Host imports

The module requires these host functions:

- `__moonbit_time_unstable.now() -> i64`, returning the current Unix time in
  milliseconds
- `wasi_snapshot_preview1.random_get(pointer: i32, length: i32) -> i32`,
  filling the requested memory range with random bytes and returning a WASI
  errno

`web/diago-wasm.js` supplies both imports for browsers. Custom imports with the
same module and function names override its defaults.

## Render request version 2

```json
{
  "version": 2,
  "source": "a -> b",
  "output": "svg",
  "layout": "auto",
  "direction": "down",
  "target": null,
  "render": {
    "themeName": null,
    "darkThemeId": null,
    "sketch": null,
    "pad": null,
    "center": null,
    "themeOverrides": null,
    "darkThemeOverrides": null,
    "scale": null,
    "noXmlTag": null,
    "salt": null,
    "omitVersion": null
  }
}
```

Only `version` and `source` are required. Other fields use the same defaults as
the backend-independent MoonBit facade. LaTeX labels and sketch rendering are
not supported. A request that enables `render.sketch`, or source containing
`|tex`, `|latex`, `style.sketch: true`, or `vars.d2-config.sketch: true`, fails
with error kind `19`.

## Syntax highlighting

For highlighting, JavaScript writes raw UTF-8 Diago source at `transfer_ptr`
and calls `highlight`. The UTF-8 result body is a JSON array:

```json
[
  { "from": 0, "to": 4, "kind": "identifier" },
  { "from": 5, "to": 7, "kind": "operator" },
  { "from": 8, "to": 14, "kind": "identifier" }
]
```

Offsets count Unicode code points and ranges are half-open. The JavaScript
adapter converts them to UTF-16 offsets before exposing them to browser
editors. Highlighting is tolerant of incomplete and invalid source.

## Error kinds

- `0`: none
- `1`: invalid request length
- `2`: invalid UTF-8
- `3`: invalid JSON
- `4`: unsupported request version
- `5`: invalid request field
- `10`: parse error
- `11`: I/O error
- `12`: IR error
- `13`: graph error
- `14`: configuration error
- `15`: layout error
- `16`: render error
- `17`: target selection error
- `18`: result exceeds transfer capacity
- `19`: unsupported feature

On failure, the result body is the human-readable error message.
`result_required_len` reports the original encoded body size, including when
the body exceeds the transfer capacity.

## JavaScript adapter

`web/diago-wasm.js` validates the ABI and exposes the same transaction as:

```js
const diago = await instantiateDiagoWasm("./wasm.wasm");
const result = diago.render({
  source: "a -> b",
  output: "svg",
  layout: "dagre",
});

const highlighted = diago.highlight("a -> b");
```

`result.body` is a copied `Uint8Array` containing the UTF-8 body.
`result.text` is its decoded convenience view. Failures additionally contain
`result.error.kind`, `result.error.name`, and `result.error.requiredLength`.
Successful highlight results additionally contain `tokens`.
