///|
test "source token variable and instruction resource limits" {
  assert_true(
    try {
      compile("x".repeat(262145)) |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      lex("x ".repeat(513), 1) |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
  let b = StringBuilder()
  b.write_string("story \"x\" \"x\"\n")
  for i = 0; i < 257; i = i + 1 {
    b.write_string("var v" + i.to_string() + " = 0\n")
  }
  b.write_string(":: a\nend \"x\"")
  assert_true(
    try {
      compile(b.to_string()) |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
  let c = StringBuilder()
  c.write_string("story \"x\" \"x\"\n:: a\n")
  for i = 0; i < 10001; i = i + 1 {
    c.write_string("end \"\"\n")
  }
  assert_true(
    try {
      compile(c.to_string()) |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
}

///|
test "session limit checks before copying actions and expression nesting is bounded" {
  let s = start(compile("story \"x\" \"x\"\n:: a\nline n \"x\"\njump a"))
  let full = Session::{
    story: s.story,
    vars: s.vars,
    pc: s.pc,
    current: s.current,
    delivered: s.delivered,
    sequence: s.sequence,
    actions: Array::make(10000, ""),
  }
  assert_true(
    try {
      full.advance() |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
  let deeply = "(".repeat(40) + "1" + ")".repeat(40)
  assert_true(
    try {
      calculate(deeply) |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
}

///|
test "rendering and string growth limits are enforced before oversized output" {
  let vars : Map[String, Value] = Map([("a", Text("x".repeat(140000)))])
  assert_true(
    try {
      template("${a}${a}", vars, 1) |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      eval(Binary("+", Read("a"), Read("a")), vars) |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
}

///|
test "save checks long repeated choice ids before encoding the complete journal" {
  let id = "x".repeat(120000)
  let story = compile(
    "story \"large\" \"large\"\n:: loop\nchoice " + id + " \"again\" -> loop",
  )
  let mut s = start(story)
  for i = 0; i < 20; i = i + 1 {
    s = s.choose(id)
  }
  assert_eq(s.action_count(), 20)
  assert_true(
    try {
      s.save() |> ignore
      false
    } catch {
      StoryError::Limit(_) => true
      _ => false
    },
  )
}
