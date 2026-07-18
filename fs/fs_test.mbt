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
async fn remove_test_path(path : String) -> Unit {
  @async_fs.remove(path) catch {
    _ => ()
  }
}

///|
async fn remove_test_dir(path : String) -> Unit {
  @async_fs.rmdir(path) catch {
    _ => ()
  }
}

///|
async fn prepare_import_fixture(dir : String) -> (String, String, String) {
  let main_path = dir + "/main.d2"
  let dep_path = dir + "/common.d2"
  let nested_path = dir + "/nested.d2"
  remove_test_path(main_path)
  remove_test_path(dep_path)
  remove_test_path(nested_path)
  remove_test_dir(dir)
  @async_fs.mkdir(dir)
  @async_fs.write_file(
    main_path,
    "common: @common",
    create_mode=CreateOrTruncate,
  )
  @async_fs.write_file(
    dep_path,
    "server\ndatabase\nnested: @nested",
    create_mode=CreateOrTruncate,
  )
  @async_fs.write_file(nested_path, "leaf", create_mode=CreateOrTruncate)
  (main_path, dep_path, nested_path)
}

///|
async fn clean_import_fixture(
  dir : String,
  main_path : String,
  dep_path : String,
  nested_path : String,
) -> Unit {
  remove_test_path(main_path)
  remove_test_path(dep_path)
  remove_test_path(nested_path)
  remove_test_dir(dir)
}

///|
async test "filesystem resolver supports source-based facade calls" {
  let dir = ".diago_fs_resolver_test"
  let (main_path, dep_path, nested_path) = prepare_import_fixture(dir)
  let ir_map = @diago.parse(
    "common: @common",
    options=@diago.ParseOptions::new().with_import_resolver(
      Some(import_resolver("common: @common", base_path=Some(dir))),
    ),
  )
  clean_import_fixture(dir, main_path, dep_path, nested_path)
  guard ir_map.get_field("common") is Some(common) else {
    fail("no common field")
  }
  guard common.composite is Some(Map(common_map)) else {
    fail("common field has no map")
  }
  assert_true(common_map.has_field("server"))
  assert_true(common_map.has_field("database"))
  guard common_map.get_field("nested") is Some(nested) else {
    fail("no nested field")
  }
  guard nested.composite is Some(Map(nested_map)) else {
    fail("nested field has no map")
  }
  assert_true(nested_map.has_field("leaf"))
}

///|
async test "parse_file resolves imports relative to the input file" {
  let dir = ".diago_fs_parse_file_test"
  let (main_path, dep_path, nested_path) = prepare_import_fixture(dir)
  let ir_map = parse_file(main_path)
  clean_import_fixture(dir, main_path, dep_path, nested_path)
  guard ir_map.get_field("common") is Some(common) else {
    fail("no common field")
  }
  guard common.composite is Some(Map(common_map)) else {
    fail("common field has no map")
  }
  assert_true(common_map.has_field("server"))
  assert_true(common_map.has_field("database"))
}

///|
async test "compile_file returns rendered output" {
  let dir = ".diago_fs_compile_file_test"
  let (main_path, dep_path, nested_path) = prepare_import_fixture(dir)
  let svg = compile_file(main_path)
  clean_import_fixture(dir, main_path, dep_path, nested_path)
  assert_true(svg.contains("<svg"))
}
