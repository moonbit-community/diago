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
test "theme colors match the pinned D2 catalog" {
  @debug.assert_eq(get_theme(4).resolve("B1"), "#000536")
  @debug.assert_eq(get_theme(4).resolve("AB5"), "#DACEFB")
  @debug.assert_eq(get_theme(6).resolve("B1"), "#170034")
  @debug.assert_eq(get_theme(6).resolve("AB5"), "#FFDAEF")
  @debug.assert_eq(get_theme(100).resolve("B1"), "#1E1303")
  @debug.assert_eq(get_theme(100).resolve("AB5"), "#D5E0FD")
  @debug.assert_eq(get_theme(200).resolve("N1"), "#CDD6F4")
  @debug.assert_eq(get_theme(200).resolve("AA2"), "#f38BA8")
  @debug.assert_eq(get_theme(300).resolve("B2"), "#0000E4")
  @debug.assert_eq(get_theme(300).resolve("AB5"), "#F9E088")
  @debug.assert_eq(get_theme(303).resolve("N1"), "#0f5eaa")
  @debug.assert_eq(get_theme(303).resolve("B4"), "#438dd5")
  assert_true(get_theme(303).rules.c4)
}
