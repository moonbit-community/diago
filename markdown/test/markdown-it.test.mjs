import assert from "node:assert/strict";
import test from "node:test";

import MarkdownIt from "markdown-it";

import diago from "../dist/markdown-it.js";

function namespace(svg) {
  return /class="(d2-\d+) d2-svg"/.exec(svg)?.[1];
}

test("markdown-it renders exact diago fences and delegates other info strings", () => {
  const md = new MarkdownIt().use(diago);
  const source = [
    "```diago",
    "a -> b",
    "```",
    "",
    "```d2",
    "a -> b",
    "```",
    "",
    "```Diago",
    "a -> b",
    "```",
    "",
    "```diago title=x",
    "a -> b",
    "```",
  ].join("\n");
  const output = md.render(source, { path: "docs/exact.md" });
  assert.equal((output.match(/data-d2-version=/g) ?? []).length, 1);
  assert.match(output, /class="language-d2"/);
  assert.match(output, /class="language-Diago"/);
  assert.match(output, /class="language-diago"/);
});

test("markdown-it keeps failed fences and records diagnostics after partial success", () => {
  const seen = [];
  const md = new MarkdownIt().use(diago, {
    onDiagnostic: (diagnostic) => seen.push(diagnostic),
  });
  const env = { path: "docs/partial.md" };
  const output = md.render(
    "```diago\na -> b\n```\n\n```diago\na ->\n```\n\n```diago\nc -> d\n```",
    env,
  );
  assert.equal((output.match(/data-d2-version=/g) ?? []).length, 2);
  assert.match(output, /<code class="language-diago">a -&gt;/);
  assert.equal(env.diagoDiagnostics.length, 1);
  assert.strictEqual(seen[0], env.diagoDiagnostics[0]);
  assert.equal(seen[0].code, "DIAGO_PARSE");
  assert.equal(seen[0].range.start.line, 5);
  assert.equal(seen[0].documentId, "docs/partial.md");
});

test("markdown-it supports nested CommonMark containers", () => {
  const md = new MarkdownIt().use(diago);
  const source = [
    "> 1. outer",
    ">    - inner",
    ">",
    ">      ```diago",
    ">      a -> b",
    ">      ```",
  ].join("\n");
  const output = md.render(source, { path: "docs/nested.md" });
  assert.match(output, /<blockquote>/);
  assert.match(output, /<ol>/);
  assert.match(output, /<ul>/);
  assert.match(output, /<svg /);
});

test("namespaces are stable across unrelated fences and unique for repeats", () => {
  const md = new MarkdownIt().use(diago);
  const first = md.render("```diago\na -> b\n```", { path: "docs/id.md" });
  const withOther = md.render(
    "```diago\nx -> y\n```\n\n```diago\na -> b\n```",
    { path: "docs/id.md" },
  );
  const repeated = md.render(
    "```diago\na -> b\n```\n\n```diago\na -> b\n```",
    { path: "docs/id.md" },
  );
  assert.equal(namespace(first), (withOther.match(/class="d2-\d+ d2-svg"/g) ?? [])[1]?.match(/d2-\d+/)?.[0]);
  const repeatIds = [...repeated.matchAll(/class="(d2-\d+) d2-svg"/g)].map(
    (match) => match[1],
  );
  assert.equal(repeatIds.length, 2);
  assert.notEqual(repeatIds[0], repeatIds[1]);
});

test("markdown-it validates configuration and duplicate installation", () => {
  assert.throws(
    () => new MarkdownIt().use(diago, { diagram: { layout: "dot" } }),
    /diagram\.layout/,
  );
  const md = new MarkdownIt().use(diago);
  assert.throws(() => md.use(diago), /already installed/);
});

test("line endings and a structural final newline do not change namespaces", () => {
  const md = new MarkdownIt().use(diago);
  const lf = md.render("```diago\na -> b\n```\n", { path: "docs/eol.md" });
  const crlf = md.render("```diago\r\na -> b\r\n```", {
    path: "docs/eol.md",
  });
  assert.equal(namespace(lf), namespace(crlf));
});

test("diagnostics are stored before a callback aborts the host", () => {
  const sentinel = new Error("stop build");
  const env = { path: "docs/fail-fast.md" };
  const md = new MarkdownIt().use(diago, {
    onDiagnostic() {
      throw sentinel;
    },
  });
  assert.throws(() => md.render("```diago\na ->\n```", env), sentinel);
  assert.equal(env.diagoDiagnostics.length, 1);
  assert.equal(env.diagoDiagnostics[0].code, "DIAGO_PARSE");
});

test("every Wasm error name maps through the shared diagnostic model", () => {
  const names = [
    "request_length",
    "invalid_utf8",
    "invalid_json",
    "unsupported_version",
    "invalid_request",
    "parse",
    "io",
    "ir",
    "graph",
    "config",
    "layout",
    "render",
    "target",
    "result_too_large",
    "unsupported_feature",
    "unknown",
  ];
  for (const [kind, name] of names.entries()) {
    const renderer = {
      abiVersion: 1,
      transferCapacity: 1024,
      render() {
        return {
          ok: false,
          body: new TextEncoder().encode(name),
          text: name,
          error: { kind, name, requiredLength: name.length },
        };
      },
    };
    const md = new MarkdownIt().use(diago, { renderer });
    const env = { path: `docs/${name}.md` };
    md.render("```diago\na -> b\n```", env);
    assert.equal(env.diagoDiagnostics[0].code, `DIAGO_${name.toUpperCase()}`);
    assert.equal(env.diagoDiagnostics[0].wasm.name, name);
  }
});
