///|
/// Use host-provided measurements for every text role during this operation.
pub fn SvgConfig::with_measurer(
  self : SvgConfig,
  measurer : @fonts.Measurer?,
) -> SvgConfig {
  { ..self, measurer, }
}
