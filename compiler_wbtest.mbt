///|
test "compile forward references Unicode and escaped interpolation" {
  let s = compile(
    "story \"a\" \"测试\"\nvar n = 1\n:: start\nline narrator \"$${n} = ${n} 😀\"\nchoice go \"走\" -> done if n == 1\n:: done\nend \"ok\"",
  )
  assert_eq(s.id, "a")
  assert_eq(s.node_names(), ["start", "done"])
  assert_eq(s.instruction_count(), 3)
  let names = s.node_names()
  names.clear()
  assert_eq(s.node_names().length(), 2)
  assert_eq(template("$${n} = ${n}", s.initial, 1), "${n} = 1")
}

///|
test "compiler rejects incomplete nodes broken targets and invalid declarations" {
  for
    text in [
      "story \"a\" \"b\"\n:: a\nline n \"x\"", "story \"a\" \"b\"\n:: a\njump absent",
      "story \"a\" \"b\"\n:: a\n:: b\nend \"x\"", "story \"a\" \"b\"\nvar x = y\n:: a\nend \"x\"",
      "story \"a\" \"b\"\nvar x = 1\n:: a\nset x = true\nend \"x\"", "story \"a\" \"b\"\n:: a\nline n \"${missing}\"\nend \"x\"",
      "story \"a\" \"b\"\n:: a\nchoice x \"x\" -> a\nchoice x \"y\" -> a", "story \"a\" \"b\"\n:: a\nchoice x \"x\" -> a\nend \"x\"",
      "story \"a\" \"b\"\n:: a\nvar x = 1\nend \"x\"", "story \"a\" \"b\"\nvar true = 1\n:: a\nend \"x\"",
      "story \"a\" \"b\"\n:: a\nend \"x\"\n:: a\nend \"x\"",
    ] {
    assert_true(
      try {
        compile(text) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "long left associated expressions are depth bounded" {
  let b = StringBuilder()
  b.write_string("story \"a\" \"b\"\nvar n = 1")
  for i = 0; i < 40; i = i + 1 {
    b.write_string(" + 1")
  }
  b.write_string("\n:: a\nend \"x\"")
  assert_true(
    try {
      compile(b.to_string()) |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
}
