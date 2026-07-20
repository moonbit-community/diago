import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import test from "node:test";
import { pathToFileURL } from "node:url";

import MarkdownIt from "markdown-it";

import diago from "../dist/vitepress.js";

test("VitePress config hook installs Diago and reports errors", () => {
  const errors = [];
  const original = console.error;
  console.error = (message) => errors.push(message);
  try {
    const md = new MarkdownIt();
    diago()(md);
    const env = { relativePath: "guide/example.md" };
    const output = md.render("```diago\na ->\n```", env);
    assert.match(output, /<code class="language-diago">/);
    assert.equal(env.diagoDiagnostics.length, 1);
    assert.equal(errors.length, 1);
    assert.match(
      errors[0],
      /^guide\/example\.md:1:1 error \[DIAGO_PARSE\]/,
    );
  } finally {
    console.error = original;
  }
});

test("VitePress forwards a caller diagnostic callback", () => {
  const seen = [];
  const md = new MarkdownIt();
  diago({ onDiagnostic: (diagnostic) => seen.push(diagnostic) })(md);
  md.render("```diago\nx: @missing\n```", {
    relativePath: "guide/import.md",
  });
  assert.equal(seen.length, 1);
  assert.equal(seen[0].code, "DIAGO_IR");
});

test("VitePress builds a page with inline Diago SVG", async () => {
  const root = await mkdtemp(resolve("test/.tmp-vitepress-"));
  try {
    await mkdir(resolve(root, ".vitepress"));
    await writeFile(
      resolve(root, ".vitepress/config.mjs"),
      [
        `import diago from ${JSON.stringify(pathToFileURL(resolve("dist/vitepress.js")).href)}`,
        "export default { markdown: { config: diago() } }",
      ].join("\n"),
    );
    await writeFile(resolve(root, "index.md"), "```diago\na -> b\n```\n");
    const binary = resolve("node_modules/.bin/vitepress");
    const result = spawnSync(binary, ["build", root], {
      encoding: "utf8",
      maxBuffer: 16 * 1024 * 1024,
    });
    assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
    const html = await readFile(
      resolve(root, ".vitepress/dist/index.html"),
      "utf8",
    );
    assert.match(html, /data-d2-version="0\.2\.5"/);
    assert.doesNotMatch(html, /language-diago/);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
