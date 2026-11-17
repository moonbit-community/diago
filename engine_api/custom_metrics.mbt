///|
/// Use host-provided measurements for every text role during this operation.
pub fn LayoutConfig::with_measurer(
  self : LayoutConfig,
  measurer : @fonts.Measurer?,
) -> LayoutConfig {
  { ..self, measurer, }
}
