import assert from "node:assert/strict";
import { test } from "node:test";

import { formatRenderErrorMessage } from "../render-error.js";

test("parse errors preserve the diagnostic returned by Diago", () => {
  const diagnostic = "Parse errors: 0:4: expected } to close block";
  const message = formatRenderErrorMessage({
    text: diagnostic,
    error: { name: "parse" },
  });

  assert.equal(message, diagnostic);
});
