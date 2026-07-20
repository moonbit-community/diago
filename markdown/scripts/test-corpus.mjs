import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { getDefaultRenderer } from "../dist/index.js";

const markdownRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const repositoryRoot = resolve(markdownRoot, "..");
const metadataRoot = resolve(repositoryRoot, "testdata/d2-official");
const fixtureRoot = resolve(metadataRoot, "d2-docs");
const importFixtures = new Set([
  "static/bespoke-d2/imports-nested.d2",
  "static/bespoke-d2/serviceB.d2",
  "static/d2/c4-legend.d2",
  "static/d2/c4-tags2.d2",
  "static/d2/c4-tags3.d2",
  "static/d2/imports-classes-main.d2",
  "static/d2/imports-mv-access-view.d2",
  "static/d2/imports-mv-ssh-view.d2",
  "static/d2/imports-normal.d2",
  "static/d2/imports-targeted.d2",
  "static/d2/imports-template.d2",
  "static/d2/imports-vv-history.d2",
]);

/**
 * @param {string} command
 * @param {string[]} args
 * @param {import("node:child_process").SpawnSyncOptionsWithStringEncoding} [options]
 */
function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: repositoryRoot,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    ...options,
  });
  if (result.status !== 0) {
    throw new Error(
      `${command} ${args.join(" ")} failed:\n${result.stdout}\n${result.stderr}`,
    );
  }
  return result.stdout ?? "";
}

run("moon", ["build", "cmd/diago", "--target", "native", "--release"], {
  stdio: "inherit",
});
const native = resolve(
  repositoryRoot,
  "_build/native/release/build/cmd/diago/diago.exe",
);

const inventory = (await readFile(resolve(metadataRoot, "FILES.txt"), "utf8"))
  .trim()
  .split("\n");
const skipped = new Set(
  (await readFile(resolve(metadataRoot, "skipped.tsv"), "utf8"))
    .trim()
    .split("\n")
    .map((line) => line.split("\t", 1)[0]),
);
assert.equal(inventory.length, 187);
assert.equal(importFixtures.size, 12);
assert.equal(skipped.size, 4);

const renderer = await getDefaultRenderer();
for (const engine of ["dagre", "elk", "railway"]) {
  let successes = 0;
  let emptyTemplates = 0;
  let imports = 0;
  let unsupported = 0;
  for (const path of inventory) {
    const source = await readFile(resolve(fixtureRoot, path), "utf8");
    const result = renderer.render({
      source,
      output: "svg",
      layout: engine,
      render: { noXmlTag: true, salt: `markdown-corpus:${path}` },
    });
    if (skipped.has(path)) {
      assert.equal(result.ok, false, `${engine}/${path} must remain unsupported`);
      assert.equal(result.error.name, "unsupported_feature", `${engine}/${path}`);
      unsupported += 1;
    } else if (importFixtures.has(path)) {
      assert.equal(result.ok, false, `${engine}/${path} must reject imports`);
      assert.equal(result.error.name, "ir", `${engine}/${path}`);
      imports += 1;
    } else {
      assert.equal(result.ok, true, `${engine}/${path}: ${result.text}`);
      if (result.text === "") emptyTemplates += 1;
      else assert.match(result.text, /^<svg /, `${engine}/${path}`);
      if (engine !== "railway") {
        const salt = `markdown-corpus:${path}`;
        const nativeOutput = run(
          native,
          [
            "render",
            "--stdin",
            "--output",
            "-",
            "--layout",
            engine,
            "--no-bundle",
            "--no-xml-tag",
            "--salt",
            salt,
          ],
          { input: source },
        );
        assert.equal(
          nativeOutput.endsWith("\n") ? nativeOutput.slice(0, -1) : nativeOutput,
          result.text,
          `${engine}/${path} differs between native and packaged Wasm`,
        );
      }
      successes += 1;
    }
  }
  assert.deepEqual(
    { successes, emptyTemplates, imports, unsupported },
    { successes: 171, emptyTemplates: 3, imports: 12, unsupported: 4 },
  );
  console.log(
    `${engine}: success=171 (svg=168 empty-template=3) import=12 unsupported=4`,
  );
}
