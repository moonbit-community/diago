import assert from "node:assert/strict";
import test from "node:test";

import {
  createRenderer,
  getDefaultRenderer,
} from "../dist/index.js";

test("default renderer is shared and independent renderers reuse the ABI", async () => {
  const [first, second, independent] = await Promise.all([
    getDefaultRenderer(),
    getDefaultRenderer(),
    createRenderer(),
  ]);
  assert.strictEqual(first, second);
  assert.notStrictEqual(first, independent);
  assert.equal(first.abiVersion, 1);
  assert.equal(independent.abiVersion, 1);
  assert.ok(first.transferCapacity > 0);
});

test("renderer returns copied UTF-8 bytes and text", async () => {
  const renderer = await getDefaultRenderer();
  const result = renderer.render({
    source: "a -> b",
    output: "svg",
    layout: "dagre",
    render: { noXmlTag: true, salt: "runtime-test" },
  });
  assert.equal(result.ok, true);
  assert.match(result.text, /^<svg /);
  assert.deepEqual(new TextDecoder().decode(result.body), result.text);
  const original = result.body[0];
  result.body[0] = 0;
  const next = renderer.render({ source: "a -> b", output: "svg" });
  assert.equal(next.ok, true);
  assert.equal(next.body[0], original);
});

test("renderer preserves structured error metadata", async () => {
  const renderer = await getDefaultRenderer();
  const result = renderer.render({ source: "a ->", output: "svg" });
  assert.equal(result.ok, false);
  assert.equal(result.error.name, "parse");
  assert.equal(result.error.kind, 10);
  assert.equal(result.error.requiredLength, result.body.length);
  assert.match(result.text, /edge requires a destination/);
});
