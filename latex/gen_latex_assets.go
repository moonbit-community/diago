// Generates latex_assets.mbt from D2's pinned MathJax renderer assets.
//
// Run from the Diago repository root:
//
//   go run latex/gen_latex_assets.go ../d2/d2renderers/d2latex > latex/latex_assets.mbt
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

const chunkSize = 4000

func emit(name, path string) {
	content, err := os.ReadFile(path)
	if err != nil {
		panic(err)
	}
	source := strings.TrimSuffix(string(content), "\n")
	runes := []rune(source)
	fmt.Printf("///|\nlet %s : String =\n  [\n", name)
	for start := 0; start < len(runes); start += chunkSize {
		end := min(start+chunkSize, len(runes))
		fmt.Printf("    %s,\n", strconv.Quote(string(runes[start:end])))
	}
	fmt.Println("  ].join(\"\")")
	fmt.Println()
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: gen_latex_assets <d2latex-dir>")
		os.Exit(2)
	}
	dir := os.Args[1]
	fmt.Println("// Generated from D2 MathJax assets by latex/gen_latex_assets.go. Do not edit by hand.")
	fmt.Println()
	emit("latex_polyfills_source", filepath.Join(dir, "polyfills.js"))
	emit("latex_mathjax_source", filepath.Join(dir, "mathjax.js"))
	emit("latex_setup_source", filepath.Join(dir, "setup.js"))
}
