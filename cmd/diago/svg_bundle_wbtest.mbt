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
async test "bundle local image href to data uri" {
  let icon_path = ".diago_bundle_test_icon.svg"
  remove_test_file(icon_path)
  let icon_svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>
  @fs.write_file(icon_path, icon_svg, create_mode=CreateOrTruncate)
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href=".diago_bundle_test_icon.svg" x="0" y="0" width="1" height="1"/></svg>
  let bundled = bundle_local_svg_images(svg, Some("."))
  remove_test_file(icon_path)
  @debug.assert_eq(bundled.error, None)
  assert_true(bundled.svg.contains("data:image/svg+xml;base64,"))
  assert_false(bundled.svg.contains("href=\".diago_bundle_test_icon.svg\""))
}

///|
async test "bundle updates href and xlink:href together" {
  let icon_path = ".diago_bundle_test_icon_xlink.svg"
  remove_test_file(icon_path)
  let icon_svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>
  @fs.write_file(icon_path, icon_svg, create_mode=CreateOrTruncate)
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href=".diago_bundle_test_icon_xlink.svg" xlink:href=".diago_bundle_test_icon_xlink.svg"/></svg>
  let bundled = bundle_local_svg_images(svg, Some("."))
  remove_test_file(icon_path)
  @debug.assert_eq(bundled.error, None)
  assert_true(bundled.svg.contains("href=\"data:image/svg+xml;base64,"))
  assert_true(bundled.svg.contains("xlink:href=\"data:image/svg+xml;base64,"))
}

///|
async test "bundle keeps pre-bundled data uri unchanged" {
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="data:image/png;base64,AAAA"/></svg>
  let bundled = bundle_local_svg_images(svg, Some("."))
  @debug.assert_eq(bundled.error, None)
  @debug.assert_eq(bundled.svg, svg)
}

///|
async test "bundle local image resolves relative paths from base path" {
  let dir = ".diago_bundle_nested"
  let icon_path = dir + "/test_svg.svg"
  let icon_svg =
    #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>
  remove_test_file(icon_path)
  remove_test_dir(dir)
  @fs.mkdir(dir)
  @fs.write_file(icon_path, icon_svg, create_mode=CreateOrTruncate)
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="./test_svg.svg"/></svg>
  let bundled = bundle_local_svg_images(svg, Some(dir))
  remove_test_file(icon_path)
  remove_test_dir(dir)
  @debug.assert_eq(bundled.error, None)
  assert_true(bundled.svg.contains("data:image/svg+xml;base64,"))
}

///|
async test "bundle local image keeps svg and reports invalid relative base path" {
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="./missing.svg"/></svg>
  let bundled = bundle_local_svg_images(svg, Some(".diago_missing_bundle_dir"))
  @debug.assert_eq(
    bundled.error,
    Some("failed to bundle local images: [./missing.svg]"),
  )
  @debug.assert_eq(bundled.svg, svg)
}

///|
async test "bundle remote duplicate url is fetched once per run" {
  reset_bundle_test_state()
  let url = "https://example.com/icon.svg"
  test_remote_fetch_ok_overrides[url] = (ascii_bytes(test_svg_payload), "")
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/icon.svg"/><image href="https://example.com/icon.svg"/></svg>
  let bundled = bundle_remote_svg_images(svg)
  @debug.assert_eq(bundled.error, None)
  @debug.assert_eq(test_remote_fetch_count.get_or_default(url, 0), 1)
  assert_false(bundled.svg.contains(url))
  @debug.assert_eq(
    count_occurrences(bundled.svg, "data:image/svg+xml;base64,"),
    2,
  )
  reset_bundle_test_state()
}

///|
async test "bundle remote cache reuses fetched image across runs when enabled" {
  reset_bundle_test_state()
  let url = "https://example.com/icon.svg"
  test_remote_fetch_ok_overrides[url] = (
    ascii_bytes(test_svg_payload),
    "image/svg+xml",
  )
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/icon.svg"/></svg>
  ignore(bundle_remote_svg_images(svg, cache_images=true))
  ignore(bundle_remote_svg_images(svg, cache_images=true))
  @debug.assert_eq(test_remote_fetch_count.get_or_default(url, 0), 1)
  test_remote_fetch_count.clear()
  persistent_bundle_cache.clear()
  ignore(bundle_remote_svg_images(svg, cache_images=false))
  ignore(bundle_remote_svg_images(svg, cache_images=false))
  @debug.assert_eq(test_remote_fetch_count.get_or_default(url, 0), 2)
  reset_bundle_test_state()
}

///|
async test "bundle remote image keeps svg and reports oversized response" {
  reset_bundle_test_state()
  let url = "https://example.com/huge.bin"
  test_remote_fetch_ok_overrides[url] = (
    Bytes::makei(max_bundle_image_size + 1, fn(_i) { b'a' }),
    "application/octet-stream",
  )
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/huge.bin"/></svg>
  let bundled = bundle_remote_svg_images(svg)
  @debug.assert_eq(
    bundled.error,
    Some("failed to bundle remote images: [https://example.com/huge.bin]"),
  )
  @debug.assert_eq(bundled.svg, svg)
  reset_bundle_test_state()
}

///|
async test "bundle remote image keeps svg and reports fetch errors" {
  reset_bundle_test_state()
  let url = "https://example.com/error.svg"
  test_remote_fetch_error_overrides[url] = "expected status 200 but got 500 Internal Server Error"
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/error.svg"/></svg>
  let bundled = bundle_remote_svg_images(svg)
  @debug.assert_eq(
    bundled.error,
    Some("failed to bundle remote images: [https://example.com/error.svg]"),
  )
  @debug.assert_eq(bundled.svg, svg)
  reset_bundle_test_state()
}

///|
async test "fetch remote image with async HTTP and redirects" {
  @async.with_task_group() <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, conn) => {
        if request.path == "/redirect" {
          conn.send_response(302, "Found", extra_headers={
            "Location": "/icon.svg",
          })
        } else {
          conn
          ..send_response(200, "OK", extra_headers={
            "Content-Type": "image/svg+xml",
          })
          .write(test_svg_payload)
        }
      })
    }
    let fetched = fetch_remote_image_bytes(
      "http://127.0.0.1:\{server.addr.port()}/redirect",
    )
    match fetched {
      Ok((bytes, content_type)) => {
        @debug.assert_eq(bytes, ascii_bytes(test_svg_payload))
        @debug.assert_eq(content_type, "image/svg+xml")
      }
      Err(message) => fail(message)
    }
  }
}

///|
async test "resolve remote image redirects" {
  @debug.assert_eq(
    resolve_remote_redirect(
      "https://example.com/assets/icon.svg?size=1", "../shared/icon.svg",
    ),
    Ok("https://example.com/assets/../shared/icon.svg"),
  )
  @debug.assert_eq(
    resolve_remote_redirect(
      "https://example.com/assets/icon.svg", "/images/icon.svg",
    ),
    Ok("https://example.com/images/icon.svg"),
  )
  @debug.assert_eq(
    resolve_remote_redirect(
      "https://example.com/assets/icon.svg", "//cdn.example.com/icon.svg",
    ),
    Ok("https://cdn.example.com/icon.svg"),
  )
  @debug.assert_eq(
    resolve_remote_redirect("https://example.com", "icon.svg"),
    Ok("https://example.com/icon.svg"),
  )
}

///|
async test "bundle remote image preserves successful replacements when another fetch fails" {
  reset_bundle_test_state()
  let ok_url = "https://example.com/ok.svg"
  let bad_url = "https://example.com/error.svg"
  test_remote_fetch_ok_overrides[ok_url] = (ascii_bytes(test_svg_payload), "")
  test_remote_fetch_error_overrides[bad_url] = "expected status 200 but got 500 Internal Server Error"
  let svg =
    #|<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/ok.svg"/><image href="https://example.com/error.svg"/></svg>
  let bundled = bundle_remote_svg_images(svg)
  @debug.assert_eq(
    bundled.error,
    Some("failed to bundle remote images: [https://example.com/error.svg]"),
  )
  assert_true(bundled.svg.contains("data:image/svg+xml;base64,"))
  assert_true(bundled.svg.contains(bad_url))
  assert_false(bundled.svg.contains(ok_url))
  @debug.assert_eq(test_remote_fetch_count.get_or_default(ok_url, 0), 1)
  @debug.assert_eq(test_remote_fetch_count.get_or_default(bad_url, 0), 1)
  reset_bundle_test_state()
}

///|
async fn remove_test_file(path : String) -> Unit {
  @fs.remove(path) catch {
    _ => ()
  }
}

///|
async fn remove_test_dir(path : String) -> Unit {
  @fs.rmdir(path) catch {
    _ => ()
  }
}

///|
fn ascii_bytes(text : String) -> Bytes {
  Bytes::makei(text.length(), fn(i) { text.code_unit_at(i).to_int().to_byte() })
}

///|
fn reset_bundle_test_state() -> Unit {
  persistent_bundle_cache.clear()
  test_remote_fetch_ok_overrides.clear()
  test_remote_fetch_error_overrides.clear()
  test_remote_fetch_count.clear()
}

///|
fn count_occurrences(s : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start < s.length() {
    match find_substring_from(s, needle, start) {
      Some(i) => {
        count = count + 1
        start = i + needle.length()
      }
      None => break
    }
  }
  count
}

///|
let test_svg_payload =
  #|<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>
