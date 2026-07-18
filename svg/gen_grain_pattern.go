// Generates grain_pattern_data.mbt from D2's embedded grain SVG template.
package main

import (
	"fmt"
	"os"
	"regexp"
	"strings"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: go run gen_grain_pattern.go <d2-grain.txt> <output.mbt>")
		os.Exit(2)
	}
	input, err := os.ReadFile(os.Args[1])
	if err != nil {
		panic(err)
	}
	match := regexp.MustCompile(`base64,([^\"]+)`).FindSubmatch(input)
	if match == nil {
		panic("grain template does not contain an embedded PNG")
	}
	const chunkSize = 100
	data := string(match[1])
	var out strings.Builder
	out.WriteString("// Generated from D2's d2renderers/d2svg/grain.txt. Do not edit by hand.\n\n")
	out.WriteString("///|\nlet d2_grain_png_base64 : String =\n")
	for start := 0; start < len(data); start += chunkSize {
		end := min(start+chunkSize, len(data))
		fmt.Fprintf(&out, "  %q", data[start:end])
		if end != len(data) {
			out.WriteString(" +")
		}
		out.WriteByte('\n')
	}
	if err := os.WriteFile(os.Args[2], []byte(out.String()), 0o644); err != nil {
		panic(err)
	}
}
