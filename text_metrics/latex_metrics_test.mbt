///|
test "LaTeX measurement matches D2 MathJax ex conversion" {
  inspect(
    @text_metrics.measure_label_latex("x^2"),
    content="{width: 19, height: 17}",
  )
}
