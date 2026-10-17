///|
test "analysis finds unreachable nodes and closed loops" {
  let s = compile(
    "story \"x\" \"x\"\n:: a\nchoice loop \"loop\" -> b\nchoice done \"done\" -> c\n:: b\njump b\n:: c\nend \"ok\"\n:: orphan\nend \"unused\"",
  )
  let d = s.diagnostics()
  assert_eq(d.length(), 2)
  assert_eq(d[0].code, "no_end_path")
  assert_eq(d[0].node, "b")
  assert_eq(d[1].code, "unreachable")
  assert_eq(d[1].node, "orphan")
}

///|
test "analysis explicitly ignores condition satisfiability" {
  let s = compile(
    "story \"x\" \"x\"\n:: a\nif false -> b\njump a\n:: b\nend \"ok\"",
  )
  assert_eq(s.diagnostics().length(), 0)
  assert_true(
    try {
      start(s) |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
}

///|
test "dead jump after an ending cannot make a node reachable" {
  let s = compile(
    "story \"x\" \"x\"\n:: a\nend \"ok\"\njump b\n:: b\nend \"other\"",
  )
  assert_eq(s.diagnostics().length(), 1)
  assert_eq(s.diagnostics()[0].node, "b")
}
