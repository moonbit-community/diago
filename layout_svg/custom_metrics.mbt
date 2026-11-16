///|
/// Use host-provided measurements for every text role during this operation.
pub fn LegendLayoutConfig::with_measurer(
  self : LegendLayoutConfig,
  measurer : @fonts.Measurer?,
) -> LegendLayoutConfig {
  { ..self, measurer, }
}
