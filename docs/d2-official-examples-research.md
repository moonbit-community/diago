# D2 Official Example Corpora for Diago Testing

Research snapshot:

- `terrastruct/d2`: commit [`2446e247b6d7d5b9395a1ae8ad1e9c2641231035`](https://github.com/terrastruct/d2/commit/2446e247b6d7d5b9395a1ae8ad1e9c2641231035)
- `terrastruct/d2-docs`: commit [`f49a9c8985f346f0f38013c184dec3758b86dbc2`](https://github.com/terrastruct/d2-docs/commit/f49a9c8985f346f0f38013c184dec3758b86dbc2)

## Conclusion

Yes. D2 has enough official material to build a substantially broader Diago compatibility and regression suite. The most useful source is not the small showcase gallery, but the language-tour fixtures in `terrastruct/d2-docs/static/d2` and the source scripts embedded in `terrastruct/d2/e2etests`.

The recommended order is:

1. Import the self-contained language-tour fixtures as feature compatibility cases.
2. Extract a curated subset of D2's stable, regression, Unicode, and ASCII end-to-end cases.
3. Use the seven layout-independent gallery diagrams as realistic smoke and stress cases.
4. Keep layout-specific expected output separate for Dagre, ELK, and Diago's Railway engine.

Do not use upstream SVG files as byte-for-byte golden output. They include D2-specific rendering, font measurement, IDs, metadata, and layout behavior. Diago should instead test parse/compile success, structured errors, graph invariants, valid output, and its own normalized snapshots.

## Available official corpora

| Corpus | Location | Approximate size at the snapshot | Best use |
| --- | --- | ---: | --- |
| Language-tour fixtures | [`d2-docs/static/d2`](https://github.com/terrastruct/d2-docs/tree/f49a9c8985f346f0f38013c184dec3758b86dbc2/static/d2) | 159 `.d2` files | Focused syntax and feature compatibility |
| Additional documentation diagrams | [`d2-docs/static/bespoke-d2`](https://github.com/terrastruct/d2-docs/tree/f49a9c8985f346f0f38013c184dec3758b86dbc2/static/bespoke-d2), [`static/blog`](https://github.com/terrastruct/d2-docs/tree/f49a9c8985f346f0f38013c184dec3758b86dbc2/static/blog), and [`docs/tour`](https://github.com/terrastruct/d2-docs/tree/f49a9c8985f346f0f38013c184dec3758b86dbc2/docs/tour) | 28 `.d2` files; 187 documentation `.d2` files in total | More complex feature and documentation cases |
| Gallery source archive | [`d2-docs/ci/examples/examples.txtar`](https://github.com/terrastruct/d2-docs/blob/f49a9c8985f346f0f38013c184dec3758b86dbc2/ci/examples/examples.txtar) | 8 unique diagrams: 7 common, 1 TALA-only | Realistic smoke, complexity, and visual review |
| Core repository examples | [`d2/docs/examples`](https://github.com/terrastruct/d2/tree/2446e247b6d7d5b9395a1ae8ad1e9c2641231035/docs/examples) | 6 `.d2` files plus Go library examples | Grids, boards, icons, and larger diagrams |
| D2 end-to-end tests | [`d2/e2etests`](https://github.com/terrastruct/d2/tree/2446e247b6d7d5b9395a1ae8ad1e9c2641231035/e2etests) | Hundreds of scripts and cases; 57 standalone `.d2` fixtures, 50 general `txtar` entries, and 14 ASCII `txtar` entries | Regression, Unicode, renderer, and layout behavior |

The official gallery describes itself as a set of single-file examples split by layout engine. It explicitly notes that this simplified gallery does not cover imports or multi-board composition. See the [gallery overview](https://d2lang.com/examples/overview/) and its [source](https://github.com/terrastruct/d2-docs/blob/f49a9c8985f346f0f38013c184dec3758b86dbc2/docs/examples/overview.md).

The gallery generator documents the canonical extraction process and filename suffixes used to select Dagre, ELK, or TALA. At this snapshot, the generated pages contain seven Dagre examples, seven ELK examples, and eight TALA examples. See [`ci/examples/README.md`](https://github.com/terrastruct/d2-docs/blob/f49a9c8985f346f0f38013c184dec3758b86dbc2/ci/examples/README.md) and [`ci/examples/examples.sh`](https://github.com/terrastruct/d2-docs/blob/f49a9c8985f346f0f38013c184dec3758b86dbc2/ci/examples/examples.sh).

The end-to-end suite is particularly valuable because D2 itself divides it into `sanity`, `stable`, `regression`, `patterns`, `todo`, `measured`, `unicode`, `root`, `themes`, general `txtar`, and ASCII `txtar` groups. The harness exercises compilation and rendering rather than merely storing attractive examples. See [`e2etests/e2e_test.go`](https://github.com/terrastruct/d2/blob/2446e247b6d7d5b9395a1ae8ad1e9c2641231035/e2etests/e2e_test.go), [`stable_test.go`](https://github.com/terrastruct/d2/blob/2446e247b6d7d5b9395a1ae8ad1e9c2641231035/e2etests/stable_test.go), and [`regression_test.go`](https://github.com/terrastruct/d2/blob/2446e247b6d7d5b9395a1ae8ad1e9c2641231035/e2etests/regression_test.go).

## Current Diago compatibility probe

Diago currently has 41 top-level `.d2` examples. Of these, 22 `play_*`
fixtures were originally synchronized from the official D2 playground syntax
snippets on 2026-02-28.

At Diago commit
[`47f599362353e0c99aa826f28c7442e62db5f937`](https://github.com/moonbit-community/diago/commit/47f599362353e0c99aa826f28c7442e62db5f937),
all 187 documentation `.d2` files from the pinned `d2-docs` snapshot were
rendered with the native CLI using Dagre and `--no-bundle`:

- 171 rendered successfully;
- 16 failed.

The 16 failures cluster into two useful compatibility groups:

- 13 files use bracket-list syntax such as `class: [base; error]`, including
  dependent import examples;
- 3 files exercise edge properties or indexed edge overrides that Diago
  currently rejects, including edge `icon`, edge `link`, and scenario-based
  indexed edge updates.

This result is a strong argument for importing the corpus as tracked
compatibility fixtures: it immediately supplies 171 passing cases and 16
focused expected failures instead of an undifferentiated backlog.

## Feature coverage

The documentation fixtures provide compact examples for:

- shapes, containers, connections, arrowheads, labels, links, and tooltips;
- styles, root styles, classes, themes, dimensions, and directions;
- variables, substitutions, globs, overrides, nulls, and suspend;
- grids, nested grids, legends, and `near`;
- Markdown, code, LaTeX, tables, SQL tables, and UML classes;
- sequence diagrams;
- imports and reusable models;
- Unicode and non-Latin text;
- C4 models and views;
- layers, scenarios, and steps.

The core end-to-end corpus adds historical bug reproductions, crashes, layout edge cases, large or slow graphs, ASCII output, text measurement, and Unicode coverage. This is more suitable for preventing regressions than copying only the public gallery.

## Caveats and filtering rules

### Layout engines and plugins

D2 bundles Dagre and ELK, while TALA is a separate binary. This is stated in the [official D2 README](https://github.com/terrastruct/d2/blob/2446e247b6d7d5b9395a1ae8ad1e9c2641231035/README.md). The gallery's `stripe-tala` case should therefore not be treated as a Diago compatibility requirement unless Diago deliberately supports the same TALA-specific behavior.

Railway has no D2 upstream oracle. The same source corpus can be run through Railway for crash resistance and Diago-owned invariants, but D2's coordinates and SVG snapshots cannot define Railway correctness.

### Remote assets and network access

Some official examples reference remote `icon:` URLs. For example, the gallery's `golang-queue` and `lambda-infra` cases contain hosted icons, while `d2/docs/examples/twitter/in.d2`, `flipt/input.d2`, and `wcc/wcc.d2` also use remote assets or links. These references are visible in the [gallery source archive](https://github.com/terrastruct/d2-docs/blob/f49a9c8985f346f0f38013c184dec3758b86dbc2/ci/examples/examples.txtar) and [core examples directory](https://github.com/terrastruct/d2/tree/2446e247b6d7d5b9395a1ae8ad1e9c2641231035/docs/examples).

Automated tests should not depend on those hosts. Either:

- preserve the URL as syntax but disable fetching;
- replace the asset with a checked-in local fixture while retaining provenance; or
- classify the case as a network-dependent manual smoke test.

### Imports and multi-file inputs

Files such as `imports-normal.d2`, `imports-classes-main.d2`, `imports-targeted.d2`, and the C4 view fixtures require companion files. They must be copied as a group and tested through an explicit virtual-file or filesystem adapter. They are not valid tests for a source-only API that intentionally performs no implicit filesystem access.

### Boards and links

Layers, scenarios, steps, and links may compile even when the selected output backend does not fully reproduce D2's navigation or multi-board rendering. Record separate expectations for parsing, compilation, board selection, and rendering rather than reducing each case to one pass/fail flag.

### Fonts, Markdown, LaTeX, and exact geometry

D2's end-to-end tests include measured text, Markdown, code, LaTeX, Unicode, SVG, and ASCII output. Exact geometry is sensitive to font metrics and renderer implementation. These cases are good semantic and robustness tests, but upstream coordinates and complete SVG text should not be Diago goldens.

### Expected failures

The upstream `todo` and some regression cases deliberately represent errors, unsupported layout features, or past crashes. Preserve the expected stage and error category. A corpus runner should distinguish:

- expected parse failure;
- expected compile/configuration failure;
- expected layout-feature rejection;
- expected successful render;
- unsupported by Diago, with a tracked reason.

Treating every upstream file as "must render successfully" would turn useful negative tests into false failures.

## Licensing and provenance

The two official repositories have different licenses:

- `terrastruct/d2` is [Mozilla Public License 2.0](https://github.com/terrastruct/d2/blob/2446e247b6d7d5b9395a1ae8ad1e9c2641231035/LICENSE.txt).
- `terrastruct/d2-docs` is [BSD 3-Clause](https://github.com/terrastruct/d2-docs/blob/f49a9c8985f346f0f38013c184dec3758b86dbc2/LICENSE.txt).

If files are vendored into Diago, retain the applicable copyright and license notices and keep each corpus's provenance clear. MPL-covered copied or modified files should remain identifiable as such rather than being silently absorbed into Apache-2.0 project files.

The gallery archive also records third-party source URLs in comments for seven of its eight examples. Those comments should be preserved. The official gallery says that publicly available sources are recorded in the first line of the D2 code; see the [gallery overview](https://github.com/terrastruct/d2-docs/blob/f49a9c8985f346f0f38013c184dec3758b86dbc2/docs/examples/overview.md).

This is a repository-integration recommendation, not legal advice.

## Recommended Diago test structure

Use a manifest rather than treating every `.d2` file identically:

```text
testdata/d2-official/
  LICENSE.d2-docs.txt
  LICENSE.d2.txt
  provenance.json
  tour/
  gallery/
  e2e/
  imports/
```

Each manifest entry should record:

- upstream repository, commit, and path;
- upstream license;
- source category;
- required companion files;
- network or local asset requirements;
- expected parser/compiler result;
- applicable engines;
- applicable output formats;
- known unsupported features;
- provenance or original-author URL.

Suggested adoption phases:

1. Start with approximately 100 self-contained, asset-free files from `d2-docs/static/d2`.
2. Add all Unicode cases and a curated set of `stable` and `regression` scripts from `d2/e2etests`.
3. Add the seven non-TALA gallery examples, localizing or disabling remote icons.
4. Add imports and boards only after the test runner can supply companion files and select targets explicitly.
5. Run every successful case through Dagre and ELK; run Railway as a Diago robustness and quality suite with Diago-owned expectations.

## Reproducible inventory commands

The approximate counts above were obtained from clean shallow checkouts at the pinned commits:

```sh
find static/d2 -type f -name '*.d2' | wc -l
find docs static -type f -name '*.d2' | wc -l
rg -c '^-- .* --$' ci/examples/examples.txtar
find docs/examples -type f -name '*.d2' | wc -l
find e2etests/testdata/files -type f -name '*.d2' | wc -l
rg -c '^-- .* --$' e2etests/txtar.txt
rg -c '^-- .* --$' e2etests/asciitxtar.txt
```

Counts will change as D2 evolves, so imports should pin an upstream commit and update deliberately.
