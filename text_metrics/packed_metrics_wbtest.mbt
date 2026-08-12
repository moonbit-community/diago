///|
test "packed i16 decoding preserves signed boundaries" {
  let values = b"\x00\x00\xff\x7f\x00\x80\xff\xff\x68\x18"
  inspect(packed_i16_at(values, 0), content="0")
  inspect(packed_i16_at(values, 1), content="32767")
  inspect(packed_i16_at(values, 2), content="-32768")
  inspect(packed_i16_at(values, 3), content="-1")
  inspect(packed_i16_at(values, 4), content="6248")
}
