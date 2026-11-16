import assert from "node:assert/strict";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repository = resolve(dirname(fileURLToPath(import.meta.url)), "..");

export async function readBundledFonts() {
  const source = await readFile(resolve(repository, "fonts/builtin/embedded_ttf_fonts.mbt"), "utf8");
  const fonts = [...source.matchAll(
    /let (\w+)_ttf_bytes[^=\n]*= concat_font_chunks\(\[([\s\S]*?)\n\]\)/g,
  )].map((match) => {
    const hex = [...match[2].matchAll(/b"((?:\\x[0-9a-f]{2})*)"/g)]
      .map((chunk) => chunk[1].replaceAll("\\x", "")).join("");
    const data = Buffer.from(hex, "hex");
    assert.equal(data.readUInt32BE(0), 0x00010000);
    const name = match[1].replace("source_sans_pro_", "sans-")
      .replace("source_code_pro_", "mono-");
    return { name, data };
  });
  assert.equal(fonts.length, 7);
  return fonts;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  assert.ok(process.argv[2], "Usage: node scripts/export_font_assets.mjs OUTPUT_DIRECTORY");
  const directory = resolve(process.argv[2]);
  await mkdir(directory, { recursive: true });
  for (const { name, data } of await readBundledFonts()) {
    await writeFile(resolve(directory, `${name}.ttf`), data);
    console.log(`${name}.ttf: ${data.length} bytes`);
  }
}
