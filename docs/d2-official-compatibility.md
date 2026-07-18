# D2 official documentation compatibility

This report records Diago's compatibility with the 187 official documentation
fixtures vendored from
[`terrastruct/d2-docs@f49a9c8985f346f0f38013c184dec3758b86dbc2`](https://github.com/terrastruct/d2-docs/commit/f49a9c8985f346f0f38013c184dec3758b86dbc2).

Run:

```sh
scripts/run_d2_official_compat.sh
```

## Results

Every fixture was rendered as SVG with remote asset bundling disabled. Each
successful command also had to produce a non-empty file containing an `<svg`
element.

| Engine | Passed | Expected failures | Unexpected failures |
| --- | ---: | ---: | ---: |
| Dagre | 187 | 0 | 0 |
| ELK | 187 | 0 | 0 |
| Railway | 187 | 0 | 0 |
| Total | 561 | 0 | 0 |

All 187 fixtures pass through all three engines. There are no remaining known
compatibility failures in this corpus.

## Normalized SVG parity

Strict normalized SVG parity against D2 0.7.1 is checked with:

```sh
python3 scripts/test_svg_parity.py
python3 scripts/check_d2_svg_parity.py --corpus all
```

The gate covers all 41 repository examples plus all 187 pinned official
fixtures on both Dagre and ELK (456 comparisons). Normalization removes only
non-visual instability: XML attribute ordering, D2 scope salts and version
metadata, embedded font payload bytes, and unused static renderer CSS. It
preserves canvas geometry, DOM/render order, hierarchy, paths, masks, markers,
links, images, labels, and active styles. Failures produce canonical SVG diffs
and a machine-readable `results.tsv` under `_build/d2-svg-parity`.

Current strict results are:

| Engine | Exact matches | Failures |
| --- | ---: | ---: |
| Dagre | 228 / 228 | 0 |
| ELK | 228 / 228 | 0 |

`moon_elk` 0.2.1 fixed the remaining layered model-order divergence from D2's
vendored elk.js. The previous five ELK fixture failures reduced to three unique
inputs: C4, classes, and animated nested containers. Those inputs now match
strictly, including node geometry and edge routes, without renderer-side
compensation in Diago.

Two failures previously attributed to `moon_elk` were Diago defects and are
now fixed. `border-label.d2` needed D2-compatible descendant edge-route shifts
when removing ELK label margins. `wcc.d2` needed all constant-near objects in
one placement group to be positioned before any of them are inserted into the
main graph.

## Failure classification

There are no command, parser, compiler, renderer, normalized SVG parity, or
known dependency failures in the covered corpus.

## Resolved bracket-list compatibility

Diago accepts both its existing comma-separated arrays and canonical D2
semicolon-separated arrays:

```d2
x: [a, b]
y: [a; b]
```

The implementation reuses the existing array AST and IR. It supports nested
arrays, trailing separators, comments, multiple classes, SQL constraints, and
variable spreads such as `[PK; ...${base-constraints}]`.

The change made 12 previously failing official fixtures pass. The remaining
`grid-connections.d2` failure was previously masked by its class arrays; after
those arrays began parsing, its separate grid coordinate-key incompatibility
became visible.

## Resolved edge icon and link compatibility

Edge maps now carry `icon` and `link` through the exporter, backend-neutral
graph model, all layout engines, render-ready diagram, JSON output, and SVG
renderer. Connection icons support D2's fixed 32-pixel size, automatic
placement beside labels, `icon.near`, and `icon.style.border-radius`.
Connection links wrap ordinary text labels using SVG anchors, matching the
official renderer.

This makes the official `static/d2/icons-1.d2` and `static/d2/links.d2`
fixtures pass through Dagre, ELK, and Railway.

## Resolved indexed edge override compatibility

Indexed edge references now resolve by semantic edge identity: scope,
endpoints, arrow directions, and the declaration index within that edge group.
Property suffixes such as `.style.opacity`, whole property maps, and edge map
updates recursively merge into the selected edge without creating duplicates.

Scenarios inherit their parent board before applying indexed updates. Steps
inherit the previous step in source order, while layers remain isolated.
Out-of-range numeric indexes report `indexed edge does not exist`.

This makes the official `static/bespoke-d2/animated.d2` fixture pass through
Dagre, ELK, and Railway.

## Resolved comma-bearing key compatibility

D2 treats commas as ordinary text in unquoted keys, including object IDs,
property paths, and edge endpoints such as `0,0 -> 2,0`. Diago now preserves
that behavior generally instead of recognizing only numeric grid coordinates.

Comma-separated arrays remain supported as a Diago extension. The parser
passes an explicit comma mode only while reading a direct array element, so the
separator behavior does not leak into nested maps, nested arrays, imports, or
substitutions.

This makes the official `static/d2/grid-connections.d2` fixture pass through
Dagre, ELK, and Railway.

## Follow-up issues

- [#18: Support D2 bracket-list syntax](https://github.com/moonbit-community/diago/issues/18) (resolved)
- [#19: Support icon and link properties on D2 edges](https://github.com/moonbit-community/diago/issues/19) (resolved)
- [#20: Support indexed edge overrides in scenarios](https://github.com/moonbit-community/diago/issues/20) (resolved)
- [#21: Support D2 grid coordinate keys](https://github.com/moonbit-community/diago/issues/21) (resolved)
- [#22: Enforce normalized SVG parity with D2 on Dagre and ELK](https://github.com/moonbit-community/diago/issues/22) (resolved)
- [`moon_elk` #12: Three layered inputs diverge from D2's elk.js](https://github.com/moonbit-community/moon_elk/issues/12) (resolved in 0.2.1)

## Regression policy

The checked-in `expected-failures.tsv` records both known failures and an
expected diagnostic fragment. The runner treats them as `xfail`.

The run fails when:

- an unlisted fixture fails;
- a known failure produces a different diagnostic category;
- a known failure starts passing.

The last case is intentionally reported as `xpass`: once compatibility
improves, the expectation and this report must be updated so the newly passing
fixture becomes part of the permanent success baseline.
