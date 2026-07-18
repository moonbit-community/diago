// Generates `text_metrics/font_metrics.mbt` from the embedded reference fonts.
//
// Run this from a checkout where upstream reference's Go modules resolve, for example:
//
//	go run /path/to/diago/text_metrics/gen_font_metrics.go > /path/to/diago/text_metrics/font_metrics.mbt
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/golang/freetype/truetype"
	"golang.org/x/image/font"
	"golang.org/x/image/math/fixed"

	"oss.terrastruct.com/d2/d2renderers/d2fonts"
	"oss.terrastruct.com/d2/lib/textmeasure"
)

const (
	geoStart    = 0x25A0
	geoEnd      = 0x25FF
	replacement = 0xFFFD
)

type fontVariant struct {
	name   string
	family d2fonts.FontFamily
	style  d2fonts.FontStyle
}

var variants = []fontVariant{
	{name: "sans_regular", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_REGULAR},
	{name: "sans_bold", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_BOLD},
	{name: "sans_semibold", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_SEMIBOLD},
	{name: "sans_italic", family: d2fonts.SourceSansPro, style: d2fonts.FONT_STYLE_ITALIC},
	{name: "mono_regular", family: d2fonts.SourceCodePro, style: d2fonts.FONT_STYLE_REGULAR},
	{name: "mono_bold", family: d2fonts.SourceCodePro, style: d2fonts.FONT_STYLE_BOLD},
	{name: "mono_italic", family: d2fonts.SourceCodePro, style: d2fonts.FONT_STYLE_ITALIC},
	{name: "hand_regular", family: d2fonts.HandDrawn, style: d2fonts.FONT_STYLE_REGULAR},
	{name: "hand_bold", family: d2fonts.HandDrawn, style: d2fonts.FONT_STYLE_BOLD},
}

func loadFace(v fontVariant) (font.Face, int, error) {
	sizeless := d2fonts.Font{Family: v.family, Style: v.style, Size: 0}
	ttfBytes := d2fonts.FontFaces.Get(sizeless)
	ttf, err := truetype.Parse(ttfBytes)
	if err != nil {
		return nil, 0, err
	}
	unitsPerEm := int(ttf.FUnitsPerEm())
	face := truetype.NewFace(
		ttf,
		&truetype.Options{Size: float64(unitsPerEm) / 64.0},
	)
	return face, unitsPerEm, nil
}

func glyphMetrics(face font.Face, r rune) (xMin, xMax int, advance fixed.Int26_6) {
	b, adv, ok := face.GlyphBounds(r)
	if !ok {
		return 0, 0, 0
	}
	return int(b.Min.X), int(b.Max.X), adv
}

func emitArrayIntFlat(name string, values []int, perLine int) {
	fmt.Printf("let %s : Array[Int] = [\n", name)
	for i, v := range values {
		if i%perLine == 0 {
			fmt.Print("  ")
		}
		fmt.Printf("%d", v)
		if i != len(values)-1 {
			fmt.Print(", ")
		}
		if i%perLine == perLine-1 || i == len(values)-1 {
			fmt.Print("\n")
		}
	}
	fmt.Println("]")
}

func emitArrayInt(name string, values []int) {
	emitArrayIntFlat(name, values, 32)
}

func selectedSizes() []int {
	return []int{1, 2, 8, 10, 12, 13, 14, 16, 18, 20, 21, 24, 28, 29, 30, 32, 35, 36, 40, 43, 48, 55, 75, 85, 90, 100}
}

func emitSizeSpecificMetrics() {
	fmt.Println("// Generated from upstream reference embedded fonts by text_metrics/gen_font_metrics.go --size-specific. Do not edit by hand.")
	fmt.Println()
	fmt.Println("///|")
	emitArrayInt("size_specific_font_sizes", selectedSizes())
	fmt.Println()
	for _, v := range variants {
		fmt.Println("///|")
		fmt.Printf("let glyph_x_mins_%s_by_size : Array[Array[Int]] = [\n", v.name)
		for _, size := range selectedSizes() {
			face, _, err := loadFaceAtSize(v, size)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			values := make([]int, 256)
			for cp := 0; cp < 256; cp++ {
				bounds, _, ok := face.GlyphBounds(rune(cp))
				if ok {
					values[cp] = bounds.Min.X.Floor()
				}
			}
			emitNestedArray(values)
		}
		fmt.Println("]")
		fmt.Println()

		fmt.Println("///|")
		fmt.Printf("let glyph_x_maxs_%s_by_size : Array[Array[Int]] = [\n", v.name)
		for _, size := range selectedSizes() {
			face, _, err := loadFaceAtSize(v, size)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			values := make([]int, 256)
			for cp := 0; cp < 256; cp++ {
				bounds, _, ok := face.GlyphBounds(rune(cp))
				if ok {
					values[cp] = bounds.Max.X.Ceil()
				}
			}
			emitNestedArray(values)
		}
		fmt.Println("]")
		fmt.Println()

		fmt.Println("///|")
		fmt.Printf("let glyph_advances_fixed_%s_by_size : Array[Array[Int]] = [\n", v.name)
		for _, size := range selectedSizes() {
			face, _, err := loadFaceAtSize(v, size)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			values := make([]int, 256)
			for cp := 0; cp < 256; cp++ {
				_, advance, ok := face.GlyphBounds(rune(cp))
				if ok {
					values[cp] = int(advance)
				}
			}
			emitNestedArray(values)
		}
		fmt.Println("]")
		fmt.Println()

		fmt.Println("///|")
		fmt.Printf("let glyph_replacement_%s_by_size : Array[Array[Int]] = [\n", v.name)
		for _, size := range selectedSizes() {
			face, _, err := loadFaceAtSize(v, size)
			if err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
			bounds, advance, ok := face.GlyphBounds(replacement)
			if !ok {
				emitNestedArray([]int{0, 0, 0})
			} else {
				emitNestedArray([]int{bounds.Min.X.Floor(), bounds.Max.X.Ceil(), int(advance)})
			}
		}
		fmt.Println("]")
		fmt.Println()
		for i, size := range selectedSizes() {
			if !legacySizeSpecificName(v.name, size) {
				continue
			}
			fmt.Println("///|")
			fmt.Printf("let glyph_x_mins_%s_sz%d : Array[Int] = glyph_x_mins_%s_by_size[%d]\n\n", v.name, size, v.name, i)
			fmt.Println("///|")
			fmt.Printf("let glyph_x_maxs_%s_sz%d : Array[Int] = glyph_x_maxs_%s_by_size[%d]\n\n", v.name, size, v.name, i)
			fmt.Println("///|")
			fmt.Printf("let glyph_advances_fixed_%s_sz%d : Array[Int] = glyph_advances_fixed_%s_by_size[%d]\n\n", v.name, size, v.name, i)
		}
	}
}

func legacySizeSpecificName(name string, size int) bool {
	switch name {
	case "sans_regular":
		return size == 20 || size == 24 || size == 28
	case "sans_bold":
		return size == 20 || size == 24 || size == 28 || size == 29 || size == 32
	case "sans_semibold":
		return size == 20 || size == 24 || size == 28 || size == 32
	case "mono_regular":
		return size == 20
	default:
		return false
	}
}

func emitNestedArray(values []int) {
	fmt.Println("  [")
	for i, value := range values {
		if i%32 == 0 {
			fmt.Print("    ")
		}
		fmt.Print(strconv.Itoa(value))
		if i != len(values)-1 {
			fmt.Print(", ")
		}
		if i%32 == 31 || i == len(values)-1 {
			fmt.Println()
		}
	}
	fmt.Println("  ],")
}

func loadFaceAtSize(v fontVariant, size int) (font.Face, int, error) {
	sizeless := d2fonts.Font{Family: v.family, Style: v.style, Size: 0}
	ttfBytes := d2fonts.FontFaces.Get(sizeless)
	ttf, err := truetype.Parse(ttfBytes)
	if err != nil {
		return nil, 0, err
	}
	return truetype.NewFace(ttf, &truetype.Options{Size: float64(size)}), int(ttf.FUnitsPerEm()), nil
}

func main() {
	if len(os.Args) == 2 && os.Args[1] == "--probe" {
		ruler, err := textmeasure.NewRuler()
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		w, h := ruler.Measure(d2fonts.SourceCodePro.Font(16, d2fonts.FONT_STYLE_BOLD), "x")
		fmt.Printf("mono-bold x: %d %d\n", w, h)
		face, _, _ := loadFaceAtSize(fontVariant{name: "mono_bold", family: d2fonts.SourceCodePro, style: d2fonts.FONT_STYLE_BOLD}, 16)
		bounds, advance, _ := face.GlyphBounds('x')
		fmt.Printf("mono-bold x bounds: %d %d advance=%d\n", bounds.Min.X, bounds.Max.X, advance)
		w, h = ruler.Measure(d2fonts.SourceCodePro.Font(16, d2fonts.FONT_STYLE_ITALIC), "hi")
		fmt.Printf("mono-italic hi: %d %d\n", w, h)
		face, _, _ = loadFaceAtSize(fontVariant{name: "mono_italic", family: d2fonts.SourceCodePro, style: d2fonts.FONT_STYLE_ITALIC}, 16)
		for _, r := range "hi" {
			bounds, advance, _ = face.GlyphBounds(r)
			fmt.Printf("mono-italic %c bounds: %d %d advance=%d\n", r, bounds.Min.X, bounds.Max.X, advance)
		}
		return
	}
	if len(os.Args) == 2 && os.Args[1] == "--size-specific" {
		emitSizeSpecificMetrics()
		return
	}
	var b strings.Builder
	b.WriteString("// Generated from upstream reference embedded fonts by text_metrics/gen_font_metrics.go. Do not edit by hand.\n\n")
	b.WriteString("///|\n")
	b.WriteString(fmt.Sprintf("const GEO_START : Int = %d\n\n", geoStart))
	b.WriteString("///|\n")
	b.WriteString(fmt.Sprintf("const GEO_END : Int = %d\n\n", geoEnd))
	fmt.Print(b.String())

	for _, v := range variants {
		face, unitsPerEm, err := loadFace(v)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println("///|")
		fmt.Printf("const FONT_UNITS_PER_EM_%s : Int = %d\n\n", strings.ToUpper(v.name), unitsPerEm)

		asciiXMin := make([]int, 256)
		asciiXMax := make([]int, 256)
		asciiAdvance := make([]int, 256)
		for cp := 0; cp < 256; cp++ {
			xMin, xMax, adv := glyphMetrics(face, rune(cp))
			asciiXMin[cp] = xMin
			asciiXMax[cp] = xMax
			asciiAdvance[cp] = int(adv)
		}

		asciiKern := make([]int, 256*256)
		for left := 0; left < 256; left++ {
			for right := 0; right < 256; right++ {
				k := face.Kern(rune(left), rune(right))
				asciiKern[left*256+right] = int(k)
			}
		}

		geoN := geoEnd - geoStart + 1
		geoXMin := make([]int, geoN)
		geoXMax := make([]int, geoN)
		geoAdvance := make([]int, geoN)
		for cp := geoStart; cp <= geoEnd; cp++ {
			xMin, xMax, adv := glyphMetrics(face, rune(cp))
			idx := cp - geoStart
			geoXMin[idx] = xMin
			geoXMax[idx] = xMax
			geoAdvance[idx] = int(adv)
		}

		fmt.Println("///|")
		emitArrayInt("glyph_x_mins_"+v.name, asciiXMin)
		fmt.Println()
		fmt.Println("///|")
		emitArrayInt("glyph_x_maxs_"+v.name, asciiXMax)
		fmt.Println()
		fmt.Println("///|")
		emitArrayInt("glyph_advances_fixed_"+v.name, asciiAdvance)
		fmt.Println()
		fmt.Println("///|")
		emitArrayIntFlat("kernings_fixed_"+v.name, asciiKern, 16)
		fmt.Println()

		fmt.Println("///|")
		emitArrayInt("glyph_x_mins_"+v.name+"_geo", geoXMin)
		fmt.Println()
		fmt.Println("///|")
		emitArrayInt("glyph_x_maxs_"+v.name+"_geo", geoXMax)
		fmt.Println()
		fmt.Println("///|")
		emitArrayInt("glyph_advances_fixed_"+v.name+"_geo", geoAdvance)
		fmt.Println()
		replacementXMin, replacementXMax, replacementAdvance := glyphMetrics(face, replacement)
		fmt.Println("///|")
		fmt.Printf(
			"let glyph_replacement_%s : Array[Int] = [%d, %d, %d]\n",
			v.name,
			replacementXMin,
			replacementXMax,
			int(replacementAdvance),
		)
		fmt.Println()
	}
}
