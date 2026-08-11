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
priv struct AttributeSpan {
  value_start : Int
  value_end : Int
}

///|
priv enum BundleScope {
  Local
  Remote
}

///|
priv struct SvgBundleResult {
  svg : String
  error : String?
}

///|
priv struct ImageTagBundleResult {
  tag : String
  error_href : String?
}

///|
let max_bundle_image_size : Int = 1 << 25

///|
let max_remote_redirects : Int = 5

///|
let remote_fetch_timeout_ms : Int = 20_000

///|
let persistent_bundle_cache : Map[String, String] = Map([])

///|
// Whitebox tests use these maps to mirror the mockable reference HTTP transport.
let test_remote_fetch_ok_overrides : Map[String, (Bytes, String)] = Map([])

///|
let test_remote_fetch_error_overrides : Map[String, String] = Map([])

///|
let test_remote_fetch_count : Map[String, Int] = Map([])

///|
async fn bundle_local_svg_images(
  svg : String,
  base_path : String?,
  cache_images? : Bool = false,
) -> SvgBundleResult {
  bundle_svg_images_in_scope(svg, base_path, Local, cache_images)
}

///|
async fn bundle_remote_svg_images(
  svg : String,
  cache_images? : Bool = false,
) -> SvgBundleResult {
  let remote_fetches : Map[String, Result[(Bytes, String), String]] = Map([])
  for source in collect_remote_image_sources(svg) {
    let key = bundle_cache_key(source, None)
    if lookup_persistent_bundle_cache(key, cache_images) is None {
      remote_fetches[source] = fetch_remote_image_bytes(source)
    }
  }
  bundle_svg_images_in_scope(svg, None, Remote, cache_images, remote_fetches~)
}

///|
fn collect_remote_image_sources(svg : String) -> Array[String] {
  let sources : Array[String] = []
  let seen : Set[String] = Set([])
  let mut cursor = 0
  while cursor < svg.length() {
    let image_start = match find_substring_from(svg, "<image", cursor) {
      Some(i) => i
      None => break
    }
    let image_end = match find_tag_end(svg, image_start + 6) {
      Some(i) => i
      None => break
    }
    let tag = slice_string(svg, image_start, image_end + 1)
    match read_image_href(tag) {
      Some(value) => {
        let source = normalize_source_reference(
          decode_xml_attr_entities(value).trim().to_owned(),
        )
        if is_http_source(source) && !seen.contains(source) {
          seen.add(source)
          sources.push(source)
        }
      }
      None => ()
    }
    cursor = image_end + 1
  }
  sources
}

///|
async fn bundle_svg_images_in_scope(
  svg : String,
  base_path : String?,
  scope : BundleScope,
  cache_images : Bool,
  remote_fetches? : Map[String, Result[(Bytes, String), String]] = Map([]),
) -> SvgBundleResult {
  let cache : Array[(String, String)] = []
  let failed_cache : Array[(String, String)] = []
  let error_hrefs : Array[String] = []
  let out = StringBuilder::new()
  let mut cursor = 0
  while cursor < svg.length() {
    let image_start = match find_substring_from(svg, "<image", cursor) {
      Some(i) => i
      None => {
        out.write_string(slice_string(svg, cursor, svg.length()))
        break
      }
    }
    out.write_string(slice_string(svg, cursor, image_start))
    let image_end = match find_tag_end(svg, image_start + 6) {
      Some(i) => i
      None => {
        out.write_string(slice_string(svg, image_start, svg.length()))
        break
      }
    }
    let tag = slice_string(svg, image_start, image_end + 1)
    let bundled = bundle_image_tag(
      tag, base_path, scope, cache, failed_cache, cache_images, remote_fetches,
    )
    out.write_string(bundled.tag)
    match bundled.error_href {
      Some(href) => error_hrefs.push(href)
      None => ()
    }
    cursor = image_end + 1
  }
  { svg: out.to_string(), error: bundle_scope_error(scope, error_hrefs) }
}

///|
async fn bundle_image_tag(
  tag : String,
  base_path : String?,
  scope : BundleScope,
  cache : Array[(String, String)],
  failed_cache : Array[(String, String)],
  cache_images : Bool,
  remote_fetches : Map[String, Result[(Bytes, String), String]],
) -> ImageTagBundleResult {
  let href_raw = match read_image_href(tag) {
    Some(value) => value
    None => return { tag, error_href: None }
  }
  let href = decode_xml_attr_entities(href_raw).trim().to_owned()
  if href == "" || href.has_prefix("data:") {
    return { tag, error_href: None }
  }
  let normalized = normalize_source_reference(href)
  let is_remote = is_http_source(normalized)
  match scope {
    Local => if is_remote { return { tag, error_href: None } }
    Remote => if !is_remote { return { tag, error_href: None } }
  }
  let key = bundle_cache_key(normalized, base_path)
  if lookup_bundle_failure_cache(failed_cache, key) is Some(_) {
    return { tag, error_href: None }
  }
  let data_uri = match lookup_bundle_cache(cache, key) {
    Some(uri) => Some(uri)
    None =>
      match lookup_persistent_bundle_cache(key, cache_images) {
        Some(uri) => {
          cache.push((key, uri))
          Some(uri)
        }
        None =>
          match build_image_data_uri(normalized, base_path, remote_fetches) {
            Ok(v) => {
              cache.push((key, v))
              store_persistent_bundle_cache(key, v, cache_images)
              Some(v)
            }
            Err(_) => {
              failed_cache.push((key, normalized))
              None
            }
          }
      }
  }
  match data_uri {
    Some(uri) => { tag: apply_bundled_href(tag, uri), error_href: None }
    None => { tag, error_href: Some(normalized) }
  }
}

///|
fn read_image_href(tag : String) -> String? {
  match read_attr_value(tag, "href") {
    Some(v) => Some(v)
    None => read_attr_value(tag, "xlink:href")
  }
}

///|
fn apply_bundled_href(tag : String, data_uri : String) -> String {
  let mut out = tag
  if read_attr_value(out, "href") is Some(_) {
    out = set_attr_value(out, "href", data_uri)
  }
  if read_attr_value(out, "xlink:href") is Some(_) {
    out = set_attr_value(out, "xlink:href", data_uri)
  }
  out
}

///|
fn set_attr_value(tag : String, name : String, value : String) -> String {
  match find_attr_span(tag, name) {
    Some(span) =>
      slice_string(tag, 0, span.value_start) +
      value +
      slice_string(tag, span.value_end, tag.length())
    None => tag
  }
}

///|
fn read_attr_value(tag : String, name : String) -> String? {
  match find_attr_span(tag, name) {
    Some(span) => Some(slice_string(tag, span.value_start, span.value_end))
    None => None
  }
}

///|
fn find_attr_span(tag : String, name : String) -> AttributeSpan? {
  let mut i = 0
  while i < tag.length() {
    let ch = char_at(tag, i)
    if is_space(ch) || ch == '<' || ch == '>' || ch == '/' {
      i = i + 1
      continue
    }
    if ch == '"' || ch == '\'' {
      i = skip_quoted(tag, i + 1, ch)
      continue
    }
    let name_start = i
    while i < tag.length() && is_attr_name_char(char_at(tag, i)) {
      i = i + 1
    }
    if i == name_start {
      i = i + 1
      continue
    }
    let attr_name = slice_string(tag, name_start, i)
    while i < tag.length() && is_space(char_at(tag, i)) {
      i = i + 1
    }
    if i >= tag.length() || char_at(tag, i) != '=' {
      continue
    }
    i = i + 1
    while i < tag.length() && is_space(char_at(tag, i)) {
      i = i + 1
    }
    if i >= tag.length() {
      break
    }
    let quote = char_at(tag, i)
    if quote != '"' && quote != '\'' {
      while i < tag.length() {
        let c = char_at(tag, i)
        if is_space(c) || c == '>' {
          break
        }
        i = i + 1
      }
      continue
    }
    let value_start = i + 1
    i = value_start
    while i < tag.length() && char_at(tag, i) != quote {
      i = i + 1
    }
    if i >= tag.length() {
      break
    }
    let value_end = i
    i = i + 1
    if attr_name == name {
      return Some({ value_start, value_end })
    }
  }
  None
}

///|
fn skip_quoted(s : String, start : Int, quote : Char) -> Int {
  let mut i = start
  while i < s.length() {
    if char_at(s, i) == quote {
      return i + 1
    }
    i = i + 1
  }
  i
}

///|
fn bundle_cache_key(source : String, base_path : String?) -> String {
  if is_http_source(source) {
    source
  } else {
    resolve_local_image_path(source, base_path)
  }
}

///|
fn lookup_bundle_cache(
  cache : Array[(String, String)],
  key : String,
) -> String? {
  for entry in cache {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn lookup_bundle_failure_cache(
  cache : Array[(String, String)],
  key : String,
) -> String? {
  for entry in cache {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn lookup_persistent_bundle_cache(key : String, cache_images : Bool) -> String? {
  if cache_images {
    persistent_bundle_cache.get(key)
  } else {
    None
  }
}

///|
fn store_persistent_bundle_cache(
  key : String,
  data_uri : String,
  cache_images : Bool,
) -> Unit {
  if cache_images {
    persistent_bundle_cache[key] = data_uri
  }
}

///|
async fn build_image_data_uri(
  source : String,
  base_path : String?,
  remote_fetches : Map[String, Result[(Bytes, String), String]],
) -> Result[String, String] {
  let normalized = normalize_source_reference(source)
  let (bytes, mime_type) = if is_http_source(normalized) {
    let (remote_bytes, remote_content_type) = match
      remote_fetches.get(normalized) {
      Some(Ok(v)) => v
      Some(Err(e)) => return Err(e)
      None =>
        return Err("remote image '\{normalized}' was not prepared for bundling")
    }
    (
      remote_bytes,
      resolve_bundle_mime_type(normalized, remote_bytes, remote_content_type),
    )
  } else {
    let path = resolve_local_image_path(normalized, base_path)
    let bytes = @fs.read_file(path).binary() catch {
      error => return Err("failed to read image file '\{path}': \{error}")
    }
    (bytes, resolve_bundle_mime_type(path, bytes, ""))
  }
  let encoded = @base64.encode(bytes)
  Ok("data:\{mime_type};base64,\{encoded}")
}

///|
fn bundle_scope_error(
  scope : BundleScope,
  error_hrefs : Array[String],
) -> String? {
  if error_hrefs.is_empty() {
    return None
  }
  let scope_name = match scope {
    Local => "local"
    Remote => "remote"
  }
  Some(
    "failed to bundle " +
    scope_name +
    " images: " +
    format_bundle_error_hrefs(error_hrefs),
  )
}

///|
fn format_bundle_error_hrefs(error_hrefs : Array[String]) -> String {
  if error_hrefs.is_empty() {
    return "[]"
  }
  let out = StringBuilder::new()
  out.write_char('[')
  let mut first = true
  for href in error_hrefs {
    if first {
      first = false
    } else {
      out.write_char(' ')
    }
    out.write_string(href)
  }
  out.write_char(']')
  out.to_string()
}

///|
fn resolve_bundle_mime_type(
  source_hint : String,
  bytes : Bytes,
  provided_content_type : String,
) -> String {
  let mime_type = if provided_content_type.trim() != "" {
    provided_content_type.trim().to_owned()
  } else {
    detect_mime_type(source_hint, bytes)
  }
  let adjusted = mime_type.replace(old="text/xml", new="image/svg+xml")
  if adjusted == "application/octet-stream" && bytes_contains_svg(bytes) {
    "image/svg+xml"
  } else {
    adjusted
  }
}

///|
async fn fetch_remote_image_bytes(
  url : String,
) -> Result[(Bytes, String), String] {
  match fetch_remote_image_bytes_override(url) {
    Some(result) => return result
    None => ()
  }
  for current = url, redirects = 0 {
    let fetched = @async.with_timeout(remote_fetch_timeout_ms, () => {
      let proxy = match remote_proxy_url(current) {
        Some(proxy_url) => Some(@http.Client(proxy_url))
        None => None
      }
      let (response, client) = @http.get_stream(
        current,
        headers={
          "User-Agent": "diago/\{CLI_VERSION}",
          "Accept": "image/svg+xml,image/*,*/*;q=0.8",
        },
        proxy?,
      )
      defer client.close()
      let body = if response.code >= 200 && response.code < 300 {
        read_remote_image_body(client, current)
      } else {
        Ok(b"")
      }
      (response, body)
    }) catch {
      e => return Err("failed to fetch image '\{current}': \{e}")
    }
    let (response, body) = fetched
    if response.code >= 300 && response.code < 400 {
      if redirects >= max_remote_redirects {
        return Err("failed to fetch image '\{url}': too many redirects")
      }
      let location = match response.headers.get("location") {
        Some(value) => value
        None =>
          return Err(
            "failed to fetch image '\{current}': redirect response \{response.code} has no Location header",
          )
      }
      let next = match resolve_remote_redirect(current, location) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      continue next, redirects + 1
    }
    if response.code < 200 || response.code >= 300 {
      return Err(
        "failed to fetch image '\{current}': HTTP \{response.code} \{response.reason}",
      )
    }
    let bytes = match body {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let content_type = response.headers.get("content-type").unwrap_or("")
    return Ok((bytes, content_type))
  }
}

///|
async fn read_remote_image_body(
  reader : &@io.Reader,
  url : String,
) -> Result[Bytes, String] {
  let buffer = @buffer.Buffer(size_hint=4096)
  while reader.read_some(max_len=64 * 1024) is Some(chunk) {
    if buffer.length() + chunk.length() > max_bundle_image_size {
      return Err(
        "fetched image '\{url}' exceeds max size \{max_bundle_image_size} bytes",
      )
    }
    buffer.write_bytes(chunk)
  }
  Ok(buffer.to_bytes())
}

///|
fn remote_proxy_url(url : String) -> String? {
  if remote_url_bypasses_proxy(url) {
    return None
  }
  let proxy = if url.to_lower().has_prefix("https://") {
    first_non_empty_env([
      "HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy",
    ])
  } else {
    first_non_empty_env(["HTTP_PROXY", "http_proxy"])
  }
  match proxy {
    Some(value) =>
      if value.contains("://") {
        Some(value)
      } else {
        Some("http://" + value)
      }
    None => None
  }
}

///|
fn first_non_empty_env(names : Array[String]) -> String? {
  for name in names {
    match @env.get_env_var(name) {
      Some(value) if value.trim() != "" => return Some(value.trim().to_owned())
      _ => ()
    }
  }
  None
}

///|
fn remote_url_bypasses_proxy(url : String) -> Bool {
  let host = match remote_url_host(url) {
    Some(value) => value.to_lower()
    None => return false
  }
  if host == "localhost" || host == "127.0.0.1" || host == "::1" {
    return true
  }
  let no_proxy = match first_non_empty_env(["NO_PROXY", "no_proxy"]) {
    Some(value) => value
    None => return false
  }
  for raw_rule in no_proxy.split(",") {
    let rule = raw_rule.trim().to_owned().to_lower()
    if rule == "*" {
      return true
    }
    if rule == "" {
      continue
    }
    let host_rule = strip_proxy_rule_port(rule)
    let suffix = if host_rule.has_prefix(".") {
      host_rule
    } else {
      "." + host_rule
    }
    if host == host_rule || host.has_suffix(suffix) {
      return true
    }
  }
  false
}

///|
fn strip_proxy_rule_port(rule : String) -> String {
  if rule.has_prefix("[") {
    match rule.find("]") {
      Some(end) => return slice_string(rule, 1, end)
      None => return rule
    }
  }
  match rule.find(":") {
    Some(colon) => slice_string(rule, 0, colon)
    None => rule
  }
}

///|
fn remote_url_host(url : String) -> String? {
  let scheme_end = match url.find("://") {
    Some(index) => index
    None => return None
  }
  let authority_start = scheme_end + 3
  let authority_end = find_url_authority_end(url, authority_start)
  let authority = slice_string(url, authority_start, authority_end)
  let mut host_start = 0
  for i in 0..<authority.length() {
    if char_at(authority, i) == '@' {
      host_start = i + 1
    }
  }
  let host_port = slice_string(authority, host_start, authority.length())
  if host_port.has_prefix("[") {
    match host_port.find("]") {
      Some(end) => Some(slice_string(host_port, 1, end))
      None => None
    }
  } else {
    match host_port.find(":") {
      Some(colon) => Some(slice_string(host_port, 0, colon))
      None => Some(host_port)
    }
  }
}

///|
fn resolve_remote_redirect(
  current : String,
  location_raw : String,
) -> Result[String, String] {
  let location = location_raw.trim().to_owned()
  if location == "" {
    return Err("failed to fetch image '\{current}': redirect Location is empty")
  }
  if is_http_source(location) {
    return Ok(location)
  }
  let scheme_end = match current.find("://") {
    Some(index) => index
    None =>
      return Err("failed to resolve redirect from invalid URL '\{current}'")
  }
  let scheme = slice_string(current, 0, scheme_end)
  if location.has_prefix("//") {
    return Ok(scheme + ":" + location)
  }
  let authority_start = scheme_end + 3
  let authority_end = find_url_authority_end(current, authority_start)
  let origin = slice_string(current, 0, authority_end)
  if location.has_prefix("/") {
    return Ok(origin + location)
  }
  let current_without_fragment = match current.find("#") {
    Some(index) => slice_string(current, 0, index)
    None => current
  }
  if location.has_prefix("?") {
    let base = match current_without_fragment.find("?") {
      Some(index) => slice_string(current_without_fragment, 0, index)
      None => current_without_fragment
    }
    return Ok(base + location)
  }
  if location.has_prefix("#") {
    return Ok(current_without_fragment + location)
  }
  let current_without_query = match current_without_fragment.find("?") {
    Some(index) => slice_string(current_without_fragment, 0, index)
    None => current_without_fragment
  }
  let mut slash = authority_end
  for i in authority_end..<current_without_query.length() {
    if char_at(current_without_query, i) == '/' {
      slash = i
    }
  }
  let base = if slash == current_without_query.length() {
    current_without_query + "/"
  } else {
    slice_string(current_without_query, 0, slash + 1)
  }
  Ok(base + location)
}

///|
fn find_url_authority_end(url : String, start : Int) -> Int {
  for i in start..<url.length() {
    let c = char_at(url, i)
    if c == '/' || c == '?' || c == '#' {
      return i
    }
  }
  url.length()
}

///|
fn fetch_remote_image_bytes_override(
  url : String,
) -> Result[(Bytes, String), String]? {
  match test_remote_fetch_ok_overrides.get(url) {
    Some((bytes, content_type)) => {
      test_remote_fetch_count[url] = test_remote_fetch_count.get_or_default(
          url, 0,
        ) +
        1
      if bytes.length() > max_bundle_image_size {
        Some(
          Err(
            "fetched image '\{url}' exceeds max size \{max_bundle_image_size} bytes",
          ),
        )
      } else {
        Some(Ok((bytes, content_type)))
      }
    }
    None =>
      match test_remote_fetch_error_overrides.get(url) {
        Some(message) => {
          test_remote_fetch_count[url] = test_remote_fetch_count.get_or_default(
              url, 0,
            ) +
            1
          Some(Err(message))
        }
        None => None
      }
  }
}

///|
fn resolve_local_image_path(source : String, base_path : String?) -> String {
  let normalized = normalize_source_reference(source)
  if @path.Path(normalized).is_absolute() {
    return @path.Path(normalized).normalize().to_string()
  }
  match base_path {
    Some(base) =>
      @path.Path(base).join(Path(normalized)).normalize().to_string()
    None => @path.Path(normalized).normalize().to_string()
  }
}

///|
fn normalize_source_reference(source : String) -> String {
  if source.has_prefix("file://") {
    if source.has_prefix("file:///") {
      return slice_string(source, 7, source.length())
    }
    return slice_string(source, 7, source.length())
  }
  source
}

///|
fn detect_mime_type(source_hint : String, bytes : Bytes) -> String {
  let lower = strip_query_and_fragment(source_hint).to_lower()
  if lower.has_suffix(".svg") || lower.has_suffix(".svgz") {
    "image/svg+xml"
  } else if lower.has_suffix(".png") {
    "image/png"
  } else if lower.has_suffix(".jpg") || lower.has_suffix(".jpeg") {
    "image/jpeg"
  } else if lower.has_suffix(".gif") {
    "image/gif"
  } else if lower.has_suffix(".webp") {
    "image/webp"
  } else if lower.has_suffix(".bmp") {
    "image/bmp"
  } else if lower.has_suffix(".ico") {
    "image/x-icon"
  } else if bytes_contains_svg(bytes) {
    "image/svg+xml"
  } else if bytes_has_prefix(bytes, [0x89, 0x50, 0x4e, 0x47]) {
    "image/png"
  } else if bytes_has_prefix(bytes, [0xff, 0xd8, 0xff]) {
    "image/jpeg"
  } else if bytes_has_prefix_ascii(bytes, "GIF87a") ||
    bytes_has_prefix_ascii(bytes, "GIF89a") {
    "image/gif"
  } else if bytes_has_prefix_ascii(bytes, "RIFF") &&
    bytes_window_equals_ascii(bytes, 8, "WEBP") {
    "image/webp"
  } else if bytes_has_prefix_ascii(bytes, "BM") {
    "image/bmp"
  } else if bytes_has_prefix(bytes, [0x00, 0x00, 0x01, 0x00]) {
    "image/x-icon"
  } else {
    "application/octet-stream"
  }
}

///|
fn bytes_has_prefix(bytes : Bytes, prefix : Array[Int]) -> Bool {
  if bytes.length() < prefix.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if bytes[i].to_int() != prefix[i] {
      return false
    }
  }
  true
}

///|
fn bytes_has_prefix_ascii(bytes : Bytes, text : String) -> Bool {
  if bytes.length() < text.length() {
    return false
  }
  for i in 0..<text.length() {
    if bytes[i].to_int() != text.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
fn bytes_window_equals_ascii(bytes : Bytes, start : Int, text : String) -> Bool {
  if start < 0 || bytes.length() < start + text.length() {
    return false
  }
  for i in 0..<text.length() {
    if bytes[start + i].to_int() != text.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
fn bytes_contains_svg(bytes : Bytes) -> Bool {
  if bytes.length() < 4 {
    return false
  }
  for i in 0..<(bytes.length() - 3) {
    if bytes[i].to_int() == '<'.to_int() &&
      bytes[i + 1].to_int() == 's'.to_int() &&
      bytes[i + 2].to_int() == 'v'.to_int() &&
      bytes[i + 3].to_int() == 'g'.to_int() {
      return true
    }
  }
  false
}

///|
fn strip_query_and_fragment(s : String) -> String {
  for i in 0..<s.length() {
    let c = char_at(s, i)
    if c == '?' || c == '#' {
      return slice_string(s, 0, i)
    }
  }
  s
}

///|
fn is_http_source(source : String) -> Bool {
  let lower = source.to_lower()
  lower.has_prefix("http://") || lower.has_prefix("https://")
}

///|
fn decode_xml_attr_entities(s : String) -> String {
  s
  .replace(old="&amp;", new="&")
  .replace(old="&quot;", new="\"")
  .replace(old="&apos;", new="'")
  .replace(old="&lt;", new="<")
  .replace(old="&gt;", new=">")
}

///|
fn find_tag_end(s : String, start : Int) -> Int? {
  let mut i = start
  let mut in_quote = '\u0000'
  while i < s.length() {
    let c = char_at(s, i)
    if in_quote != '\u0000' {
      if c == in_quote {
        in_quote = '\u0000'
      }
    } else if c == '"' || c == '\'' {
      in_quote = c
    } else if c == '>' {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn find_substring_from(s : String, pattern : String, start : Int) -> Int? {
  if pattern.length() == 0 {
    return Some(start)
  }
  if pattern.length() > s.length() {
    return None
  }
  let limit = s.length() - pattern.length()
  let mut i = if start < 0 { 0 } else { start }
  while i <= limit {
    let mut matched = true
    for j in 0..<pattern.length() {
      if s.code_unit_at(i + j) != pattern.code_unit_at(j) {
        matched = false
        break
      }
    }
    if matched {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn slice_string(s : String, start : Int, end_exclusive : Int) -> String {
  let sb = StringBuilder::new()
  let mut i = start
  while i < end_exclusive {
    sb.write_char(char_at(s, i))
    i = i + 1
  }
  sb.to_string()
}

///|
fn is_attr_name_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_' ||
  c == ':' ||
  c == '.'
}

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn char_at(s : String, i : Int) -> Char {
  s.code_unit_at(i).to_int().unsafe_to_char()
}

///|
