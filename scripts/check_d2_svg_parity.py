#!/usr/bin/env python3

"""Render D2 and Diago fixtures and compare strict canonical SVG output."""

from __future__ import annotations

import argparse
import csv
import hashlib
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from svg_parity import compare_svg_files


REPO_ROOT = Path(__file__).resolve().parent.parent
OFFICIAL_META = REPO_ROOT / "testdata" / "d2-official"
OFFICIAL_ROOT = OFFICIAL_META / "d2-docs"
EXPECTED_OFFICIAL_COUNT = 187


@dataclass(frozen=True)
class Fixture:
    corpus: str
    display_path: str
    source_path: Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Compare normalized D2 and Diago SVG output without discarding "
            "visual or structural differences."
        )
    )
    parser.add_argument(
        "--engine",
        action="append",
        choices=("dagre", "elk"),
        dest="engines",
        help="Layout engine to check. Repeat to select both; defaults to both.",
    )
    parser.add_argument(
        "--corpus",
        choices=("all", "examples", "official"),
        default="all",
    )
    parser.add_argument(
        "--path",
        action="append",
        dest="paths",
        help="Only run a fixture whose repository-relative path contains this value.",
    )
    parser.add_argument(
        "--result-dir",
        type=Path,
        default=REPO_ROOT / "_build" / "d2-svg-parity",
    )
    parser.add_argument("--d2-bin", default="d2")
    parser.add_argument(
        "--diago-bin",
        type=Path,
        help="Use an existing native Diago binary instead of building one.",
    )
    parser.add_argument(
        "--release",
        action="store_true",
        help="Build the release binary instead of the faster debug binary.",
    )
    parser.add_argument(
        "--keep-successes",
        action="store_true",
        help="Keep raw SVG files for passing comparisons.",
    )
    return parser.parse_args()


def run_command(command: list[str], log_path: Path) -> bool:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("w", encoding="utf-8") as log:
        result = subprocess.run(
            command,
            cwd=REPO_ROOT,
            stdout=log,
            stderr=subprocess.STDOUT,
            check=False,
        )
    return result.returncode == 0


def build_diago(release: bool) -> Path:
    command = ["moon", "build", "--target", "native"]
    if release:
        command.append("--release")
    command.append("cmd/diago")
    subprocess.run(command, cwd=REPO_ROOT, check=True)
    binary = (
        REPO_ROOT
        / "_build"
        / "native"
        / ("release" if release else "debug")
        / "build"
        / "cmd"
        / "diago"
        / "diago.exe"
    )
    if not binary.is_file():
        raise RuntimeError(f"Diago binary was not produced at {binary}")
    return binary


def verify_official_fixtures() -> list[Fixture]:
    inventory = (OFFICIAL_META / "FILES.txt").read_text(
        encoding="utf-8"
    ).splitlines()
    if len(inventory) != EXPECTED_OFFICIAL_COUNT:
        raise RuntimeError(
            f"Expected {EXPECTED_OFFICIAL_COUNT} official fixtures, "
            f"found {len(inventory)} in FILES.txt"
        )

    actual = sorted(
        str(path.relative_to(OFFICIAL_ROOT))
        for root in ("docs", "static")
        for path in (OFFICIAL_ROOT / root).rglob("*.d2")
    )
    if inventory != actual:
        raise RuntimeError("Official fixture tree differs from FILES.txt")

    for line in (OFFICIAL_META / "SHA256SUMS").read_text(
        encoding="utf-8"
    ).splitlines():
        expected, relative_path = line.split(maxsplit=1)
        relative_path = relative_path.lstrip("*")
        content = (OFFICIAL_ROOT / relative_path).read_bytes()
        actual_digest = hashlib.sha256(content).hexdigest()
        if actual_digest != expected:
            raise RuntimeError(
                f"Checksum mismatch for official fixture {relative_path}"
            )

    return [
        Fixture("official", path, OFFICIAL_ROOT / path) for path in inventory
    ]


def collect_fixtures(corpus: str, filters: list[str]) -> list[Fixture]:
    fixtures: list[Fixture] = []
    if corpus in ("all", "examples"):
        fixtures.extend(
            Fixture("examples", str(path.relative_to(REPO_ROOT)), path)
            for path in sorted((REPO_ROOT / "examples").glob("*.d2"))
        )
    if corpus in ("all", "official"):
        fixtures.extend(verify_official_fixtures())
    if filters:
        fixtures = [
            fixture
            for fixture in fixtures
            if any(value in fixture.display_path for value in filters)
        ]
    if not fixtures:
        raise RuntimeError("No fixtures matched the requested corpus and paths")
    return fixtures


def output_base(result_dir: Path, fixture: Fixture, engine: str) -> Path:
    relative = Path(fixture.display_path).with_suffix("")
    if fixture.corpus == "examples":
        relative = Path(relative.name)
    return result_dir / fixture.corpus / engine / relative


def append_suffix(path: Path, suffix: str) -> Path:
    return Path(str(path) + suffix)


def write_failure_artifacts(
    base: Path,
    expected: str,
    actual: str,
    diff: str,
) -> None:
    base.parent.mkdir(parents=True, exist_ok=True)
    append_suffix(base, ".d2.canonical.txt").write_text(
        expected, encoding="utf-8"
    )
    append_suffix(base, ".diago.canonical.txt").write_text(
        actual, encoding="utf-8"
    )
    append_suffix(base, ".diff").write_text(diff, encoding="utf-8")


def board_target(relative_svg: Path) -> str | None:
    parts = list(relative_svg.with_suffix("").parts)
    if parts[-1] == "index":
        parts.pop()
    return ".".join(parts) if parts else None


def main() -> int:
    args = parse_args()
    engines = args.engines or ["dagre", "elk"]
    fixtures = collect_fixtures(args.corpus, args.paths or [])
    d2_binary = shutil.which(args.d2_bin)
    if d2_binary is None:
        raise RuntimeError(f"D2 binary not found: {args.d2_bin}")
    diago_binary = (
        args.diago_bin.resolve() if args.diago_bin else build_diago(args.release)
    )
    if not diago_binary.is_file():
        raise RuntimeError(f"Diago binary not found: {diago_binary}")

    result_dir = args.result_dir.resolve()
    if result_dir.exists():
        shutil.rmtree(result_dir)
    result_dir.mkdir(parents=True)
    results_path = result_dir / "results.tsv"
    failures = 0
    counts = {engine: {"pass": 0, "fail": 0} for engine in engines}

    with results_path.open("w", encoding="utf-8", newline="") as results_file:
        writer = csv.writer(results_file, delimiter="\t")
        writer.writerow(["corpus", "engine", "outcome", "category", "path"])

        total = len(fixtures) * len(engines)
        completed = 0
        for engine in engines:
            for fixture in fixtures:
                completed += 1
                base = output_base(result_dir, fixture, engine)
                d2_svg = append_suffix(base, ".d2.svg")
                diago_svg = append_suffix(base, ".diago.svg")
                d2_log = append_suffix(base, ".d2.log")
                diago_log = append_suffix(base, ".diago.log")
                d2_svg.parent.mkdir(parents=True, exist_ok=True)

                d2_ok = run_command(
                    [
                        d2_binary,
                        "--layout",
                        engine,
                        "--bundle=false",
                        "--omit-version",
                        str(fixture.source_path),
                        str(d2_svg),
                    ],
                    d2_log,
                )

                d2_board_dir = d2_svg.with_suffix("")
                if d2_svg.is_file():
                    boards = [(Path("index.svg"), d2_svg)]
                elif d2_board_dir.is_dir():
                    boards = [
                        (path.relative_to(d2_board_dir), path)
                        for path in sorted(d2_board_dir.rglob("*.svg"))
                    ]
                else:
                    boards = []

                if not d2_ok:
                    category = "d2-render"
                    outcome = "fail"
                elif not boards:
                    diago_ok = run_command(
                        [
                            str(diago_binary),
                            "render",
                            "--layout",
                            engine,
                            "--no-bundle",
                            "--omit-version",
                            str(fixture.source_path),
                            str(diago_svg),
                        ],
                        diago_log,
                    )
                    if diago_ok and (
                        not diago_svg.exists()
                        or diago_svg.stat().st_size == 0
                    ):
                        category = "template"
                        outcome = "pass"
                    else:
                        category = "template-output"
                        outcome = "fail"
                else:
                    category = "match"
                    outcome = "pass"
                    for relative_svg, expected_svg in boards:
                        target = board_target(relative_svg)
                        board_key = ".".join(
                            relative_svg.with_suffix("").parts
                        )
                        board_base = (
                            base
                            if len(boards) == 1
                            else append_suffix(base, "." + board_key)
                        )
                        actual_svg = (
                            diago_svg
                            if len(boards) == 1
                            else append_suffix(board_base, ".diago.svg")
                        )
                        actual_log = (
                            diago_log
                            if len(boards) == 1
                            else append_suffix(board_base, ".diago.log")
                        )
                        command = [
                            str(diago_binary),
                            "render",
                            "--layout",
                            engine,
                            "--no-bundle",
                            "--omit-version",
                        ]
                        if target is not None:
                            command.extend(["--target", target])
                        command.extend(
                            [str(fixture.source_path), str(actual_svg)]
                        )
                        if not run_command(command, actual_log):
                            category = "diago-render"
                            outcome = "fail"
                            break
                        try:
                            comparison = compare_svg_files(
                                expected_svg, actual_svg
                            )
                        except Exception as error:
                            append_suffix(
                                board_base, ".compare.log"
                            ).write_text(
                                f"{type(error).__name__}: {error}\n",
                                encoding="utf-8",
                            )
                            category = "canonicalization"
                            outcome = "fail"
                            break
                        if not comparison.equal:
                            category = comparison.category
                            outcome = "fail"
                            write_failure_artifacts(
                                board_base,
                                comparison.expected,
                                comparison.actual,
                                comparison.diff,
                            )
                            break
                        if not args.keep_successes and len(boards) > 1:
                            actual_svg.unlink(missing_ok=True)
                            actual_log.unlink(missing_ok=True)

                writer.writerow(
                    [
                        fixture.corpus,
                        engine,
                        outcome,
                        category,
                        fixture.display_path,
                    ]
                )
                counts[engine][outcome] += 1
                if outcome == "fail":
                    failures += 1
                    print(
                        f"FAIL [{engine}/{category}] "
                        f"{fixture.corpus}:{fixture.display_path}"
                    )
                elif not args.keep_successes:
                    d2_svg.unlink(missing_ok=True)
                    if d2_board_dir.is_dir():
                        shutil.rmtree(d2_board_dir)
                    diago_svg.unlink(missing_ok=True)
                    d2_log.unlink(missing_ok=True)
                    diago_log.unlink(missing_ok=True)

                if completed % 25 == 0 or completed == total:
                    print(f"Progress: {completed}/{total}", flush=True)

    print()
    print("Normalized D2 SVG parity")
    print(f"Results: {results_path}")
    for engine in engines:
        print(
            f"{engine:6} pass={counts[engine]['pass']} "
            f"fail={counts[engine]['fail']}"
        )
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(2)
