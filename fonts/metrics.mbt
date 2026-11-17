///|
/// A text run to measure in pixels. The selected face is the same role used by
/// the SVG font resolver. The host must load its fonts before measurement.
pub(all) struct MeasureRequest {
  text : String
  font_size : Int32
  face : Face
  /// Include the pen advance, including trailing whitespace, in the bounds.
  bounds_with_dot : Bool
  /// Use the code-label line-height convention for multiline text.
  code_line_height : Bool
}

///|
/// Unrounded dimensions for the complete request, including any newlines.
/// Values must be finite and nonnegative. Diago rounds the final label bounds.
pub(all) struct Measurement {
  width : Double
  height : Double
}

///|
/// A per-call text measurement implementation, for example backed by a browser
/// canvas, a host font library, or precomputed metrics for a custom typeface.
pub struct Measurer((MeasureRequest) -> Measurement)

///|
pub fn Measurer::new(measure : (MeasureRequest) -> Measurement) -> Measurer {
  Measurer(measure)
}

///|
pub fn Measurer::measure(
  self : Measurer,
  request : MeasureRequest,
) -> Measurement {
  let Measurer(measure) = self
  measure(request)
}

///|
pub impl Debug for Measurer with fn to_repr(_self) {
  Repr("custom text measurer")
}

///|
#deprecated
pub extend Measurer with Debug::{to_repr}
