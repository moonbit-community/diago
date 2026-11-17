///|
/// Use host-provided measurements for every text role during this operation.
pub fn AsciiConfig::with_measurer(
  self : AsciiConfig,
  measurer : @fonts.Measurer?,
) -> AsciiConfig {
  { ..self, measurer, }
}
