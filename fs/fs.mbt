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
/// Creates an import resolver by asynchronously loading imports from the local
/// filesystem into memory.
pub async fn import_resolver(
  source : String,
  base_path? : String? = None,
) -> @ir.ImportResolver {
  let loaded : Map[String, String] = Map([])
  let attempted : Map[String, Bool] = Map([])
  while true {
    let requested : Array[String] = []
    let resolver = @ir.ImportResolver::new(fn(import_path) {
      match loaded.get(import_path) {
        Some(content) => Some(content)
        None => {
          requested.push(import_path)
          None
        }
      }
    })
    let _ = Some(
      @diago.parse(
        source,
        options=@diago.ParseOptions::new().with_import_resolver(Some(resolver)),
      ),
    ) catch {
      _ => None
    }
    let mut loaded_any = false
    for import_path in requested {
      if attempted.get(import_path) is Some(_) {
        continue
      }
      attempted[import_path] = true
      let full_path = import_full_path(import_path, base_path)
      let content = Some(@async_fs.read_file(full_path).text()) catch {
        _ => None
      }
      match content {
        Some(value) => {
          loaded[import_path] = value
          loaded_any = true
        }
        None => ()
      }
    }
    if !loaded_any {
      return resolver
    }
  } nobreak {
    @ir.ImportResolver::new(fn(_) { None })
  }
}

///|
fn import_full_path(import_path : String, base_path : String?) -> String {
  let full_path = match base_path {
    Some(base) =>
      @system_path.Path(base).join(@system_path.Path(import_path)).to_string()
    None => import_path
  }
  if full_path.has_suffix(".d2") {
    full_path
  } else {
    full_path + ".d2"
  }
}

///|
/// Parses a local source file and resolves imports relative to that file.
pub async fn parse_file(
  file_path : String,
  options? : @diago.ParseOptions = @diago.ParseOptions::new(),
) -> @ir.Map raise @diago.DiagoError {
  let source = read_source_file(file_path)
  let options = with_filesystem_resolver(options, source, parent_dir(file_path)) catch {
    error => raise @diago.IOError("Error loading imports: \{error}")
  }
  @diago.parse(source, options~)
}

///|
/// Compiles a local source file and resolves imports relative to that file.
pub async fn compile_file(
  file_path : String,
  options? : @diago.CompileOptions = @diago.CompileOptions::new(),
) -> String raise @diago.DiagoError {
  let source = read_source_file(file_path)
  let parse_options = with_filesystem_resolver(
    options.parse_options,
    source,
    parent_dir(file_path),
  ) catch {
    error => raise @diago.IOError("Error loading imports: \{error}")
  }
  @diago.compile(source, options=options.with_parse_options(parse_options))
}

///|
async fn read_source_file(file_path : String) -> String raise @diago.DiagoError {
  @async_fs.read_file(file_path).text() catch {
    error => raise @diago.IOError("Error reading file '\{file_path}': \{error}")
  }
}

///|
async fn with_filesystem_resolver(
  options : @diago.ParseOptions,
  source : String,
  base_path : String?,
) -> @diago.ParseOptions {
  match options.import_resolver {
    Some(_) => options
    None =>
      options.with_import_resolver(Some(import_resolver(source, base_path~)))
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
