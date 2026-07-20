import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { once } from "node:events";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { createServer } from "node:net";
import { resolve } from "node:path";
import test from "node:test";
import { pathToFileURL } from "node:url";

import MarkdownIt from "markdown-it";

import diago from "../dist/vitepress.js";

async function availablePort() {
  const server = createServer();
  await new Promise((resolveListen, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolveListen);
  });
  const address = server.address();
  assert.notEqual(address, null);
  assert.equal(typeof address, "object");
  const port = address.port;
  await new Promise((resolveClose, reject) => {
    server.close((error) => error ? reject(error) : resolveClose());
  });
  return port;
}

async function requestWhenReady(url, child, output) {
  const deadline = Date.now() + 10_000;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) {
      throw new Error(`VitePress exited before serving the page:\n${output()}`);
    }
    try {
      return await fetch(url);
    } catch {
      await new Promise((resolveWait) => setTimeout(resolveWait, 50));
    }
  }
  throw new Error(`VitePress did not serve the page:\n${output()}`);
}

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

test("VitePress development server compiles inline Diago SVG", async () => {
  const root = await mkdtemp(resolve("test/.tmp-vitepress-dev-"));
  let child;
  let output = "";
  try {
    await mkdir(resolve(root, ".vitepress"));
    await writeFile(
      resolve(root, ".vitepress/config.mjs"),
      [
        `import diago from ${JSON.stringify(pathToFileURL(resolve("dist/vitepress.js")).href)}`,
        "export default { markdown: { config: diago() } }",
      ].join("\n"),
    );
    await writeFile(
      resolve(root, "index.md"),
      "```diago\na: Alice's diagram\nb\na -> b\n```\n",
    );
    const port = await availablePort();
    const binary = resolve("node_modules/.bin/vitepress");
    child = spawn(
      binary,
      [
        "dev",
        root,
        "--host",
        "127.0.0.1",
        "--port",
        String(port),
        "--strictPort",
      ],
      { stdio: ["ignore", "pipe", "pipe"] },
    );
    child.stdout.on("data", (chunk) => { output += chunk; });
    child.stderr.on("data", (chunk) => { output += chunk; });
    const response = await requestWhenReady(
      `http://127.0.0.1:${port}/index.md?import`,
      child,
      () => output,
    );
    const body = await response.text();
    assert.equal(response.status, 200, body);
    assert.doesNotMatch(body, /Tags with side effect/);
    assert.match(body, /innerHTML:/);
    assert.match(body, /data-d2-version/);
  } finally {
    if (child?.exitCode === null) {
      const exited = once(child, "exit");
      child.kill();
      await exited;
    }
    await rm(root, { recursive: true, force: true });
  }
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
    await writeFile(
      resolve(root, "index.md"),
      "```diago\na: Alice's diagram\nb\na -> b\n```\n",
    );
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
    assert.match(html, /<div class="diago"><svg /);
    assert.match(html, /data-d2-version="0\.2\.5"/);
    assert.match(html, /<style type="text\/css">/);
    assert.doesNotMatch(html, /v-html=/);
    assert.doesNotMatch(html, /language-diago/);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
