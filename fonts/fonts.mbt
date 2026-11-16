///|
/// Font roles used by the renderer and its built-in measurement tables.
#derive(Debug, Eq, Hash)
pub(all) enum Face {
  SansRegular
  SansBold
  SansSemibold
  SansItalic
  MonoRegular
  MonoBold
  MonoItalic
}

///|
/// TTF data is subsetted and embedded in the exported SVG. A URL is written to
/// the SVG unchanged apart from CSS escaping; the renderer performs no I/O.
/// For replacement typefaces, supply a matching Measurer during both layout
/// and rendering. With no Measurer, Diago uses its built-in font metrics.
pub(all) enum Source {
  Ttf(Bytes)
  Url(String)
}

///|
/// Called only for font roles required by the rendered SVG. Return None when
/// the requested face is unavailable; rendering then reports a RenderError.
pub type Resolver = (Face) -> Source?

///|
pub fn Face::name(self : Face) -> String {
  match self {
    SansRegular => "sans-regular"
    SansBold => "sans-bold"
    SansSemibold => "sans-semibold"
    SansItalic => "sans-italic"
    MonoRegular => "mono-regular"
    MonoBold => "mono-bold"
    MonoItalic => "mono-italic"
  }
}

///|
#deprecated
pub extend Face with Debug::{to_repr}

///|
#deprecated
pub extend Face with Eq::{equal, not_equal}

///|
#deprecated
pub extend Face with Hash::{hash, hash_combine}
