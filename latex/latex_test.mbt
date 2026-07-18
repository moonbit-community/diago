///|
test "MathJax renders and measures a simple formula like D2" {
  let output = match render("x^2") {
    Ok(output) => output
    Err(error) => fail(error.to_string())
  }
  assert_true(output.svg.contains("data-mml-node=\"math\""))
  assert_eq(output.width, 19)
  assert_eq(output.height, 17)
}
