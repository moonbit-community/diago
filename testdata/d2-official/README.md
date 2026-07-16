# Official D2 documentation fixtures

This directory vendors the 187 `.d2` files used by the official D2
documentation at the following fixed revision:

- Repository: <https://github.com/terrastruct/d2-docs>
- Commit: `f49a9c8985f346f0f38013c184dec3758b86dbc2`
- License: BSD 3-Clause; see `LICENSE.d2-docs.txt`

The files are copied without modification from these upstream directories:

- `docs/tour`: 1 file
- `static/bespoke-d2`: 23 files
- `static/blog`: 4 files
- `static/d2`: 159 files

`FILES.txt` is the canonical 187-file inventory. `SHA256SUMS` records the
upstream contents so accidental fixture edits are detected.

Run the compatibility suite from the repository root:

```sh
scripts/run_d2_official_compat.sh
```

The runner builds the native CLI once, renders every fixture through Dagre,
ELK, and Railway with remote asset bundling disabled, and stores generated
outputs and logs under `_build/d2-official-compat`.

Known incompatibilities are recorded in `expected-failures.tsv`. A known
failure is reported as `xfail` and does not fail the runner. An unexpected
failure, a changed diagnostic, or a formerly failing case that starts passing
causes the runner to fail so the baseline must be reviewed deliberately.
