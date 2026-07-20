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

export interface RawRenderer {
  readonly abiVersion: number
  readonly transferCapacity: number
  render(request: object): RawWasmResult
}

export function createDiagoWasm(wasm: WebAssembly.Instance | WebAssembly.Exports): RawRenderer
export function instantiateDiagoWasm(
  source: WebAssembly.Module | BufferSource,
  imports?: WebAssembly.Imports,
): Promise<RawRenderer>
