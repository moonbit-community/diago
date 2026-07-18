// Generates sketch_assets.mbt from D2's pinned sketch renderer assets.
//
// Run from the Diago repository root:
//
//   swc ../d2/d2renderers/d2sketch/rough.js -C jsc.target=es5 -o /tmp/rough.es5.js
//   go run renderer_svg/gen_sketch_assets.go ../d2/d2renderers/d2sketch /tmp/rough.es5.js > renderer_svg/sketch_assets.mbt
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

func read(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		panic(err)
	}
	return string(b)
}

func replaceRequired(source, old, replacement string) string {
	if !strings.Contains(source, old) {
		panic("expected rough.js fragment was not found")
	}
	return strings.Replace(source, old, replacement, 1)
}

func emit(name, source string) {
	fmt.Printf("///|\nlet %s : String =\n", name)
	source = strings.TrimSuffix(source, "\n")
	for _, line := range strings.Split(source, "\n") {
		fmt.Printf("  #|%s\n", line)
	}
	fmt.Println()
}

func main() {
	if len(os.Args) != 2 && len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: gen_sketch_assets <d2sketch-dir> [transpiled-rough.js]")
		os.Exit(2)
	}
	dir := os.Args[1]
	roughPath := filepath.Join(dir, "rough.js")
	if len(os.Args) == 3 {
		roughPath = os.Args[2]
	}
	rough := read(roughPath)
	// The embedded interpreter treats accessor keywords as reserved even after
	// Babel lowers them to descriptor object keys.
	rough = strings.ReplaceAll(rough, "get: function get(", "\"get\": function _get(")
	rough = strings.ReplaceAll(rough, "set: function set(", "\"set\": function _set(")
	// String.prototype.substr is absent from the embedded runtime; all D2 uses
	// here pass a non-negative start and are equivalent to slice.
	rough = strings.ReplaceAll(rough, ".substr(", ".slice(")
	// Object.defineProperty in the embedded interpreter supports data
	// descriptors but not accessor descriptors. Rough's SVG path walker uses
	// accessor-backed state, so materialize those fields as writable own data
	// properties and keep the position fields synchronized.
	rough = replaceRequired(
		rough,
		"this.bezierReflectionPoint = null, this.quadReflectionPoint = null, this.parsed = new a(t);",
		"this.bezierReflectionPoint = null, this.quadReflectionPoint = null, this.parsed = new a(t), Object.defineProperty(this, \"segments\", { value: this.parsed.segments, writable: true }), Object.defineProperty(this, \"closed\", { value: false, writable: true }), Object.defineProperty(this, \"first\", { value: null, writable: true }), Object.defineProperty(this, \"position\", { value: this._position, writable: true }), Object.defineProperty(this, \"x\", { value: 0, writable: true }), Object.defineProperty(this, \"y\", { value: 0, writable: true });",
	)
	rough = replaceRequired(
		rough,
		"this._position = [\n                    t,\n                    e\n                ], this._first || (this._first = [\n                    t,\n                    e\n                ]);",
		"this._position = [\n                    t,\n                    e\n                ], this.position = this._position, this.x = t, this.y = e, this.first || (this.first = [\n                    t,\n                    e\n                ]);",
	)
	setup := read(filepath.Join(dir, "setup.js"))
	setup = strings.Replace(setup, "const root =", "var root =", 1)
	setup = strings.Replace(setup, "const rc =", "var rc =", 1)
	setup = strings.Replace(setup, "let node;", "var node;", 1)
	setup += "\nif (typeof globalThis !== \"undefined\") {\n    globalThis.rc = rc;\n}\n"
	streaks := read(filepath.Join(dir, "streaks.txt"))

	fmt.Println("// Generated from D2 sketch renderer assets by renderer_svg/gen_sketch_assets.go. Do not edit by hand.")
	fmt.Println()
	emit("sketch_runtime_source", rough)
	emit("sketch_setup_source", setup)
	emit("sketch_streaks_pattern_template", streaks)
}
