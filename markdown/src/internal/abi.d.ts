export const DIAGO_WASM_ABI_VERSION: number

export interface RawWasmError {
  kind: number
  name: string
  requiredLength: number
}

export type RawWasmResult =
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
      error: RawWasmError
    }

export interface RawSyntaxToken {
  from: number
  to: number
  kind:
    | "comment"
    | "string"
    | "number"
    | "boolean"
    | "keyword"
    | "identifier"
    | "operator"
    | "punctuation"
}

export type RawHighlightResult = RawWasmResult & {
  tokens: RawSyntaxToken[]
}

export interface RawRenderer {
  readonly abiVersion: number
  readonly transferCapacity: number
  render(request: object): RawWasmResult
  highlight(source: string): RawHighlightResult
}

export function createDiagoWasm(wasm: WebAssembly.Instance | WebAssembly.Exports): RawRenderer
export function instantiateDiagoWasm(
  source: WebAssembly.Module | BufferSource,
  imports?: WebAssembly.Imports,
): Promise<RawRenderer>
