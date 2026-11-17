///|
/// The optional bundled Source Sans Pro and Source Code Pro font assets.
/// Importing `fonts` or `renderer_svg_core` does not include these assets.
pub fn resolve(face : @fonts.Face) -> @fonts.Source? {
  Some(
    Ttf(
      match face {
        SansRegular => source_sans_pro_regular_ttf_bytes
        SansBold => source_sans_pro_bold_ttf_bytes
        SansSemibold => source_sans_pro_semibold_ttf_bytes
        SansItalic => source_sans_pro_italic_ttf_bytes
        MonoRegular => source_code_pro_regular_ttf_bytes
        MonoBold => source_code_pro_bold_ttf_bytes
        MonoItalic => source_code_pro_italic_ttf_bytes
      },
    ),
  )
}
