name = "Milky2018/diago"

version = "0.3.1"

import {
  "moonbitlang/x@0.4.49",
  "Milky2018/xml@0.2.0",
  "moonbit-community/cmark@0.4.3",
  "Milky2018/moon_swash@0.1.3",
  "Milky2018/moon_cosmic@0.1.6",
  "Milky2018/moon_yazi@0.1.0",
  "gmlewis/flate@0.36.2",
  "gmlewis/io@0.23.3",
  "gmlewis/zlib@0.21.3",
  "Milky2018/moon_elk@0.2.1",
  "moonbit-community/moon_dagre@0.3.1",
  "moonbitlang/async@0.20.1",
}

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/diago"

license = "Apache-2.0"

keywords = [ "graph" ]

description = "A diagram toolkit for MoonBit with Dagre, ELK, and Railway layout engines, rendering SVG, ASCII, and Unicode outputs."

options(
  exclude: [ "examples" ],
)
