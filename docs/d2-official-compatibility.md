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
| Dagre | 171 | 16 | 0 |
| ELK | 171 | 16 | 0 |
| Railway | 171 | 16 | 0 |
| Total executions | 513 | 48 | 0 |

All three engines fail on exactly the same 16 inputs with the same
diagnostics. The failures occur during parsing, import expansion, or graph
compilation, before layout engine dispatch. There are no additional
engine-specific failures in this corpus.

## Failure classification

The 16 failing inputs reduce to two high-level compatibility gaps and five
concrete categories.

| Category | Files | Stage | Root cause |
| --- | ---: | --- | --- |
| Direct bracket-list syntax | 9 | Parser | Diago's array grammar does not accept D2 semicolon-separated lists such as `class: [base; error]`, SQL constraints, empty lists, or list spreads. |
| Imported bracket-list syntax | 4 | Import expansion | The entry file is valid by itself, but imports a file containing the unsupported bracket-list syntax. |
| Edge `icon` property | 1 | Graph compilation | Object icons are supported, but `icon` is rejected inside an edge map. |
| Edge `link` property | 1 | Graph compilation | Object links are supported, but `link` is rejected inside an edge map. |
| Indexed edge override | 1 | Graph compilation | Scenario updates such as `(a -> b)[0].style.opacity` are parsed as edge updates but rejected by the graph semantic layer. |

### Direct bracket-list syntax

- `static/bespoke-d2/c4-code.d2`
- `static/d2/c4-models.d2`
- `static/d2/globs-filter-2.d2`
- `static/d2/grid-connections.d2`
- `static/d2/imports-classes-main.d2`
- `static/d2/multiple-classes.d2`
- `static/d2/ordered-classes.d2`
- `static/d2/users-current.d2`
- `static/d2/vars-spread.d2`

This group contains several subforms:

- multiple classes: `class: [server; deployed]`;
- empty class list: `class: []`;
- SQL constraints: `constraint: [primary_key; unique]`;
- variable arrays and spreads:
  `[PK; ...${base-constraints}]`.

The extra `unexpected }` diagnostics in `grid-connections.d2` are parser
recovery cascades after the first unsupported list, not separate root causes.

### Imported bracket-list syntax

- `static/d2/c4-legend.d2` imports `c4-models.d2`;
- `static/d2/c4-tags2.d2` imports `c4-models.d2`;
- `static/d2/c4-tags3.d2` imports `c4-models.d2`;
- `static/d2/imports-vv-history.d2` imports `users-current.d2`.

These should become passing cases automatically when bracket-list parsing is
implemented; no separate import-system fix is indicated by the current logs.

### Edge properties and overrides

- `static/d2/icons-1.d2`: edge `icon`;
- `static/d2/links.d2`: edge `link`;
- `static/bespoke-d2/animated.d2`: indexed edge style updates inside a
  scenario.

All three currently produce the generic graph diagnostic
`Semantic(edge map keys must be reserved keywords)`. The identical diagnostic
does not mean they are one feature: each requires a different addition to the
edge semantic model.

## Follow-up issues

- [#18: Support D2 bracket-list syntax](https://github.com/moonbit-community/diago/issues/18)
- [#19: Support icon and link properties on D2 edges](https://github.com/moonbit-community/diago/issues/19)
- [#20: Support indexed edge overrides in scenarios](https://github.com/moonbit-community/diago/issues/20)

## Regression policy

The checked-in `expected-failures.tsv` records all 16 known failures and an
expected diagnostic fragment. The runner treats them as `xfail`.

The run fails when:

- an unlisted fixture fails;
- a known failure produces a different diagnostic category;
- a known failure starts passing.

The last case is intentionally reported as `xpass`: once compatibility
improves, the expectation and this report must be updated so the newly passing
fixture becomes part of the permanent success baseline.
