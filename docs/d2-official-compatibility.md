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
| Dagre | 186 | 1 | 0 |
| ELK | 186 | 1 | 0 |
| Railway | 186 | 1 | 0 |
| Total | 558 | 3 | 0 |

All three engines fail on exactly the same input with the same diagnostic.
The failure occurs during parsing, before layout engine dispatch. There are no
additional engine-specific failures in this corpus.

## Failure classification

The remaining failing input belongs to one compatibility category.

| Category | Files | Stage | Root cause |
| --- | ---: | --- | --- |
| Grid coordinate keys | 1 | Parser | Commas terminate normal key paths, so D2 grid coordinates such as `0,0` are not yet recognized as grid cell identifiers. |

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

### Remaining failure fixtures

- `static/d2/grid-connections.d2`: grid coordinate keys;

## Follow-up issues

- [#18: Support D2 bracket-list syntax](https://github.com/moonbit-community/diago/issues/18) (resolved)
- [#19: Support icon and link properties on D2 edges](https://github.com/moonbit-community/diago/issues/19) (resolved)
- [#20: Support indexed edge overrides in scenarios](https://github.com/moonbit-community/diago/issues/20) (resolved)
- [#21: Support D2 grid coordinate keys](https://github.com/moonbit-community/diago/issues/21)

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
