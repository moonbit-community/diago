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
/// Creates an import resolver backed by the local filesystem.
pub fn import_resolver(base_path? : String? = None) -> @ir.ImportResolver {
  @ir.ImportResolver::new(fn(import_path) {
    let full_path = match base_path {
      Some(base) =>
        @system_path.Path(base).join(@system_path.Path(import_path)).to_string()
      None => import_path
    }
    let path_with_ext = if full_path.has_suffix(".d2") {
      full_path
    } else {
      full_path + ".d2"
    }
    Some(@system_fs.read_file_to_string(path_with_ext)) catch {
      _ => None
    }
  })
}

///|
/// Parses a local source file and resolves imports relative to that file.
pub fn parse_file(
  file_path : String,
  options? : @diago.ParseOptions = @diago.ParseOptions::new(),
) -> @ir.Map raise @diago.DiagoError {
  let source = read_source_file(file_path)
  @diago.parse(
    source,
    options=with_filesystem_resolver(options, parent_dir(file_path)),
  )
}

///|
/// Compiles a local source file and resolves imports relative to that file.
pub fn compile_file(
  file_path : String,
  options? : @diago.CompileOptions = @diago.CompileOptions::new(),
) -> String raise @diago.DiagoError {
  let source = read_source_file(file_path)
  let parse_options = with_filesystem_resolver(
    options.parse_options,
    parent_dir(file_path),
  )
  @diago.compile(source, options=options.with_parse_options(parse_options))
}

///|
fn read_source_file(file_path : String) -> String raise @diago.DiagoError {
  @system_fs.read_file_to_string(file_path) catch {
    @system_fs.IOError(message) =>
      raise @diago.IOError("Error reading file '\{file_path}': \{message}")
  }
}

///|
fn with_filesystem_resolver(
  options : @diago.ParseOptions,
  base_path : String?,
) -> @diago.ParseOptions {
  match options.import_resolver {
    Some(_) => options
    None => options.with_import_resolver(Some(import_resolver(base_path~)))
  }
}

///|
fn parent_dir(file_path : String) -> String? {
  let dir = @system_path.Path(file_path).dirname().to_string()
  if dir.length() > 0 {
    Some(dir)
  } else {
    None
  }
}
