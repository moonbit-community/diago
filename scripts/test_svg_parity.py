#!/usr/bin/env python3

import unittest

from svg_parity import compare_svg_text


class SvgParityTest(unittest.TestCase):
    def test_ignores_only_renderer_instability(self) -> None:
        d2 = """<svg xmlns="http://www.w3.org/2000/svg"
          data-d2-version="v0.7.1" viewBox="0 0 10 10">
          <svg class="d2-123 d2-svg">
            <style>.d2-123 .text{font-family:x}@font-face{
              src:url("data:application/font-woff;base64,AAAA")}
              .sketch-overlay-B1{fill:red}</style>
            <rect width="10" height="10" class="fill-B1 shape"/>
          </svg>
        </svg>"""
        diago = """<svg viewBox="0 0 10 10"
          xmlns="http://www.w3.org/2000/svg" data-d2-version="0.3.0">
          <svg class="d2-svg d2-999">
            <style>.d2-999 .text{font-family:x}@font-face{
              src:url("data:application/font-woff;base64,BBBB")}</style>
            <rect class="shape fill-B1" height="10" width="10"/>
          </svg>
        </svg>"""
        self.assertTrue(compare_svg_text(d2, diago).equal)

    def test_preserves_geometry(self) -> None:
        d2 = '<svg xmlns="http://www.w3.org/2000/svg"><path d="M 0 0"/></svg>'
        diago = (
            '<svg xmlns="http://www.w3.org/2000/svg">'
            '<path d="M 0 1"/></svg>'
        )
        comparison = compare_svg_text(d2, diago)
        self.assertFalse(comparison.equal)
        self.assertEqual(comparison.category, "geometry")

    def test_preserves_active_sketch_css(self) -> None:
        d2 = """<svg xmlns="http://www.w3.org/2000/svg">
          <style>.sketch-overlay-B1{fill:red}</style>
          <path class="sketch-overlay-B1"/>
        </svg>"""
        diago = """<svg xmlns="http://www.w3.org/2000/svg">
          <style>.sketch-overlay-B1{fill:blue}</style>
          <path class="sketch-overlay-B1"/>
        </svg>"""
        comparison = compare_svg_text(d2, diago)
        self.assertFalse(comparison.equal)
        self.assertEqual(comparison.category, "style")


if __name__ == "__main__":
    unittest.main()
