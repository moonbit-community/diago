import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { gzipSync } from "node:zlib";

import esbuild from "../web/node_modules/esbuild/lib/main.js";
import { readBundledFonts } from "./export_font_assets.mjs";

const repository = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const manifest = await readFile(resolve(repository, "moon.mod"), "utf8");
const version = /version\s*=\s*"([^"]+)"/.exec(manifest)?.[1];
assert.ok(version);
await mkdir(resolve(repository, "_build"), { recursive: true });
const workspace = await mkdtemp(resolve(repository, "_build/slim-check-"));

function run(args) {
  const result = spawnSync("moon", args, {
    cwd: workspace,
    encoding: "utf8",
    maxBuffer: 32 * 1024 * 1024,
  });
  assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
  return result.stdout;
}

async function artifact(name, target) {
  const extension = target === "js" ? ".js" : ".wasm";
  const directory = resolve(workspace, `_build/${target}/release/build`);
  const entries = await readdir(directory, { recursive: true });
  const path = entries.find((entry) => entry.endsWith(`/${name}${extension}`));
  assert.ok(path, `${name}: missing ${target} artifact`);
  return resolve(directory, path);
}

const probes = {
  full: {
    imports: [""],
    source: `pub fn render(source : String, mode : String, engine : String) -> String {
  let output = match mode { "ascii" => @diago.OutputMode::Ascii; "unicode" => Unicode; _ => Svg }
  let layout = match engine { "elk" => @diago.LayoutEngine::Elk; "railway" => Railway; _ => Dagre }
  @diago.compile(source, options=@diago.CompileOptions::new().with_output_mode(output).with_layout_engine(layout)) catch { error => "\\{Repr(error)}" }
}`,
  },
  text_only: {
    imports: ["text"],
    source: `pub fn render(source : String, unicode : Bool) -> String {
  @text.compile(source, mode=if unicode { Unicode } else { Ascii }) catch { error => "\\{Repr(error)}" }
}`,
  },
  external_svg: {
    imports: ["compiler", "diagram", "engine_api", "engine_dagre", "renderer_svg_core", "fonts"],
    source: `pub fn render(source : String, font_base_url : String, ttf : Bytes) -> String {
  let compiled = match @compiler.compile_graph("diagram", source) { Ok(value) => value; Err(error) => return "\\{Repr(error)}" }
  let graph = @engine_api.layout_with_engine(@engine_dagre.DagreEngine::new(), compiled.graph_input(), @engine_api.LayoutConfig::new(), Down) catch { error => return "\\{Repr(error)}" }
  let fonts : @fonts.Resolver = fn(face) { if ttf.length() > 0 { Some(Ttf(ttf)) } else { Some(Url(font_base_url + face.name() + ".ttf")) } }
  @renderer_svg_core.render(@diagram.from_graph(graph, compiled.source_config()), @renderer_svg_core.SvgConfig::new(), fonts~) catch { error => "\\{Repr(error)}" }
}`,
  },
};

try {
  await writeFile(resolve(workspace, "moon.mod"),
    `name = "local/diago_size_check"\nversion = "0.0.0"\nimport { "moonbit-community/diago@${version}" }\n`);
  await writeFile(resolve(workspace, "moon.pkg"), "");
  await writeFile(resolve(workspace, "package.json"), '{"type":"module"}\n');
  run(["work", "init", repository, "."]);
  for (const [name, probe] of Object.entries(probes)) {
    await mkdir(resolve(workspace, name));
    const imports = probe.imports.map((path) =>
      `  "moonbit-community/diago${path ? `/${path}` : ""}",`).join("\n");
    await writeFile(resolve(workspace, name, "moon.pkg"),
      `import {\n${imports}\n}\nsupported_targets = "all"\noptions(link: { "js": { "exports": ["render"], "format": "esm" }, "wasm": { "exports": ["render"] } })\n`);
    await writeFile(resolve(workspace, name, "main.mbt"), `///|\n${probe.source}\n`);
  }

  const fonts = await readBundledFonts();
  const fingerprints = fonts.map(({ data }) => data.subarray(0, 256));
  const report = {};
  const renderers = {};
  for (const name of Object.keys(probes)) {
    const plan = run(["build", name, "--target", "wasm", "--release", "--dry-run"]);
    const link = plan.split("\n").find((line) => line.includes(" link-core "));
    assert.ok(link, `${name}: missing link plan`);
    if (name === "text_only") {
      assert.doesNotMatch(link, /renderer_svg|font_subset|fonts\/builtin|moonbit-community\/elk/);
    } else if (name === "external_svg") {
      assert.doesNotMatch(link, /diago\/renderer_svg[:/ ]|fonts\/builtin|moonbit-community\/elk/);
    }
    run(["build", name, "--target", "wasm", "--release", "--deny-warn"]);
    run(["build", name, "--target", "js", "--release", "--deny-warn"]);
    const wasm = await readFile(await artifact(name, "wasm"));
    const jsPath = await artifact(name, "js");
    const js = await readFile(jsPath, "utf8");
    const minified = (await esbuild.transform(js, {
      minify: true, format: "esm", target: "es2022",
    })).code;
    for (const fingerprint of fingerprints) {
      assert.equal(wasm.includes(fingerprint), name === "full", `${name}: unexpected TTF payload`);
      assert.equal(js.includes([...fingerprint].join(",")), name === "full", `${name}: unexpected JS font array`);
    }
    report[name] = {
      wasm: wasm.length,
      wasmGzip: gzipSync(wasm, { level: 9 }).length,
      js: Buffer.byteLength(js),
      jsMinified: Buffer.byteLength(minified),
      jsMinifiedGzip: gzipSync(minified, { level: 9 }).length,
    };
    renderers[name] = await import(pathToFileURL(jsPath).href);
  }

  for (const source of ["a -> b", "group: { a -> b }", "direction: right\na: Hello 世界\na -> b: Label"]) {
    for (const unicode of [false, true]) {
      assert.equal(renderers.text_only.render(source, unicode),
        renderers.full.render(source, unicode ? "unicode" : "ascii", "dagre"));
    }
    const svg = renderers.external_svg.render(source, "https://fonts.example.test/", new Uint8Array());
    assert.match(svg, /<svg /);
    assert.match(svg, /url\("https:\/\/fonts\.example\.test\//);
    assert.doesNotMatch(svg, /data:application\/font-woff/);
  }
  const regular = fonts.find(({ name }) => name === "sans-regular").data;
  assert.match(renderers.external_svg.render("a: { style.bold: false }", "", regular),
    /data:application\/font-woff;base64,/);
  for (const name of ["text_only", "external_svg"]) {
    assert.ok(report[name].wasm < report.full.wasm);
    assert.ok(report[name].jsMinified < report.full.jsMinified);
  }
  await writeFile(resolve(repository, "_build/slim-sizes.json"), `${JSON.stringify(report, null, 2)}\n`);
  console.table(report);
  console.log("Slim dependency, embedded-font, and output checks passed.");
} finally {
  await rm(workspace, { recursive: true, force: true });
}
