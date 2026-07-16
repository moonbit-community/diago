///|
test "native command execution reports success and failure" {
  @debug.assert_eq(command_exec("exit 0"), 0)
  assert_true(command_exec("exit 1") != 0)
}
