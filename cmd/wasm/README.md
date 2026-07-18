# Diago Wasm ABI

The wasm1 browser adapter exposes one synchronous render transaction over an
exported linear-memory transfer arena.

## Exports

- `memory`
- `abi_version() -> i32`
- `transfer_ptr() -> i32`
- `transfer_capacity() -> i32`
- `render(request_len: i32) -> i32`
- `result_len() -> i32`
- `result_error_kind() -> i32`
- `result_required_len() -> i32`

JavaScript writes a UTF-8 JSON request at `transfer_ptr`, calls `render`, then
reads the UTF-8 result body from the same address. `render` returns `0` on
success and `1` on failure.

The adapter is single-call-at-a-time and not reentrant.

## Request version 1

```json
{
  "version": 1,
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
```

`result.body` is a copied `Uint8Array` containing the UTF-8 body.
`result.text` is its decoded convenience view. Failures additionally contain
`result.error.kind`, `result.error.name`, and `result.error.requiredLength`.
