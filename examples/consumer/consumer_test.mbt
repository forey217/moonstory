///|
test "game host receives an item event and resumes a saved conversation" {
  let text = "story \"npc\" \"NPC\"\nvar accepted = false\n:: start\nline guide \"Help?\"\nchoice accept \"Yes\" -> quest\nchoice leave \"No\" -> exit\n:: quest\nset accepted = true\nemit \"inventory.add\" \"map\"\nline guide \"Take this map.\"\nend \"accepted\"\n:: exit\nend \"declined\""
  let compiled = @story.compile(text)
  let external_save = @moonstory-consumer-example.accept_and_save(text)
  assert_true(
    @story.restore(compiled, external_save).variables().get("accepted")
    is Some(@story.Flag(true)),
  )
  let current = @story.start(compiled).advance().choose("accept")
  assert_true(current.frame() is @story.Line("guide", "Take this map."))
  assert_eq(current.events()[0].name, "inventory.add")
  assert_true(current.events()[0].value is @story.Text("map"))
  let resumed = @story.restore(compiled, current.save())
  assert_eq(resumed.events().length(), 0)
  assert_true(resumed.advance().frame() is @story.Ended("accepted"))
}

///|
test "teaching host reads score independently of dialogue UI" {
  let s = @story.compile(
    "story \"lesson\" \"Lesson\"\nvar score = 0\n:: a\nchoice correct \"Check identity\" -> b\nchoice wrong \"Skip\" -> c\n:: b\nset score = score + 2\nemit \"assessment.score\" score\nend \"passed\"\n:: c\nend \"retry\"",
  )
  let completed = @story.start(s).choose("correct")
  assert_true(completed.variables().get("score") is Some(@story.Number(2)))
  assert_true(completed.events()[0].value is @story.Number(2))
  assert_eq(s.diagnostics().length(), 0)
}
