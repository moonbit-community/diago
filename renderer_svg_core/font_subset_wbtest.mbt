///|
test "font subset failures are reported" {
  try d2_subset_font_data_url(b"", "abc") catch {
    error =>
      inspect(error, content="RenderFailed(failed to subset embedded font)")
  } noraise {
    _ => fail("expected font subsetting to fail")
  }
}
