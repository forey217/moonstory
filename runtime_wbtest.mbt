///|
let shop_script : String = "story \"shop\" \"商店\"\nvar coins = 3\nvar bought = false\n:: start\nline keeper \"金币 ${coins}\"\nchoice buy \"购买\" -> buy if coins >= 2\nchoice leave \"离开\" -> done\n:: buy\nset coins = coins - 2\nset bought = true\nemit \"inventory.add\" \"key\"\njump start\n:: done\nend \"left\""

///|
test "NPC dialogue hides unaffordable options and emits host events" {
  let a = start(compile(shop_script))
  assert_eq(a.frame(), Line("keeper", "金币 3"))
  let b = a.advance()
  assert_true(b.frame() is Choices(cs) && cs.length() == 2)
  let c = b.choose("buy")
  assert_eq(c.frame(), Line("keeper", "金币 1"))
  assert_eq(c.variables().get("bought"), Some(Flag(true)))
  assert_eq(c.events(), [
    { sequence: 1, name: "inventory.add", value: Text("key"), },
  ])
  assert_eq(a.variables().get("coins"), Some(Number(3)))
  let d = c.advance()
  assert_true(
    d.frame() is Choices(cs) && cs.length() == 1 && cs[0].id == "leave",
  )
  assert_eq(d.events().length(), 0)
  assert_eq(d.choose("leave").frame(), Ended("left"))
  assert_true(
    try {
      d.choose("buy") |> ignore
      false
    } catch {
      _ => true
    },
  )
}

///|
test "failed transitions roll back assignments events and player actions" {
  let s = start(
    compile(
      "story \"x\" \"x\"\nvar n = 0\n:: start\nline n \"before\"\nset n = 4\nemit \"effect\" n\nset n = 2147483647 + 1\nend \"bad\"",
    ),
  )
  assert_true(
    try {
      s.advance() |> ignore
      false
    } catch {
      StoryError::Runtime("overflow", _) => true
      _ => false
    },
  )
  assert_eq(s.variables().get("n"), Some(Number(0)))
  assert_eq(s.events().length(), 0)
  assert_eq(s.action_count(), 0)
  assert_eq(s.frame(), Line("n", "before"))
}

///|
test "automatic loops and all hidden choices produce recoverable errors" {
  assert_true(
    try {
      start(compile("story \"x\" \"x\"\n:: a\njump a")) |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      start(compile("story \"x\" \"x\"\n:: a\nchoice no \"no\" -> a if false"))
      |> ignore
      false
    } catch {
      StoryError::Runtime("blocked", _) => true
      _ => false
    },
  )
}

///|
test "public collections cannot corrupt session state" {
  let s = start(compile(shop_script)).advance()
  let vars = s.variables()
  vars["coins"] = Number(100)
  if s.frame() is Choices(cs) {
    cs.clear()
  }
  let ev = s.events()
  ev.push({ sequence: 9, name: "fake", value: Number(1), })
  assert_eq(s.choose("buy").variables().get("coins"), Some(Number(1)))
  assert_eq(s.source_line(), 6)
  assert_eq(s.node(), "start")
}

///|
test "conditional jump and completed session action errors" {
  let s = start(
    compile(
      "story \"x\" \"x\"\nvar ok = true\n:: a\nif ok -> b\nend \"bad\"\n:: b\nend \"good\"",
    ),
  )
  assert_eq(s.frame(), Ended("good"))
  assert_true(
    try {
      s.advance() |> ignore
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      s.choose("x") |> ignore
      false
    } catch {
      _ => true
    },
  )
}
