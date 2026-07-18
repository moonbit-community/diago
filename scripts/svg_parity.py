#!/usr/bin/env python3

"""Strict SVG canonicalization for D2 renderer parity checks."""

from __future__ import annotations

import difflib
import json
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


_SCOPE_RE = re.compile(r"d2-\d+")
_FONT_DATA_RE = re.compile(
    r"data:application/font-(?:woff2?|ttf|otf);base64,[A-Za-z0-9+/=]+"
)
_SKETCH_RULE_RE = re.compile(r"\.sketch-overlay-([A-Za-z0-9_-]+)\{[^{}]*\}")
_WHITESPACE_RE = re.compile(r"\s+")


@dataclass(frozen=True)
class SvgComparison:
    equal: bool
    category: str
    expected: str
    actual: str
    diff: str


def _local_name(name: str) -> str:
    if name.startswith("{http://www.w3.org/2000/svg}"):
        return name.rsplit("}", 1)[1]
    if name.startswith("{http://www.w3.org/1999/xlink}"):
        return "xlink:" + name.rsplit("}", 1)[1]
    return name


def _normalize_scope(value: str) -> str:
    return _SCOPE_RE.sub("d2-SCOPE", value)


def _normalize_style_attribute(value: str) -> str:
    declarations = []
    for declaration in value.split(";"):
        declaration = declaration.strip()
        if declaration:
            declarations.append(_WHITESPACE_RE.sub(" ", declaration))
    return ";".join(declarations)


def _normalize_css(css: str, used_classes: set[str]) -> str:
    css = css.replace("\r\n", "\n").replace("\r", "\n")
    css = _normalize_scope(css)
    css = _FONT_DATA_RE.sub("data:application/font-woff;base64,FONT", css)

    def keep_active_sketch_rule(match: re.Match[str]) -> str:
        class_name = "sketch-overlay-" + match.group(1)
        return match.group(0) if class_name in used_classes else ""

    css = _SKETCH_RULE_RE.sub(keep_active_sketch_rule, css)
    return _WHITESPACE_RE.sub(" ", css).strip()


def _collect_used_classes(root: ET.Element) -> set[str]:
    classes: set[str] = set()
    for element in root.iter():
        value = element.attrib.get("class")
        if value:
            classes.update(value.split())
    return classes


def canonicalize_svg_text(svg: str) -> str:
    """Return a deterministic, strict token stream for an SVG document.

    The canonical form ignores only non-visual renderer instability:
    version metadata, D2 scope salts, embedded font bytes, XML attribute order,
    class token order, insignificant XML whitespace, and unused static sketch
    CSS. Element order, geometry, text, styles, links, images, IDs, and
    references remain significant.
    """

    root = ET.fromstring(svg)
    used_classes = _collect_used_classes(root)
    lines: list[str] = []

    def visit(element: ET.Element, depth: int) -> None:
        tag = _local_name(element.tag)
        attributes: list[tuple[str, str]] = []
        for raw_name, raw_value in element.attrib.items():
            name = _local_name(raw_name)
            if name == "data-d2-version":
                continue
            value = _normalize_scope(raw_value)
            value = _FONT_DATA_RE.sub(
                "data:application/font-woff;base64,FONT", value
            )
            if name == "class":
                value = " ".join(sorted(value.split()))
            elif name == "style":
                value = _normalize_style_attribute(value)
            attributes.append((name, value))
        href = element.attrib.get("href")
        xlink_href = element.attrib.get(
            "{http://www.w3.org/1999/xlink}href"
        )
        if href is not None and xlink_href == href:
            attributes = [
                item for item in attributes if item[0] != "xlink:href"
            ]
        attributes.sort()
        prefix = "  " * depth
        lines.append(
            f"{prefix}<{tag} {json.dumps(attributes, ensure_ascii=False)}>"
        )

        text = element.text or ""
        if tag == "style":
            text = _normalize_css(text, used_classes)
        elif not text.strip():
            text = ""
        if text:
            lines.append(
                f"{prefix}  #text {json.dumps(text, ensure_ascii=False)}"
            )

        for child in element:
            visit(child, depth + 1)
            tail = child.tail or ""
            if tail.strip():
                lines.append(
                    f"{prefix}  #tail {json.dumps(tail, ensure_ascii=False)}"
                )
        lines.append(f"{prefix}</{tag}>")

    visit(root, 0)
    return "\n".join(lines) + "\n"


def canonicalize_svg_file(path: Path) -> str:
    return canonicalize_svg_text(path.read_text(encoding="utf-8"))


def _classify_diff(diff: str) -> str:
    changed = "\n".join(
        line for line in diff.splitlines() if line.startswith(("+", "-"))
    )
    if any(
        token in changed
        for token in (
            '"d"',
            '"points"',
            '"viewBox"',
            '"x"',
            '"x1"',
            '"x2"',
            '"y"',
            '"y1"',
            '"y2"',
            '"width"',
            '"height"',
            '"transform"',
        )
    ):
        return "geometry"
    if any(
        token in changed
        for token in (
            '"class"',
            '"style"',
            '"fill"',
            '"stroke"',
            '"opacity"',
            "<style ",
            "sketch-overlay-",
        )
    ):
        return "style"
    if "#text" in changed:
        return "text"
    return "structure"


def compare_svg_text(expected_svg: str, actual_svg: str) -> SvgComparison:
    expected = canonicalize_svg_text(expected_svg)
    actual = canonicalize_svg_text(actual_svg)
    if expected == actual:
        return SvgComparison(True, "match", expected, actual, "")
    diff = "".join(
        difflib.unified_diff(
            expected.splitlines(keepends=True),
            actual.splitlines(keepends=True),
            fromfile="d2.canonical.svg",
            tofile="diago.canonical.svg",
        )
    )
    return SvgComparison(
        False,
        _classify_diff(diff),
        expected,
        actual,
        diff,
    )


def compare_svg_files(expected_path: Path, actual_path: Path) -> SvgComparison:
    return compare_svg_text(
        expected_path.read_text(encoding="utf-8"),
        actual_path.read_text(encoding="utf-8"),
    )
