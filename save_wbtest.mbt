///|
test "save replay restores variables cursor choices and event numbering" {
  let story = compile(shop_script)
  let s = start(story).advance().choose("buy")
  let saved = s.save()
  let r = restore(story, saved)
  assert_eq(r.frame(), s.frame())
  assert_eq(r.variables(), s.variables())
  assert_eq(r.action_count(), 2)
  assert_eq(r.events().length(), 0)
  assert_eq(r.advance().choose("leave").frame(), Ended("left"))
  assert_eq(r.save(), saved)
}

///|
test "saves reject changed sources forged variables unsupported formats and illegal paths" {
  let story = compile(shop_script)
  let saved = start(story).save()
  assert_true(
    try {
      restore(compile(shop_script + "\n"), saved) |> ignore
      false
    } catch {
      StoryError::Save(_) => true
      _ => false
    },
  )
  for bad in ["null", "{", "{}", "{\"format\":\"moonstory-save/2\"}"] {
    assert_true(
      try {
        restore(story, bad) |> ignore
        false
      } catch {
        _ => true
      },
    )
  }
  let forged = Json::object(
    Map([
      ("format", Json::string("moonstory-save/1")),
      ("source", Json::string(shop_script)),
      ("actions", Json::array([Json::string("buy")])),
    ]),
  ).stringify()
  assert_true(
    try {
      restore(story, forged) |> ignore
      false
    } catch {
      _ => true
    },
  )
  guard @json.parse(saved) is Object(o) else { fail("object required") }
  o["variables"] = Json::object(Map([("coins", Json::number(999))]))
  assert_true(
    try {
      restore(story, Json::object(o).stringify()) |> ignore
      false
    } catch {
      StoryError::Save(_) => true
      _ => false
    },
  )
}

///|
test "repeated quest effects continue after restore without redelivering history" {
  let story = compile(
    "story \"loop\" \"loop\"\nvar n = 0\n:: a\nset n = n + 1\nemit \"count\" n\nline n \"${n}\"\njump a",
  )
  let a = start(story).advance()
  assert_eq(a.events()[0].sequence, 2)
  let b = restore(story, a.save())
  assert_eq(b.events().length(), 0)
  let c = b.advance()
  assert_eq(c.events()[0].sequence, 3)
  assert_eq(c.variables().get("n"), Some(Number(3)))
}
