#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_meta="$repo_root/testdata/d2-official"
fixture_root="$fixture_meta/d2-docs"
result_root="${DIAGO_D2_RESULTS_DIR:-$repo_root/_build/d2-official-compat}"
expected_count=187

if (($# > 0)); then
  engines=("$@")
else
  engines=(dagre elk railway)
fi

for engine in "${engines[@]}"; do
  case "$engine" in
    dagre | elk | railway) ;;
    *)
      echo "Unknown layout engine: $engine" >&2
      exit 2
      ;;
  esac
done

inventory="$(mktemp)"
trap 'rm -f "$inventory"' EXIT

find "$fixture_root/docs" "$fixture_root/static" -type f -name '*.d2' \
  | sed "s#^$fixture_root/##" \
  | LC_ALL=C sort >"$inventory"

actual_count="$(wc -l <"$inventory" | tr -d ' ')"
if [[ "$actual_count" != "$expected_count" ]]; then
  echo "Expected $expected_count fixtures, found $actual_count." >&2
  exit 1
fi

if ! diff -u "$fixture_meta/FILES.txt" "$inventory"; then
  echo "Fixture inventory differs from FILES.txt." >&2
  exit 1
fi

if ! (cd "$fixture_root" && shasum -a 256 -c ../SHA256SUMS >/dev/null); then
  echo "Fixture checksum verification failed." >&2
  exit 1
fi

cd "$repo_root"
moon build --target native --release cmd/diago
diago="$repo_root/_build/native/release/build/cmd/diago/diago.exe"

rm -rf "$result_root"
mkdir -p "$result_root"
results="$result_root/results.tsv"
printf 'engine\toutcome\tcategory\tpath\n' >"$results"

regressions=0

for engine in "${engines[@]}"; do
  while IFS= read -r path; do
    skipped="$(
      awk -F '	' -v path="$path" '
        $1 == path {
          print $2 "\t" $3
          exit
        }
      ' "$fixture_meta/skipped.tsv"
    )"
    if [[ -n "$skipped" ]]; then
      category="${skipped%%$'\t'*}"
      printf '%s\tskip\t%s\t%s\n' "$engine" "$category" "$path" >>"$results"
      continue
    fi

    output="$result_root/$engine/output/${path%.d2}.svg"
    log="$result_root/$engine/logs/${path%.d2}.log"
    mkdir -p "${output%/*}" "${log%/*}"

    expected="$(
      awk -F '	' -v path="$path" '
        $1 == path {
          print $2 "\t" $3
          exit
        }
      ' "$fixture_meta/expected-failures.tsv"
    )"

    if "$diago" render \
      --layout "$engine" \
      --no-bundle \
      "$fixture_root/$path" \
      "$output" >"$log" 2>&1; then
      category="-"
      if [[ ! -s "$output" ]]; then
        category="template"
      elif ! grep -q '<svg' "$output"; then
        printf '%s\tunexpected_fail\tinvalid-output\t%s\n' \
          "$engine" "$path" >>"$results"
        regressions=$((regressions + 1))
        continue
      fi
      if [[ -n "$expected" ]]; then
        category="${expected%%$'\t'*}"
        printf '%s\txpass\t%s\t%s\n' "$engine" "$category" "$path" >>"$results"
        regressions=$((regressions + 1))
      else
        printf '%s\tpass\t%s\t%s\n' "$engine" "$category" "$path" >>"$results"
      fi
      continue
    fi

    if [[ -z "$expected" ]]; then
      printf '%s\tunexpected_fail\tunclassified\t%s\n' \
        "$engine" "$path" >>"$results"
      regressions=$((regressions + 1))
      continue
    fi

    category="${expected%%$'\t'*}"
    diagnostic="${expected#*$'\t'}"
    if grep -Fq "$diagnostic" "$log"; then
      printf '%s\txfail\t%s\t%s\n' \
        "$engine" "$category" "$path" >>"$results"
    else
      printf '%s\tchanged_fail\t%s\t%s\n' \
        "$engine" "$category" "$path" >>"$results"
      regressions=$((regressions + 1))
    fi
  done <"$inventory"
done

echo
echo "D2 official compatibility results"
echo "Results: $results"
for engine in "${engines[@]}"; do
  printf '%-8s' "$engine"
  awk -F '	' -v engine="$engine" '
    NR > 1 && $1 == engine {
      counts[$2] += 1
    }
    END {
      printf " pass=%d skip=%d xfail=%d xpass=%d unexpected_fail=%d changed_fail=%d\n",
        counts["pass"],
        counts["skip"],
        counts["xfail"],
        counts["xpass"],
        counts["unexpected_fail"],
        counts["changed_fail"]
    }
  ' "$results"
done

echo
echo "Expected failure categories across selected engines"
awk -F '	' '
  NR > 1 && $2 == "xfail" {
    counts[$3] += 1
  }
  END {
    for (category in counts) {
      print category "\t" counts[category]
    }
  }
' "$results" | LC_ALL=C sort

if ((regressions > 0)); then
  echo "$regressions compatibility result(s) require baseline review." >&2
  exit 1
fi
