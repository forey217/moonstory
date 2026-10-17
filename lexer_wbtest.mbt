///|
test "lexer separates operators and decodes Unicode JSON strings" {
  let ts = lex("choice a \"你好\\n😀\" -> end if x>=2 && !done", 7)
  assert_eq(ts.length(), 12)
  assert_true(ts[2].kind == Quoted("你好\n😀"))
  assert_true(ts[3].kind == Word("->"))
  assert_true(ts[7].kind == Word(">="))
  assert_eq(ts[0].col, 1)
  assert_eq(lex(" # comment", 1).length(), 0)
  assert_true(identifier("_node2"))
  assert_false(identifier("2node"))
}

///|
test "lexer gives exact source location for malformed input" {
  let bad = try {
    lex("line a \"bad\\q\"", 4) |> ignore
    false
  } catch {
    StoryError::Syntax(4, 8, _) => true
    _ => false
  }
  assert_true(bad)
  assert_true(
    try {
      lex("x & y", 3) |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      lex("\"unterminated", 2) |> ignore
      false
    } catch {
      _ => true
    },
  )
}
