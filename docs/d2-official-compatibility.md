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
| Dagre | 183 | 4 | 0 |
| ELK | 183 | 4 | 0 |
| Railway | 183 | 4 | 0 |
| Total executions | 549 | 12 | 0 |

All three engines fail on exactly the same four inputs with the same
diagnostics. The failures occur during parsing or graph compilation, before
layout engine dispatch. There are no additional engine-specific failures in
this corpus.

## Failure classification

The four failing inputs belong to four concrete compatibility categories.

| Category | Files | Stage | Root cause |
| --- | ---: | --- | --- |
| Grid coordinate keys | 1 | Parser | Commas terminate normal key paths, so D2 grid coordinates such as `0,0` are not yet recognized as grid cell identifiers. |
| Edge `icon` property | 1 | Graph compilation | Object icons are supported, but `icon` is rejected inside an edge map. |
| Edge `link` property | 1 | Graph compilation | Object links are supported, but `link` is rejected inside an edge map. |
| Indexed edge override | 1 | Graph compilation | Scenario updates such as `(a -> b)[0].style.opacity` are parsed as edge updates but rejected by the graph semantic layer. |

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

### Remaining failure fixtures

- `static/d2/grid-connections.d2`: grid coordinate keys;
- `static/d2/icons-1.d2`: edge `icon`;
- `static/d2/links.d2`: edge `link`;
- `static/bespoke-d2/animated.d2`: indexed edge style updates inside a
  scenario.

The last three currently produce the generic graph diagnostic
`Semantic(edge map keys must be reserved keywords)`. The identical diagnostic
does not mean they are one feature: each requires a different addition to the
edge semantic model.

## Follow-up issues

- [#18: Support D2 bracket-list syntax](https://github.com/moonbit-community/diago/issues/18) (resolved)
- [#19: Support icon and link properties on D2 edges](https://github.com/moonbit-community/diago/issues/19)
- [#20: Support indexed edge overrides in scenarios](https://github.com/moonbit-community/diago/issues/20)
- [#21: Support D2 grid coordinate keys](https://github.com/moonbit-community/diago/issues/21)

## Regression policy

The checked-in `expected-failures.tsv` records all four known failures and an
expected diagnostic fragment. The runner treats them as `xfail`.

The run fails when:

- an unlisted fixture fails;
- a known failure produces a different diagnostic category;
- a known failure starts passing.

The last case is intentionally reported as `xpass`: once compatibility
improves, the expectation and this report must be updated so the newly passing
fixture becomes part of the permanent success baseline.
