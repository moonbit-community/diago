import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

test("playground loads the bundled CodeMirror editor", async () => {
  const [html, editorBundle] = await Promise.all([
    readFile(new URL("../index.html", import.meta.url), "utf8"),
    readFile(new URL("../assets/editor.js", import.meta.url), "utf8"),
  ]);

  assert.match(html, /import \{ createSourceEditor \} from '\.\/assets\/editor\.js'/);
  assert.match(
    html,
    /import \{ formatRenderErrorMessage \} from '\.\/render-error\.js'/,
  );
  assert.match(html, /<div id="editor" class="editor-host"><\/div>/);
  assert.doesNotMatch(html, /<textarea\b/);
  assert.match(editorBundle, /createSourceEditor/);
});
