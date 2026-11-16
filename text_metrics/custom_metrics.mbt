///|
/// Measure using the original tables, without invoking a custom provider.
/// This can also be used as an explicit fallback by host measurers.
pub fn measure_builtin(request : @fonts.MeasureRequest) -> MeasuredText {
  let kind = match request.face {
    SansRegular => FontKind::SansRegular
    SansBold => SansBold
    SansSemibold => SansSemibold
    SansItalic => SansItalic
    MonoRegular => MonoRegular
    MonoBold => MonoBold
    MonoItalic => MonoItalic
  }
  measure_text_with_mode(
    request.text,
    request.font_size,
    kind,
    request.bounds_with_dot,
    request.code_line_height,
  )
}
