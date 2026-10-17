///|
fn calculate(s : String) -> Value raise StoryError {
  let e = expression(lex(s, 1), 1)
  let vars : Map[String, Value] = Map([])
  expr_kind(e, vars, 1) |> ignore
  eval(e, vars)
}

///|
test "precedence types and left association" {
  assert_eq(calculate("7 - 3 - 2"), Number(2))
  assert_eq(calculate("1 + 2 >= 3 && !false || false"), Flag(true))
  assert_eq(calculate("\"月\" + \"光\""), Text("月光"))
  assert_eq(calculate("(1 + 2) - -3"), Number(6))
  assert_eq(calculate("-2147483648"), Number(-2147483648))
}

///|
test "short circuit prevents overflow and integer operations are checked" {
  assert_eq(calculate("false && (2147483647 + 1 > 0)"), Flag(false))
  assert_eq(calculate("true || (-2147483648 - 1 > 0)"), Flag(true))
  for s in ["2147483647 + 1", "-2147483648 - 1", "--2147483648", "2147483648"] {
    assert_true(
      try {
        calculate(s) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "reject undefined variables malformed expressions and mixed types" {
  for
    s in [
      "unknown", "1 + true", "true < false", "!1", "\"a\" - \"b\"", "1 2", "(1 + 2",
      "true && 3", "1 == \"1\"",
    ] {
    assert_true(
      try {
        calculate(s) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
}
