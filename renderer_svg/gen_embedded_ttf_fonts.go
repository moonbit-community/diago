// Generates `renderer_svg/embedded_ttf_fonts.mbt` from D2's embedded fonts.
//
// Run this from the D2 checkout so its Go module resolves, for example:
//
//	go run /path/to/diago/renderer_svg/gen_embedded_ttf_fonts.go > /path/to/diago/renderer_svg/embedded_ttf_fonts.mbt
package main

import (
	"fmt"

	"oss.terrastruct.com/d2/d2renderers/d2fonts"
)

type fontVariant struct {
	name   string
	family d2fonts.FontFamily
	style  d2fonts.FontStyle
}

var variants = []fontVariant{
	{name: "source_sans_pro_regular", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_REGULAR},
	{name: "source_sans_pro_bold", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_BOLD},
	{name: "source_sans_pro_semibold", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_SEMIBOLD},
	{name: "source_sans_pro_italic", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_ITALIC},
	{name: "source_code_pro_regular", family: d2fonts.SourceCodePro, style: d2fonts.FONT_STYLE_REGULAR},
	{name: "source_code_pro_bold", family: d2fonts.SourceCodePro, style: d2fonts.FONT_STYLE_BOLD},
	{name: "source_code_pro_italic", family: d2fonts.SourceCodePro, style: d2fonts.FONT_STYLE_ITALIC},
}

func emitBytes(name string, data []byte) {
	const chunkSize = 12000
	fmt.Printf("let %s_ttf_bytes : Bytes = concat_font_chunks([\n", name)
	for start := 0; start < len(data); start += chunkSize {
		end := min(start+chunkSize, len(data))
		fmt.Print("  b\"")
		for _, value := range data[start:end] {
			fmt.Printf("\\x%02x", value)
		}
		fmt.Println("\",")
	}
	fmt.Println("])")
}

func main() {
	fmt.Println("// Generated from D2's embedded fonts by renderer_svg/gen_embedded_ttf_fonts.go. Do not edit by hand.")
	fmt.Println()
	fmt.Println("///|")
	fmt.Println("fn concat_font_chunks(chunks : Array[Bytes]) -> Bytes {")
	fmt.Println("  let output : Array[Byte] = []")
	fmt.Println("  for chunk in chunks {")
	fmt.Println("    for byte in chunk {")
	fmt.Println("      output.push(byte)")
	fmt.Println("    }")
	fmt.Println("  }")
	fmt.Println("  Bytes::from_array(output)")
	fmt.Println("}")
	fmt.Println()
	for _, variant := range variants {
		font := d2fonts.Font{Family: variant.family, Style: variant.style, Size: 0}
		fmt.Println("///|")
		emitBytes(variant.name, d2fonts.FontFaces.Get(font))
		fmt.Println()
	}
}
