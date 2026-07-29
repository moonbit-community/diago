#!/bin/bash
# Build WASM and copy assets for local testing
set -e

cd "$(dirname "$0")/.."

echo "Building WASM..."
moon build cmd/wasm --target wasm --release

echo "Building CodeMirror editor..."
npm ci --prefix web
npm run build --prefix web

echo "Copying wasm.wasm..."
cp _build/wasm/release/build/cmd/wasm/wasm.wasm web/

echo "Checking WASM ABI..."
node scripts/wasm_smoke.mjs web/wasm.wasm

echo "Copying examples..."
rm -rf web/examples
mkdir -p web/examples
cp examples/*.d2 web/examples/

echo "Done! To test locally:"
echo "  cd web && python3 -m http.server 8080"
echo "  open http://localhost:8080"
