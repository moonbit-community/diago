// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// Render-ready diagram model.
///
/// This module mirrors the responsibilities of a "target" format in other
/// implementations: it is the only input type renderers should consume.

///|
/// Typed values preserved from config data entries.
pub(all) enum ConfigDataValue {
  Text(String)
  StringArray(Array[String])
} derive(Eq, Debug)

///|
/// Configuration extracted from source (vars/config).
///
/// Caller-provided options may override these values.
pub struct Config {
  sketch : Bool?
  theme_id : Int?
  dark_theme_id : Int?
  theme_overrides : ThemeOverrides?
  dark_theme_overrides : ThemeOverrides?
  pad : Double?
  center : Bool?
  layout_engine : String?
  scale : Double?
  no_xml_tag : Bool?
  salt : String?
  omit_version : Bool?
  data : Map[String, ConfigDataValue]
} derive(Debug)

///|
pub fn Config::new() -> Config {
  {
    sketch: None,
    theme_id: None,
    dark_theme_id: None,
    theme_overrides: None,
    dark_theme_overrides: None,
    pad: None,
    center: None,
    layout_engine: None,
    scale: None,
    no_xml_tag: None,
    salt: None,
    omit_version: None,
    data: Map([]),
  }
}

///|
pub fn Config::from_parts(
  sketch : Bool?,
  theme_id : Int?,
  dark_theme_id : Int?,
  theme_overrides : ThemeOverrides?,
  dark_theme_overrides : ThemeOverrides?,
  pad : Double?,
  center : Bool?,
  layout_engine : String?,
  scale : Double?,
  no_xml_tag : Bool?,
  salt : String?,
  omit_version : Bool?,
  data : Map[String, ConfigDataValue],
) -> Config {
  {
    sketch,
    theme_id,
    dark_theme_id,
    theme_overrides,
    dark_theme_overrides,
    pad,
    center,
    layout_engine,
    scale,
    no_xml_tag,
    salt,
    omit_version,
    data,
  }
}

///|
/// Renderable shape.
///
/// This is derived from `@graph.ObjectInput` after layout has been applied.
pub struct Shape {
  id : String
  semantic_id : String
  label : String
  shape_type : @graph.ShapeType
  style : @graph.StyleInput
  box : @graph.Box?
  label_box : @graph.Box?
  label_width : Double?
  label_height : Double?
  child_ids : Array[String]
  z_index : Int
  icon : String?
  icon_position : String?
  tooltip : String?
  tooltip_position : String?
  link : String?
  label_position : String?
  classes : Array[String]
  language : String?
  sql_constraints : Array[String]
  grid_rows : Int?
  grid_columns : Int?
  grid_gap : Double?
  horizontal_gap : Double?
  vertical_gap : Double?
  grid_column_span : Int?
  grid_row_span : Int?
  near : String?
} derive(Debug)

///|
/// Renderable connection.
///
/// This is derived from `@graph.EdgeInput` after layout has been applied.
pub struct Connection {
  index : Int
  src_id : String
  dst_id : String
  src_syntax_id : String
  dst_syntax_id : String
  src_lookup_id : String
  dst_lookup_id : String
  identity_scope_depth : Int
  classes : Array[String]
  src_arrow : Bool
  dst_arrow : Bool
  src_arrowhead : @graph.ArrowheadType
  dst_arrowhead : @graph.ArrowheadType
  src_arrowhead_label : String?
  dst_arrowhead_label : String?
  src_arrowhead_label_color : String?
  dst_arrowhead_label_color : String?
  src_anchor : String?
  dst_anchor : String?
  label : String
  icon : String?
  icon_position : String?
  icon_border_radius : Double?
  link : String?
  style : @graph.StyleInput
  route : Array[@graph.Point]
  bend_points : Array[@graph.Point]?
  is_curve : Bool
  z_index : Int
  reference_count : Int
  label_box : @graph.Box?
  src_column_index : Int?
  dst_column_index : Int?
} derive(Debug)

///|
/// Build the renderable shape used by the SVG legend's scaled icon.
pub fn Shape::legend_icon(
  id : String,
  shape_type : @graph.ShapeType,
  style : @graph.StyleInput,
) -> Shape {
  {
    id,
    semantic_id: id,
    label: "",
    shape_type,
    style,
    box: Some(@graph.Box::new(0.0, 0.0, 120.0, 120.0)),
    label_box: None,
    label_width: None,
    label_height: None,
    child_ids: [],
    z_index: 0,
    icon: None,
    icon_position: None,
    tooltip: None,
    tooltip_position: None,
    link: None,
    label_position: None,
    classes: [],
    language: None,
    sql_constraints: [],
    grid_rows: None,
    grid_columns: None,
    grid_gap: None,
    horizontal_gap: None,
    vertical_gap: None,
    grid_column_span: None,
    grid_row_span: None,
    near: None,
  }
}

///|
/// Build the renderable connection used by the SVG legend's scaled icon.
pub fn Connection::legend_icon(
  src_id : String,
  dst_id : String,
  index : Int,
  src_arrow : Bool,
  dst_arrow : Bool,
  src_arrowhead : @graph.ArrowheadType,
  dst_arrowhead : @graph.ArrowheadType,
  style : @graph.StyleInput,
) -> Connection {
  {
    index,
    src_id,
    dst_id,
    src_syntax_id: src_id,
    dst_syntax_id: dst_id,
    src_lookup_id: src_id,
    dst_lookup_id: dst_id,
    identity_scope_depth: @graph.syntax_path_depth(src_id),
    classes: [],
    src_arrow,
    dst_arrow,
    src_arrowhead,
    dst_arrowhead,
    src_arrowhead_label: None,
    dst_arrowhead_label: None,
    src_arrowhead_label_color: None,
    dst_arrowhead_label_color: None,
    src_anchor: None,
    dst_anchor: None,
    label: "",
    icon: None,
    icon_position: None,
    icon_border_radius: None,
    link: None,
    style,
    route: [@graph.Point::new(0.0, 0.0), @graph.Point::new(48.0, 0.0)],
    bend_points: None,
    is_curve: false,
    z_index: 0,
    reference_count: 1,
    label_box: None,
    src_column_index: None,
    dst_column_index: None,
  }
}

///|
/// Render-ready diagram.
///
/// `shapes` does not include `root`.
pub struct Diagram {
  name : String
  config : Config?
  is_folder_only : Bool
  description : String
  font_family : String?
  mono_font_family : String?
  root : Shape
  shapes : Array[Shape]
  connections : Array[Connection]
  activation_boxes : Array[(String, @graph.Box)]
  sequence_notes : Array[(String, String, @graph.Box)]
  sequence_fragments : Array[@graph.SequenceFragmentLayout]
  layers : Array[Diagram]
  scenarios : Array[Diagram]
  steps : Array[Diagram]
  legend : @graph.LegendInput?
} derive(Debug)

///|
pub fn Diagram::has_layers(self : Diagram) -> Bool {
  self.layers.length() > 0
}

///|
pub fn Diagram::has_scenarios(self : Diagram) -> Bool {
  self.scenarios.length() > 0
}

///|
pub fn Diagram::has_steps(self : Diagram) -> Bool {
  self.steps.length() > 0
}

///|
pub fn Diagram::without_children(self : Diagram) -> Diagram {
  { ..self, layers: [], scenarios: [], steps: [] }
}

///|
pub fn Diagram::has_legend(self : Diagram) -> Bool {
  match self.legend {
    Some(l) => !l.is_empty() && l.position != Hidden
    None => false
  }
}

///|
pub fn Diagram::has_shape(self : Diagram, condition : (Shape) -> Bool) -> Bool {
  for board in self.layers {
    if board.has_shape(condition) {
      return true
    }
  }
  for board in self.scenarios {
    if board.has_shape(condition) {
      return true
    }
  }
  for board in self.steps {
    if board.has_shape(condition) {
      return true
    }
  }
  for shape in self.shapes {
    if condition(shape) {
      return true
    }
  }
  false
}

///|
/// Get a board by path.
///
/// Supports both explicit and shorthand paths:
/// - Explicit: ["layers", "x", "scenarios", "y"]
/// - Shorthand: ["x", "y"]
pub fn Diagram::get_board(
  self : Diagram,
  board_path : Array[String],
) -> Diagram? {
  get_board_at(self, board_path, 0)
}

///|
fn get_board_at(
  current : Diagram,
  board_path : Array[String],
  index : Int,
) -> Diagram? {
  if index >= board_path.length() {
    return Some(current)
  }

  let head = board_path[index]
  if index == board_path.length() - 1 && current.name == head {
    return Some(current)
  }

  if head == "layers" || head == "scenarios" || head == "steps" {
    if index + 1 >= board_path.length() {
      return None
    }
    let board_name = board_path[index + 1]
    match find_named_board(current, head, board_name) {
      Some(child) => return get_board_at(child, board_path, index + 2)
      None => return None
    }
  }

  match find_named_board_any(current, head) {
    Some(child) => get_board_at(child, board_path, index + 1)
    None => None
  }
}

///|
fn find_named_board(
  current : Diagram,
  board_kind : String,
  board_name : String,
) -> Diagram? {
  if board_kind == "layers" {
    for board in current.layers {
      if board.name == board_name {
        return Some(board)
      }
    }
    return None
  }
  if board_kind == "scenarios" {
    for board in current.scenarios {
      if board.name == board_name {
        return Some(board)
      }
    }
    return None
  }
  if board_kind == "steps" {
    for board in current.steps {
      if board.name == board_name {
        return Some(board)
      }
    }
    return None
  }
  None
}

///|
fn find_named_board_any(current : Diagram, board_name : String) -> Diagram? {
  for board in current.layers {
    if board.name == board_name {
      return Some(board)
    }
  }
  for board in current.scenarios {
    if board.name == board_name {
      return Some(board)
    }
  }
  for board in current.steps {
    if board.name == board_name {
      return Some(board)
    }
  }
  None
}

///|
pub fn Diagram::get_objects(self : Diagram) -> Array[Shape] {
  self.shapes
}

///|
pub fn Diagram::get_edges(self : Diagram) -> Array[Connection] {
  self.connections
}

///|
pub fn Diagram::find_object(self : Diagram, id : String) -> Shape? {
  if self.root.id == id {
    return Some(self.root)
  }
  for obj in self.shapes {
    if obj.id == id {
      return Some(obj)
    }
  }
  if self.root.semantic_id == id {
    return Some(self.root)
  }
  for obj in self.shapes {
    if obj.semantic_id == id {
      return Some(obj)
    }
  }
  None
}

///|
pub fn Diagram::bytes(self : Diagram) -> String {
  let out = StringBuilder::new()
  out.write_string(diagram_shape_array_json(self.shapes))
  out.write_string(diagram_connection_array_json(self.connections))
  out.write_string(diagram_shape_json(self.root))
  match self.config {
    Some(config) => out.write_string(diagram_config_json(config))
    None => ()
  }
  for board in self.layers {
    out.write_string(board.bytes())
  }
  for board in self.scenarios {
    out.write_string(board.bytes())
  }
  for board in self.steps {
    out.write_string(board.bytes())
  }
  out.to_string()
}

///|
pub fn Diagram::hash_id(self : Diagram, salt : String?) -> String {
  let bytes = self.bytes()
  let hash = match salt {
    Some(s) => d2_fnv32a(bytes + s)
    None => d2_fnv32a(bytes)
  }
  "d2-\{d2_u32_decimal(hash)}"
}

///|
pub fn Diagram::with_render_hash_config(
  self : Diagram,
  theme_id : Int,
  dark_theme_id : Int?,
  sketch : Bool,
) -> Diagram {
  let updated_config = match self.config {
    Some(config) =>
      Config::from_parts(
        Some(sketch),
        Some(theme_id),
        dark_theme_id,
        config.theme_overrides,
        config.dark_theme_overrides,
        config.pad,
        config.center,
        config.layout_engine,
        config.scale,
        config.no_xml_tag,
        config.salt,
        config.omit_version,
        config.data,
      )
    None =>
      Config::from_parts(
        Some(sketch),
        Some(theme_id),
        dark_theme_id,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        Map([]),
      )
  }
  let layers : Array[Diagram] = []
  for board in self.layers {
    layers.push(board.with_render_hash_config(theme_id, dark_theme_id, sketch))
  }
  let scenarios : Array[Diagram] = []
  for board in self.scenarios {
    scenarios.push(
      board.with_render_hash_config(theme_id, dark_theme_id, sketch),
    )
  }
  let steps : Array[Diagram] = []
  for board in self.steps {
    steps.push(board.with_render_hash_config(theme_id, dark_theme_id, sketch))
  }
  { ..self, config: Some(updated_config), layers, scenarios, steps }
}

///|
pub fn Diagram::get_nested_corpus(self : Diagram) -> String {
  let corpus = StringBuilder::new()
  corpus.write_string(self.get_corpus())
  for board in self.layers {
    corpus.write_string(board.get_nested_corpus())
  }
  for board in self.scenarios {
    corpus.write_string(board.get_nested_corpus())
  }
  for board in self.steps {
    corpus.write_string(board.get_nested_corpus())
  }
  corpus.to_string()
}

///|
pub fn Diagram::get_corpus(self : Diagram) -> String {
  let corpus = StringBuilder::new()
  let mut appendix_count = 0
  let suppressed_shape_ids : Map[String, Bool] = Map([])
  for shape in self.shapes {
    if shape.shape_type == Class || shape.shape_type == SqlTable {
      for child_id in shape.child_ids {
        suppressed_shape_ids[child_id] = true
      }
    }
  }
  for shape in self.shapes {
    if suppressed_shape_ids.contains(shape.id) {
      continue
    }
    corpus.write_string(shape.label)
    match shape.tooltip {
      Some(tooltip) =>
        if tooltip != "" {
          corpus.write_string(tooltip)
          appendix_count = appendix_count + 1
          corpus.write_string(appendix_count.to_string())
        }
      None => ()
    }
    match shape.link {
      Some(link) =>
        if link != "" {
          corpus.write_string(link)
          appendix_count = appendix_count + 1
          corpus.write_string(appendix_count.to_string())
        }
      None => ()
    }
    corpus.write_string(shape_structured_corpus(shape, self.shapes))
  }
  for connection in self.connections {
    corpus.write_string(connection.label)
    match connection.src_arrowhead_label {
      Some(label) => corpus.write_string(label)
      None => ()
    }
    match connection.dst_arrowhead_label {
      Some(label) => corpus.write_string(label)
      None => ()
    }
  }
  match self.legend {
    Some(legend) =>
      if !legend.is_empty() {
        corpus.write_string(legend_corpus(legend))
      }
    None => ()
  }
  corpus.to_string()
}

///|
pub fn Shape::get_id(self : Shape) -> String {
  self.id
}

///|
pub fn Shape::get_box(self : Shape) -> @graph.Box? {
  self.box
}

///|
pub fn Shape::center(self : Shape) -> @graph.Point? {
  match self.box {
    Some(b) => Some(b.center())
    None => None
  }
}

///|
fn json_string(value : String) -> String {
  Json::string(value).stringify()
}

///|
fn json_bool(value : Bool) -> String {
  Json::boolean(value).stringify()
}

///|
fn json_int(value : Int) -> String {
  value.to_string()
}

///|
fn json_double(value : Double) -> String {
  Json::number(value).stringify()
}

///|
fn json_array(items : Array[String]) -> String {
  let joined = items.join(",")
  "[\{joined}]"
}

///|
fn json_string_array(items : Array[String]) -> String {
  let out : Array[String] = []
  for item in items {
    out.push(json_string(item))
  }
  json_array(out)
}

///|
fn json_object(fields : Array[(String, String)]) -> String {
  let out : Array[String] = []
  for field in fields {
    out.push("\{json_string(field.0)}:\{field.1}")
  }
  let joined = out.join(",")
  "{\{joined}}"
}

///|
fn style_value_json(value : @graph.StyleValue) -> String {
  json_string(value.get_value())
}

///|
fn style_input_json(style : @graph.StyleInput) -> String {
  let fields : Array[(String, String)] = []
  let push = fn(key : String, value : @graph.StyleValue?) {
    match value {
      Some(v) => fields.push((key, style_value_json(v)))
      None => ()
    }
  }
  push("opacity", style.opacity)
  push("stroke", style.stroke)
  push("fill", style.fill)
  push("strokeWidth", style.stroke_width)
  push("strokeDash", style.stroke_dash)
  push("borderRadius", style.border_radius)
  push("shadow", style.shadow)
  push("threeD", style.three_d)
  push("multiple", style.multiple)
  push("font", style.font)
  push("fontSize", style.font_size)
  push("fontColor", style.font_color)
  push("bold", style.bold)
  push("italic", style.italic)
  push("underline", style.underline)
  push("animated", style.animated)
  push("filled", style.filled)
  push("doubleBorder", style.double_border)
  push("textTransform", style.text_transform)
  push("fontFamily", style.font_family)
  push("fillPattern", style.fill_pattern)
  push("sketch", style.sketch)
  push("curved", style.curved)
  json_object(fields)
}

///|
fn point_json(point : @graph.Point) -> String {
  json_object([("x", json_double(point.x)), ("y", json_double(point.y))])
}

///|
fn point_array_json(points : Array[@graph.Point]) -> String {
  let items : Array[String] = []
  for point in points {
    items.push(point_json(point))
  }
  json_array(items)
}

///|
fn box_json(box : @graph.Box) -> String {
  json_object([
    ("x", json_double(box.x)),
    ("y", json_double(box.y)),
    ("width", json_double(box.width)),
    ("height", json_double(box.height)),
  ])
}

///|
fn shape_type_json(shape_type : @graph.ShapeType) -> String {
  json_string(shape_type.to_shape_string())
}

///|
fn arrowhead_json(arrowhead : @graph.ArrowheadType) -> String {
  json_string(arrowhead.to_string())
}

///|
fn diagram_shape_json(shape : Shape) -> String {
  let fields : Array[(String, String)] = [
    ("id", json_string(shape.id)),
    ("semanticId", json_string(shape.semantic_id)),
    ("label", json_string(shape.label)),
    ("shapeType", shape_type_json(shape.shape_type)),
    ("style", style_input_json(shape.style)),
    ("childIds", json_string_array(shape.child_ids)),
    ("zIndex", json_int(shape.z_index)),
    ("classes", json_string_array(shape.classes)),
    ("sqlConstraints", json_string_array(shape.sql_constraints)),
  ]
  match shape.box {
    Some(box) => fields.push(("box", box_json(box)))
    None => ()
  }
  match shape.label_box {
    Some(box) => fields.push(("labelBox", box_json(box)))
    None => ()
  }
  match shape.label_width {
    Some(value) => fields.push(("labelWidth", json_double(value)))
    None => ()
  }
  match shape.label_height {
    Some(value) => fields.push(("labelHeight", json_double(value)))
    None => ()
  }
  match shape.icon {
    Some(value) => fields.push(("icon", json_string(value)))
    None => ()
  }
  match shape.icon_position {
    Some(value) => fields.push(("iconPosition", json_string(value)))
    None => ()
  }
  match shape.tooltip {
    Some(value) => fields.push(("tooltip", json_string(value)))
    None => ()
  }
  match shape.tooltip_position {
    Some(value) => fields.push(("tooltipPosition", json_string(value)))
    None => ()
  }
  match shape.link {
    Some(value) => fields.push(("link", json_string(value)))
    None => ()
  }
  match shape.label_position {
    Some(value) => fields.push(("labelPosition", json_string(value)))
    None => ()
  }
  match shape.language {
    Some(value) => fields.push(("language", json_string(value)))
    None => ()
  }
  match shape.grid_rows {
    Some(value) => fields.push(("gridRows", json_int(value)))
    None => ()
  }
  match shape.grid_columns {
    Some(value) => fields.push(("gridColumns", json_int(value)))
    None => ()
  }
  match shape.grid_gap {
    Some(value) => fields.push(("gridGap", json_double(value)))
    None => ()
  }
  match shape.horizontal_gap {
    Some(value) => fields.push(("horizontalGap", json_double(value)))
    None => ()
  }
  match shape.vertical_gap {
    Some(value) => fields.push(("verticalGap", json_double(value)))
    None => ()
  }
  match shape.grid_column_span {
    Some(value) => fields.push(("gridColumnSpan", json_int(value)))
    None => ()
  }
  match shape.grid_row_span {
    Some(value) => fields.push(("gridRowSpan", json_int(value)))
    None => ()
  }
  match shape.near {
    Some(value) => fields.push(("near", json_string(value)))
    None => ()
  }
  json_object(fields)
}

///|
fn diagram_shape_array_json(shapes : Array[Shape]) -> String {
  let items : Array[String] = []
  for shape in shapes {
    items.push(diagram_shape_json(shape))
  }
  json_array(items)
}

///|
fn diagram_connection_json(connection : Connection) -> String {
  let fields : Array[(String, String)] = [
    ("index", json_int(connection.index)),
    ("srcId", json_string(connection.src_id)),
    ("dstId", json_string(connection.dst_id)),
    ("srcSyntaxId", json_string(connection.src_syntax_id)),
    ("dstSyntaxId", json_string(connection.dst_syntax_id)),
    ("srcLookupId", json_string(connection.src_lookup_id)),
    ("dstLookupId", json_string(connection.dst_lookup_id)),
    ("srcArrow", json_bool(connection.src_arrow)),
    ("dstArrow", json_bool(connection.dst_arrow)),
    ("srcArrowhead", arrowhead_json(connection.src_arrowhead)),
    ("dstArrowhead", arrowhead_json(connection.dst_arrowhead)),
    ("label", json_string(connection.label)),
    ("style", style_input_json(connection.style)),
    ("route", point_array_json(connection.route)),
    ("isCurve", json_bool(connection.is_curve)),
    ("zIndex", json_int(connection.z_index)),
    ("referenceCount", json_int(connection.reference_count)),
  ]
  match connection.src_arrowhead_label {
    Some(value) => fields.push(("srcArrowheadLabel", json_string(value)))
    None => ()
  }
  match connection.dst_arrowhead_label {
    Some(value) => fields.push(("dstArrowheadLabel", json_string(value)))
    None => ()
  }
  match connection.src_arrowhead_label_color {
    Some(value) => fields.push(("srcArrowheadLabelColor", json_string(value)))
    None => ()
  }
  match connection.dst_arrowhead_label_color {
    Some(value) => fields.push(("dstArrowheadLabelColor", json_string(value)))
    None => ()
  }
  match connection.src_anchor {
    Some(value) => fields.push(("srcAnchor", json_string(value)))
    None => ()
  }
  match connection.dst_anchor {
    Some(value) => fields.push(("dstAnchor", json_string(value)))
    None => ()
  }
  match connection.icon {
    Some(value) => fields.push(("icon", json_string(value)))
    None => ()
  }
  match connection.icon_position {
    Some(value) => fields.push(("iconPosition", json_string(value)))
    None => ()
  }
  match connection.icon_border_radius {
    Some(value) => fields.push(("iconBorderRadius", json_double(value)))
    None => ()
  }
  match connection.link {
    Some(value) => fields.push(("link", json_string(value)))
    None => ()
  }
  match connection.bend_points {
    Some(points) => fields.push(("bendPoints", point_array_json(points)))
    None => ()
  }
  match connection.label_box {
    Some(box) => fields.push(("labelBox", box_json(box)))
    None => ()
  }
  match connection.src_column_index {
    Some(value) => fields.push(("srcColumnIndex", json_int(value)))
    None => ()
  }
  match connection.dst_column_index {
    Some(value) => fields.push(("dstColumnIndex", json_int(value)))
    None => ()
  }
  json_object(fields)
}

///|
fn diagram_connection_array_json(connections : Array[Connection]) -> String {
  let items : Array[String] = []
  for connection in connections {
    items.push(diagram_connection_json(connection))
  }
  json_array(items)
}

///|
fn config_data_value_json(value : ConfigDataValue) -> String {
  match value {
    Text(text) => json_string(text)
    StringArray(values) => json_string_array(values)
  }
}

///|
fn theme_overrides_json(overrides : ThemeOverrides) -> String {
  let fields : Array[(String, String)] = []
  for entry in overrides.entries() {
    fields.push((entry.0.to_lower(), json_string(entry.1)))
  }
  json_object(fields)
}

///|
fn sorted_config_data_json(values : Map[String, ConfigDataValue]) -> String {
  let keys : Array[String] = []
  for key, _ in values {
    keys.push(key)
  }
  keys.sort_by(fn(a, b) { a.compare(b) })
  let fields : Array[(String, String)] = []
  for key in keys {
    fields.push((key, config_data_value_json(values[key])))
  }
  json_object(fields)
}

///|
fn diagram_config_json(config : Config) -> String {
  let fields : Array[(String, String)] = []
  match config.sketch {
    Some(value) => fields.push(("sketch", json_bool(value)))
    None => ()
  }
  match config.theme_id {
    Some(value) => fields.push(("themeID", json_int(value)))
    None => ()
  }
  match config.dark_theme_id {
    Some(value) => fields.push(("darkThemeID", json_int(value)))
    None => ()
  }
  match config.pad {
    Some(value) => fields.push(("pad", json_double(value)))
    None => ()
  }
  match config.center {
    Some(value) => fields.push(("center", json_bool(value)))
    None => ()
  }
  match config.layout_engine {
    Some(value) => fields.push(("layoutEngine", json_string(value)))
    None => ()
  }
  match config.theme_overrides {
    Some(overrides) =>
      if !overrides.is_empty() {
        fields.push(("themeOverrides", theme_overrides_json(overrides)))
      }
    None => ()
  }
  match config.dark_theme_overrides {
    Some(overrides) =>
      if !overrides.is_empty() {
        fields.push(("darkThemeOverrides", theme_overrides_json(overrides)))
      }
    None => ()
  }
  if !config.data.is_empty() {
    fields.push(("data", sorted_config_data_json(config.data)))
  }
  json_object(fields)
}

///|
fn legend_corpus(legend : @graph.LegendInput) -> String {
  let corpus = StringBuilder::new()
  match legend.title {
    Some(title) =>
      if title == "" {
        corpus.write_string("Legend")
      } else {
        corpus.write_string(title)
      }
    None => corpus.write_string("Legend")
  }
  for entry in legend.entries {
    match entry {
      ShapeEntry(label~, ..) => corpus.write_string(label)
      ConnectionEntry(label~, ..) => corpus.write_string(label)
      CustomEntry(..) => ()
      Separator => ()
    }
  }
  corpus.to_string()
}

///|
fn object_children(parent : Shape, all_shapes : Array[Shape]) -> Array[Shape] {
  let by_id : Map[String, Shape] = Map([])
  for shape in all_shapes {
    by_id[shape.id] = shape
  }
  let children : Array[Shape] = []
  for child_id in parent.child_ids {
    match by_id.get(child_id) {
      Some(shape) => children.push(shape)
      None => ()
    }
  }
  children
}

///|
fn short_shape_name(shape : Shape) -> String {
  @graph.syntax_path_last_display(shape.id)
}

///|
fn trim_surrounding_double_quotes(s : String) -> String {
  if s.length() >= 2 && s[0] == '"' && s[s.length() - 1] == '"' {
    let out = StringBuilder::new()
    for i = 1; i < s.length() - 1; i = i + 1 {
      match s[i].to_char() {
        Some(ch) => out.write_char(ch)
        None => ()
      }
    }
    out.to_string()
  } else {
    s
  }
}

///|
fn split_class_member_visibility(raw_name : String) -> (String, Bool, String) {
  if raw_name == "" {
    return ("", false, "")
  }
  match raw_name[0].to_char() {
    Some(ch) =>
      if ch == '+' || ch == '-' || ch == '#' || ch == '~' {
        let rest = StringBuilder::new()
        for i = 1; i < raw_name.length(); i = i + 1 {
          match raw_name[i].to_char() {
            Some(c) => rest.write_char(c)
            None => ()
          }
        }
        (rest.to_string(), true, ch.to_string())
      } else {
        (raw_name, false, "")
      }
    None => (raw_name, false, "")
  }
}

///|
fn class_member_corpus(child : Shape) -> String {
  let raw_name = short_shape_name(child)
  let (name_without_visibility, has_explicit_visibility, visibility) = split_class_member_visibility(
    raw_name,
  )
  let is_method = name_without_visibility.contains("(")
  let effective_visibility = if has_explicit_visibility {
    visibility
  } else {
    "+"
  }
  let display_name = effective_visibility + name_without_visibility
  let raw_type = trim_surrounding_double_quotes(child.label)
  let type_name = if raw_type == "" ||
    raw_type == raw_name ||
    raw_type == name_without_visibility ||
    raw_type == display_name {
    if is_method {
      "void"
    } else {
      ""
    }
  } else {
    raw_type
  }
  name_without_visibility + type_name + effective_visibility
}

///|
fn sql_table_constraint_abbr(child : Shape) -> String {
  let abbrs : Array[String] = []
  for constraint in child.sql_constraints {
    abbrs.push(
      match constraint {
        "primary_key" => "PK"
        "foreign_key" => "FK"
        "unique" => "UNQ"
        _ => constraint
      },
    )
  }
  abbrs.join(", ")
}

///|
fn shape_structured_corpus(shape : Shape, all_shapes : Array[Shape]) -> String {
  let corpus = StringBuilder::new()
  match shape.shape_type {
    Class =>
      for child in object_children(shape, all_shapes) {
        corpus.write_string(class_member_corpus(child))
      }
    SqlTable =>
      for child in object_children(shape, all_shapes) {
        corpus.write_string(short_shape_name(child))
        corpus.write_string(child.label)
        corpus.write_string(sql_table_constraint_abbr(child))
      }
    _ => ()
  }
  corpus.to_string()
}

///|
fn d2_fnv32a(text : String) -> Int {
  let mut h : Int = -2128831035
  let bytes = @utf8.encode(text[:])
  for b in bytes {
    h = (h ^ b.to_int()) & 0xffffffff
    h = (h * 16777619) & 0xffffffff
  }
  h
}

///|
fn d2_u32_decimal(v : Int) -> String {
  let unsigned = if v < 0 {
    Int64::from_int(v) + 4294967296L
  } else {
    Int64::from_int(v)
  }
  unsigned.to_string()
}

///|
fn project_double_for_target(value : Double) -> Double {
  value.to_int().to_double()
}

///|
fn project_box_for_target(box : @graph.Box?) -> @graph.Box? {
  match box {
    Some(b) =>
      Some(
        @graph.Box::new(
          project_double_for_target(b.x),
          project_double_for_target(b.y),
          project_double_for_target(b.width),
          project_double_for_target(b.height),
        ),
      )
    None => None
  }
}

///|
const D2_ROUTE_TRUNCATE_SCALE : Double = 1000.0

///|
fn truncate_decimals_like_d2(v : Double) -> Double {
  (v * D2_ROUTE_TRUNCATE_SCALE).to_int().to_double() / D2_ROUTE_TRUNCATE_SCALE
}

///|
fn truncate_float32_like_d2(v : Double) -> Double {
  Float::from_double(v).to_double()
}

///|
fn normalize_route_like_d2(route : Array[@graph.Point]) -> Array[@graph.Point] {
  let out : Array[@graph.Point] = []
  for p in route {
    let x = truncate_float32_like_d2(truncate_decimals_like_d2(p.x))
    let y = truncate_float32_like_d2(truncate_decimals_like_d2(p.y))
    out.push(@graph.Point::new(x, y))
  }
  out
}

///|
fn normalize_bend_points_like_d2(
  bend_points : Array[@graph.Point]?,
) -> Array[@graph.Point]? {
  match bend_points {
    Some(points) => Some(normalize_route_like_d2(points))
    None => None
  }
}

///|

///|
fn shape_from_object(obj : @graph.ObjectInput) -> Shape {
  let projected_metrics_box = project_box_for_target(obj.label_box)
  let projected_label_box = if obj.child_ids.is_empty() {
    None
  } else {
    // Keep container label anchor coordinates in full precision.
    // The reference computes text placement from float label anchors; truncating here
    // introduces 0.5px drift in centered container titles (e.g. legend labels).
    obj.label_box
  }
  let label_width = match projected_metrics_box {
    Some(label_box) => Some(label_box.width)
    None => None
  }
  let label_height = match projected_metrics_box {
    Some(label_box) => Some(label_box.height)
    None => None
  }
  {
    id: obj.abs_id_syntax,
    semantic_id: obj.id,
    label: obj.label,
    shape_type: obj.shape_type,
    style: obj.style,
    box: project_box_for_target(obj.box),
    label_box: projected_label_box,
    label_width,
    label_height,
    child_ids: obj.child_ids,
    z_index: obj.z_index,
    icon: obj.icon,
    icon_position: obj.icon_position,
    tooltip: obj.tooltip,
    tooltip_position: obj.tooltip_position,
    link: obj.link,
    label_position: obj.label_position,
    classes: obj.classes,
    language: obj.language,
    sql_constraints: obj.sql_constraints,
    grid_rows: obj.grid_rows,
    grid_columns: obj.grid_columns,
    grid_gap: obj.grid_gap,
    horizontal_gap: obj.horizontal_gap,
    vertical_gap: obj.vertical_gap,
    grid_column_span: obj.grid_column_span,
    grid_row_span: obj.grid_row_span,
    near: obj.near,
  }
}

///|
fn connection_from_edge(
  edge : @graph.EdgeInput,
  src_id? : String = edge.src_id,
  dst_id? : String = edge.dst_id,
  src_syntax_id? : String = edge.src_id_syntax,
  dst_syntax_id? : String = edge.dst_id_syntax,
  src_lookup_id? : String = edge.src_id_syntax,
  dst_lookup_id? : String = edge.dst_id_syntax,
  identity_scope_depth? : Int = @graph.syntax_path_depth(src_syntax_id),
) -> Connection {
  {
    index: edge.index,
    src_id,
    dst_id,
    src_syntax_id,
    dst_syntax_id,
    src_lookup_id,
    dst_lookup_id,
    identity_scope_depth,
    classes: edge.classes,
    src_arrow: edge.src_arrow,
    dst_arrow: edge.dst_arrow,
    src_arrowhead: edge.src_arrowhead,
    dst_arrowhead: edge.dst_arrowhead,
    src_arrowhead_label: edge.src_arrowhead_label,
    dst_arrowhead_label: edge.dst_arrowhead_label,
    src_arrowhead_label_color: edge.src_arrowhead_label_color,
    dst_arrowhead_label_color: edge.dst_arrowhead_label_color,
    src_anchor: edge.src_anchor,
    dst_anchor: edge.dst_anchor,
    label: edge.label,
    icon: edge.icon,
    icon_position: edge.icon_position,
    icon_border_radius: edge.icon_border_radius,
    link: edge.link,
    style: edge.style,
    route: normalize_route_like_d2(edge.route),
    bend_points: normalize_bend_points_like_d2(edge.bend_points),
    is_curve: edge.is_curve,
    z_index: edge.z_index,
    reference_count: edge.reference_count,
    label_box: edge.label_box,
    src_column_index: edge.src_column_index,
    dst_column_index: edge.dst_column_index,
  }
}

///|
fn sequence_connection_syntax_id(
  id : String,
  object_by_abs_id : Map[String, @graph.ObjectInput],
) -> String {
  let parts = @graph.split_syntax_path(id)
  let kept : Array[String] = []
  let prefix : Array[String] = []
  for part in parts {
    prefix.push(part)
    let abs_id = prefix.join(".")
    let is_group = match object_by_abs_id.get(abs_id) {
      Some(obj) => obj.classes.contains("__diago_sequence_group")
      None => false
    }
    if !is_group {
      kept.push(part)
    }
  }
  kept.join(".")
}

///|
fn sequence_participant_ids(graph : @graph.GraphInput) -> Array[String] {
  if !graph.root.child_ids.is_empty() {
    let ids : Array[String] = []
    let exists : Map[String, Bool] = Map([])
    for obj in graph.objects {
      exists[obj.abs_id_syntax] = true
    }
    for id in graph.root.child_ids {
      if exists.contains(id) {
        guard graph.find_object(id) is Some(obj) else { continue }
        if !obj.classes.contains("__diago_sequence_group") {
          ids.push(id)
        }
      }
    }
    if !ids.is_empty() {
      return ids
    }
  }
  let child_ids : Map[String, Bool] = Map([])
  for obj in graph.objects {
    for child_id in obj.child_ids {
      child_ids[child_id] = true
    }
  }
  let ids : Array[String] = []
  for obj in graph.objects {
    if !child_ids.contains(obj.abs_id_syntax) {
      ids.push(obj.abs_id_syntax)
    }
  }
  ids
}

///|
fn sequence_parent_id_by_child_id(
  graph : @graph.GraphInput,
) -> Map[String, String] {
  let out : Map[String, String] = Map([])
  for child_id in graph.root.child_ids {
    out[child_id] = graph.root.abs_id_syntax
  }
  for obj in graph.objects {
    for child_id in obj.child_ids {
      out[child_id] = obj.abs_id_syntax
    }
  }
  out
}

///|
fn sequence_participant_alias_by_abs_id(
  graph : @graph.GraphInput,
  participant_ids : Array[String],
  object_by_abs_id : Map[String, @graph.ObjectInput],
) -> Map[String, String] {
  let participant_by_local_id : Map[String, String] = Map([])
  for participant_id in participant_ids {
    match object_by_abs_id.get(participant_id) {
      Some(obj) => {
        participant_by_local_id[obj.id_val] = obj.abs_id_syntax
        participant_by_local_id[obj.id_syntax] = obj.abs_id_syntax
      }
      None => participant_by_local_id[participant_id] = participant_id
    }
  }
  let out : Map[String, String] = Map([])
  for participant_id in participant_ids {
    out[participant_id] = participant_id
  }
  for obj in graph.objects {
    if out.contains(obj.abs_id_syntax) {
      continue
    }
    match participant_by_local_id.get(obj.id_val) {
      Some(participant_id) => out[obj.abs_id_syntax] = participant_id
      None =>
        match participant_by_local_id.get(obj.id_syntax) {
          Some(participant_id) => out[obj.abs_id_syntax] = participant_id
          None => ()
        }
    }
  }
  out
}

///|
fn sequence_top_participant_id(
  id : String,
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  participant_alias_by_abs_id : Map[String, String],
) -> String {
  sequence_resolve_top_participant_id(
    id, id, participant_exists, parent_id_by_child_id, participant_alias_by_abs_id,
  )
}

///|
fn sequence_resolve_top_participant_id(
  current : String,
  fallback : String,
  participant_exists : Map[String, Bool],
  parent_id_by_child_id : Map[String, String],
  participant_alias_by_abs_id : Map[String, String],
) -> String {
  match participant_alias_by_abs_id.get(current) {
    Some(mapped_id) => mapped_id
    None =>
      if participant_exists.contains(current) {
        current
      } else {
        match parent_id_by_child_id.get(current) {
          Some(parent_id) =>
            sequence_resolve_top_participant_id(
              parent_id, fallback, participant_exists, parent_id_by_child_id, participant_alias_by_abs_id,
            )
          None => fallback
        }
      }
  }
}

///|
const D2_SEQUENCE_LIFELINE_STROKE_WIDTH : Int = 2

///|
const D2_SEQUENCE_LIFELINE_STROKE_DASH : Int = 6

///|
const D2_SEQUENCE_MESSAGE_Z_INDEX : Int = 4

///|
const D2_SEQUENCE_MIN_MESSAGE_DISTANCE : Double = 30.0

///|
const D2_SEQUENCE_VERTICAL_PAD : Double = 40.0

///|
const D2_SEQUENCE_LIFELINE_LABEL_PAD : Double = 5.0

///|
fn sequence_lifeline_start_y(
  graph : @graph.GraphInput,
  shape : Shape,
  box : @graph.Box,
) -> Double {
  let mut actor_bottom = box.y + box.height
  match graph.find_object(shape.id) {
    Some(obj) =>
      match obj.box {
        Some(raw_box) => actor_bottom = raw_box.y + raw_box.height
        None => ()
      }
    None => ()
  }
  if shape.label == "" {
    return actor_bottom
  }
  let outside_bottom = match shape.label_position {
    Some(position) => position.has_prefix("OUTSIDE_BOTTOM_")
    None => shape.shape_type == Person || shape.shape_type == Image
  }
  if outside_bottom {
    match shape.label_height {
      Some(height) =>
        actor_bottom = actor_bottom + height + D2_SEQUENCE_LIFELINE_LABEL_PAD
      None => ()
    }
  }
  actor_bottom
}

///|
fn sequence_lifeline_style(
  actor_style : @graph.StyleInput,
) -> @graph.StyleInput {
  let stroke_dash = match actor_style.stroke_dash {
    Some(v) => Some(v)
    None => Some(@graph.StyleValue::from_int(D2_SEQUENCE_LIFELINE_STROKE_DASH))
  }
  @graph.StyleInput::from_parts(
    None,
    match actor_style.stroke {
      Some(value) =>
        if value.get_value() == "B1" {
          Some(@graph.StyleValue::from_string("B2"))
        } else {
          Some(value)
        }
      None => Some(@graph.StyleValue::from_string("B2"))
    },
    None,
    Some(@graph.StyleValue::from_int(D2_SEQUENCE_LIFELINE_STROKE_WIDTH)),
    stroke_dash,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
    None,
  )
}

///|
fn append_sequence_lifeline_connections(
  graph : @graph.GraphInput,
  shapes : Array[Shape],
  connections : Array[Connection],
) -> Unit {
  if graph.root.shape_type != SequenceDiagram {
    return
  }

  let shape_by_id : Map[String, Shape] = Map([])
  for shape in shapes {
    shape_by_id[shape.id] = shape
  }

  let participant_ids = sequence_participant_ids(graph)
  if participant_ids.is_empty() {
    return
  }
  for i = 0; i < connections.length(); i = i + 1 {
    let conn = connections[i]
    if conn.z_index < D2_SEQUENCE_MESSAGE_Z_INDEX {
      connections[i] = { ..conn, z_index: D2_SEQUENCE_MESSAGE_Z_INDEX }
    }
  }

  let mut end_y = 0.0
  for conn in connections {
    for point in conn.route {
      if point.y > end_y {
        end_y = point.y
      }
    }
  }
  for note in graph.sequence_notes {
    let note_box = note.2
    let note_bottom = note_box.y + note_box.height
    if note_bottom > end_y {
      end_y = note_bottom
    }
  }

  for id in participant_ids {
    match shape_by_id.get(id) {
      Some(shape) =>
        match shape.box {
          Some(box) => {
            let actor_bottom = box.y + box.height
            if actor_bottom > end_y {
              end_y = actor_bottom
            }
          }
          None => ()
        }
      None => ()
    }
  }

  if end_y <= 0.0 {
    return
  }
  let lifeline_end_y = end_y +
    D2_SEQUENCE_MIN_MESSAGE_DISTANCE +
    D2_SEQUENCE_VERTICAL_PAD

  append_sequence_lifelines(
    graph, participant_ids, shape_by_id, lifeline_end_y, connections,
  )
}

///|
fn append_sequence_lifelines(
  graph : @graph.GraphInput,
  participant_ids : Array[String],
  shape_by_id : Map[String, Shape],
  lifeline_end_y : Double,
  connections : Array[Connection],
) -> Unit {
  let mut next_index = 0
  for conn in connections {
    if conn.index >= next_index {
      next_index = conn.index + 1
    }
  }

  for id in participant_ids {
    match shape_by_id.get(id) {
      Some(shape) =>
        match shape.box {
          Some(box) => {
            let start_y = sequence_lifeline_start_y(graph, shape, box)
            let x = box.x + box.width / 2.0
            let style = sequence_lifeline_style(shape.style)
            connections.push({
              index: next_index,
              src_id: id,
              dst_id: "",
              src_syntax_id: id,
              dst_syntax_id: "",
              src_lookup_id: id,
              dst_lookup_id: "",
              identity_scope_depth: @graph.syntax_path_depth(id),
              classes: [],
              src_arrow: false,
              dst_arrow: false,
              src_arrowhead: None,
              dst_arrowhead: None,
              src_arrowhead_label: None,
              dst_arrowhead_label: None,
              src_arrowhead_label_color: None,
              dst_arrowhead_label_color: None,
              src_anchor: None,
              dst_anchor: None,
              label: "",
              icon: None,
              icon_position: None,
              icon_border_radius: None,
              link: None,
              style,
              route: [
                @graph.Point::new(
                  truncate_float32_like_d2(truncate_decimals_like_d2(x)),
                  truncate_float32_like_d2(truncate_decimals_like_d2(start_y)),
                ),
                @graph.Point::new(
                  truncate_float32_like_d2(truncate_decimals_like_d2(x)),
                  lifeline_end_y,
                ),
              ],
              bend_points: None,
              is_curve: false,
              z_index: 1,
              reference_count: 1,
              label_box: None,
              src_column_index: None,
              dst_column_index: None,
            })
            next_index += 1
          }
          None => ()
        }
      None => ()
    }
  }
}

///|
fn nested_sequence_participant_for_endpoint(
  endpoint_id : String,
  participant_ids : Array[String],
) -> String? {
  let endpoint_parts = @graph.split_syntax_path(endpoint_id)
  for participant_id in participant_ids {
    let participant_key = @graph.syntax_path_last(participant_id).to_lower()
    for part in endpoint_parts {
      if part.to_lower() == participant_key {
        return Some(participant_id)
      }
    }
  }
  None
}

///|
fn append_nested_sequence_lifeline_connections(
  graph : @graph.GraphInput,
  shapes : Array[Shape],
  connections : Array[Connection],
  activation_ids : Map[String, Bool],
) -> Unit {
  if graph.root.shape_type == SequenceDiagram {
    return
  }
  let shape_by_id : Map[String, Shape] = Map([])
  for shape in shapes {
    shape_by_id[shape.id] = shape
  }
  for container in shapes {
    if container.shape_type != SequenceDiagram {
      continue
    }
    let participant_ids : Array[String] = []
    for id in container.child_ids {
      match shape_by_id.get(id) {
        Some(shape) =>
          if !shape.classes.contains("__diago_sequence_group") {
            participant_ids.push(id)
          }
        None => ()
      }
    }
    if participant_ids.is_empty() {
      continue
    }
    let container_box = match container.box {
      Some(box) => box
      None => continue
    }
    let descendant_ids : Map[String, Bool] = Map([])
    let queue : Array[String] = participant_ids.copy()
    let mut cursor = 0
    while cursor < queue.length() {
      let id = queue[cursor]
      cursor += 1
      if descendant_ids.contains(id) {
        continue
      }
      descendant_ids[id] = true
      match shape_by_id.get(id) {
        Some(shape) =>
          for child_id in shape.child_ids {
            queue.push(child_id)
          }
        None => ()
      }
    }

    let mut end_y = 0.0
    for i = 0; i < connections.length(); i = i + 1 {
      let connection = connections[i]
      let endpoints_inside = if connection.route.is_empty() {
        false
      } else {
        let first = connection.route[0]
        let last = connection.route[connection.route.length() - 1]
        first.x >= container_box.x &&
        first.y >= container_box.y &&
        first.x <= container_box.x + container_box.width &&
        first.y <= container_box.y + container_box.height &&
        last.x >= container_box.x &&
        last.y >= container_box.y &&
        last.x <= container_box.x + container_box.width &&
        last.y <= container_box.y + container_box.height
      }
      let semantic_descendants = descendant_ids.contains(
          connection.src_lookup_id,
        ) &&
        descendant_ids.contains(connection.dst_lookup_id)
      if !semantic_descendants && !endpoints_inside {
        continue
      }
      let src_participant = nested_sequence_participant_for_endpoint(
        connection.src_lookup_id,
        participant_ids,
      )
      let dst_participant = nested_sequence_participant_for_endpoint(
        connection.dst_lookup_id,
        participant_ids,
      )
      let normalized_connection = match (src_participant, dst_participant) {
        (Some(src), Some(dst)) =>
          {
            ..connection,
            src_id: if activation_ids.contains(connection.src_lookup_id) {
              connection.src_id
            } else {
              src
            },
            dst_id: if activation_ids.contains(connection.dst_lookup_id) {
              connection.dst_id
            } else {
              dst
            },
            src_lookup_id: if activation_ids.contains(connection.src_lookup_id) {
              connection.src_lookup_id
            } else {
              src
            },
            dst_lookup_id: if activation_ids.contains(connection.dst_lookup_id) {
              connection.dst_lookup_id
            } else {
              dst
            },
            z_index: if connection.z_index < D2_SEQUENCE_MESSAGE_Z_INDEX {
              D2_SEQUENCE_MESSAGE_Z_INDEX
            } else {
              connection.z_index
            },
          }
        _ =>
          if connection.z_index < D2_SEQUENCE_MESSAGE_Z_INDEX {
            { ..connection, z_index: D2_SEQUENCE_MESSAGE_Z_INDEX }
          } else {
            connection
          }
      }
      connections[i] = normalized_connection
      for point in connection.route {
        if point.y > end_y {
          end_y = point.y
        }
      }
    }
    for participant_id in participant_ids {
      match shape_by_id.get(participant_id) {
        Some(shape) =>
          match shape.box {
            Some(box) =>
              if box.y + box.height > end_y {
                end_y = box.y + box.height
              }
            None => ()
          }
        None => ()
      }
    }
    for note in graph.sequence_notes {
      let note_box = note.2
      if note_box.x >= container_box.x &&
        note_box.y >= container_box.y &&
        note_box.x + note_box.width <= container_box.x + container_box.width &&
        note_box.y + note_box.height <= container_box.y + container_box.height &&
        note_box.y + note_box.height > end_y {
        end_y = note_box.y + note_box.height
      }
    }
    if end_y <= 0.0 {
      continue
    }
    append_sequence_lifelines(
      graph,
      participant_ids,
      shape_by_id,
      end_y + D2_SEQUENCE_MIN_MESSAGE_DISTANCE + D2_SEQUENCE_VERTICAL_PAD,
      connections,
    )
  }
}

///|
/// Convert a laid-out graph to a render-ready diagram.
///
/// This is the only conversion renderers should need.
pub fn from_graph(graph : @graph.GraphInput, config : Config?) -> Diagram {
  let shapes : Array[Shape] = []
  let hidden_sequence_aliases : Map[String, Bool] = Map([])
  let sequence_aliases : Map[String, String] = Map([])
  let sequence_parents : Map[String, String] = Map([])
  if graph.root.shape_type == SequenceDiagram {
    let object_by_abs_id : Map[String, @graph.ObjectInput] = Map([])
    for obj in graph.objects {
      object_by_abs_id[obj.abs_id_syntax] = obj
    }
    let participant_ids = sequence_participant_ids(graph)
    let participant_set : Map[String, Bool] = Map([])
    for id in participant_ids {
      participant_set[id] = true
    }
    let aliases = sequence_participant_alias_by_abs_id(
      graph, participant_ids, object_by_abs_id,
    )
    for id, participant_id in aliases {
      sequence_aliases[id] = participant_id
    }
    let parents = sequence_parent_id_by_child_id(graph)
    for id, parent in parents {
      sequence_parents[id] = parent
    }
    for obj in graph.objects {
      if !participant_set.contains(obj.abs_id_syntax) &&
        aliases.contains(obj.abs_id_syntax) &&
        !obj.child_ids.is_empty() {
        hidden_sequence_aliases[obj.abs_id_syntax] = true
      }
    }
  }
  let activation_ids : Map[String, Bool] = Map([])
  for activation in graph.activation_boxes {
    activation_ids[activation.0] = true
  }
  for obj in graph.objects {
    if hidden_sequence_aliases.contains(obj.abs_id_syntax) {
      continue
    }
    let base_shape = shape_from_object(obj)
    let shape = if obj.classes.contains("__diago_sequence_note") {
      let mut current = obj.abs_id_syntax
      let mut render_id = obj.abs_id_syntax
      while true {
        match sequence_parents.get(current) {
          Some(parent) =>
            match sequence_aliases.get(parent) {
              Some(participant_id) => {
                render_id = participant_id + "." + obj.id_syntax
                break
              }
              None => current = parent
            }
          None => break
        }
      }
      { ..base_shape, id: render_id }
    } else {
      base_shape
    }
    shapes.push(
      if activation_ids.contains(obj.abs_id_syntax) {
        {
          ..shape,
          label: "",
          label_width: None,
          label_height: None,
          z_index: 2,
        }
      } else if shape.classes.contains("__diago_sequence_group") {
        { ..shape, z_index: 3 }
      } else if shape.classes.contains("__diago_sequence_note") {
        { ..shape, z_index: 5 }
      } else {
        shape
      },
    )
  }
  let connections : Array[Connection] = []
  if graph.root.shape_type == SequenceDiagram {
    let object_by_abs_id : Map[String, @graph.ObjectInput] = Map([])
    for obj in graph.objects {
      object_by_abs_id[obj.abs_id_syntax] = obj
    }
    let participant_ids = sequence_participant_ids(graph)
    let participant_exists : Map[String, Bool] = Map([])
    for participant_id in participant_ids {
      participant_exists[participant_id] = true
    }
    let parent_id_by_child_id = sequence_parent_id_by_child_id(graph)
    let participant_alias_by_abs_id = sequence_participant_alias_by_abs_id(
      graph, participant_ids, object_by_abs_id,
    )
    for edge in graph.edges {
      let src_lookup_id = sequence_top_participant_id(
        edge.src_id_syntax,
        participant_exists,
        parent_id_by_child_id,
        participant_alias_by_abs_id,
      )
      let dst_lookup_id = sequence_top_participant_id(
        edge.dst_id_syntax,
        participant_exists,
        parent_id_by_child_id,
        participant_alias_by_abs_id,
      )
      let src_display_id = if activation_ids.contains(edge.src_id_syntax) {
        edge.src_id
      } else {
        src_lookup_id
      }
      let dst_display_id = if activation_ids.contains(edge.dst_id_syntax) {
        edge.dst_id
      } else {
        dst_lookup_id
      }
      let src_syntax_id = sequence_connection_syntax_id(
        edge.src_id_syntax,
        object_by_abs_id,
      )
      let dst_syntax_id = sequence_connection_syntax_id(
        edge.dst_id_syntax,
        object_by_abs_id,
      )
      connections.push(
        connection_from_edge(
          edge,
          src_id=src_display_id,
          dst_id=dst_display_id,
          src_syntax_id~,
          dst_syntax_id~,
          src_lookup_id~,
          dst_lookup_id~,
          identity_scope_depth=@graph.syntax_path_depth(edge.src_id_syntax),
        ),
      )
    }
  } else {
    let object_by_abs_id : Map[String, @graph.ObjectInput] = Map([])
    for obj in graph.objects {
      object_by_abs_id[obj.abs_id_syntax] = obj
    }
    for edge in graph.edges {
      let src_syntax_id = sequence_connection_syntax_id(
        edge.src_id_syntax,
        object_by_abs_id,
      )
      let dst_syntax_id = sequence_connection_syntax_id(
        edge.dst_id_syntax,
        object_by_abs_id,
      )
      connections.push(
        connection_from_edge(
          edge,
          src_syntax_id~,
          dst_syntax_id~,
          identity_scope_depth=@graph.syntax_path_depth(edge.src_id_syntax),
        ),
      )
    }
  }
  append_sequence_lifeline_connections(graph, shapes, connections)
  append_nested_sequence_lifeline_connections(
    graph, shapes, connections, activation_ids,
  )
  let layers : Array[Diagram] = []
  for layer in graph.layers {
    layers.push(from_graph(layer.graph, config))
  }
  let scenarios : Array[Diagram] = []
  for scenario in graph.scenarios {
    scenarios.push(from_graph(scenario.graph, config))
  }
  let steps : Array[Diagram] = []
  for step in graph.steps {
    steps.push(from_graph(step.graph, config))
  }
  {
    name: graph.name,
    config,
    is_folder_only: graph.is_folder_only,
    description: "",
    font_family: None,
    mono_font_family: None,
    root: shape_from_object(graph.root),
    shapes,
    connections,
    activation_boxes: graph.activation_boxes,
    sequence_notes: graph.sequence_notes,
    sequence_fragments: graph.sequence_fragments_layout,
    layers,
    scenarios,
    steps,
    legend: graph.legend,
  }
}
