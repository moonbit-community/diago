///|
test "syntax_path_last_display preserves quoted dots and escapes" {
  @debug.assert_eq(
    syntax_path_last_display("alpha.\"beta.gamma\""),
    "beta.gamma",
  )
  @debug.assert_eq(syntax_path_last_display("alpha.'beta.gamma'"), "beta.gamma")
  @debug.assert_eq(
    syntax_path_last_display("alpha.\"+peek\\\"()\""),
    "+peek\"()",
  )
  @debug.assert_eq(syntax_path_last_display("alpha.rewind()"), "rewind()")
}
