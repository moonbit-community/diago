import assert from "node:assert/strict";
import test from "node:test";

import { remark } from "remark";
import html from "remark-html";

import diago from "../dist/remark.js";

test("remark replaces successful nodes and preserves failed nodes", async () => {
  const file = await remark()
    .use(diago)
    .use(html, { sanitize: false })
    .process({
      value:
        "```diago\na -> b\n```\n\n```diago\na ->\n```\n\n```d2\nc -> d\n```",
      path: "docs/remark.md",
    });
  const output = String(file);
  assert.equal((output.match(/data-d2-version=/g) ?? []).length, 1);
  assert.match(output, /<code class="language-diago">a ->/);
  assert.match(output, /<code class="language-d2">c -> d/);
  assert.equal(file.data.diagoDiagnostics.length, 1);
  assert.equal(file.data.diagoDiagnostics[0].code, "DIAGO_PARSE");
  assert.equal(file.messages.length, 1);
  assert.equal(file.messages[0].source, "diago");
  assert.equal(file.messages[0].ruleId, "DIAGO_PARSE");
  assert.equal(file.messages[0].fatal, false);
});

test("remark traverses list and blockquote descendants", async () => {
  const file = await remark()
    .use(diago)
    .use(html, { sanitize: false })
    .process({
      value: "> - item\n>\n>   ```diago\n>   a -> b\n>   ```",
      path: "docs/nested.md",
    });
  assert.match(String(file), /<blockquote>[\s\S]*<ul>[\s\S]*<svg /);
});

test("remark rejects trailing metadata and accepts structural whitespace", async () => {
  const file = await remark()
    .use(diago)
    .use(html, { sanitize: false })
    .process({
      value: "```diago title=x\na -> b\n```\n\n```diago   \nc -> d\n```",
      path: "docs/meta.md",
    });
  const output = String(file);
  assert.equal((output.match(/data-d2-version=/g) ?? []).length, 1);
  assert.match(output, /language-diago/);
});
