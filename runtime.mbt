///|
pub struct Choice {
  id : String
  text : String
  target : String
} derive(Eq, @debug.Debug)

///|
pub extend Choice with Eq::{equal, not_equal}

///|
pub extend Choice with @debug.Debug::{to_repr}

///|
pub(all) enum Frame {
  Line(String, String)
  Choices(Array[Choice])
  Ended(String)
} derive(Eq, @debug.Debug)

///|
pub extend Frame with Eq::{equal, not_equal}

///|
pub extend Frame with @debug.Debug::{to_repr}

///|
pub struct Event {
  sequence : Int32
  name : String
  value : Value
} derive(Eq, @debug.Debug)

///|
pub extend Event with Eq::{equal, not_equal}

///|
pub extend Event with @debug.Debug::{to_repr}

///|
pub struct Session {
  priv story : Story
  priv vars : Map[String, Value]
  priv pc : Int32
  priv current : Frame
  priv delivered : Array[Event]
  priv sequence : Int32
  priv actions : Array[String]
}

///|
pub fn Session::frame(self : Session) -> Frame {
  match self.current {
    Choices(cs) => Choices(cs.copy())
    f => f
  }
}

///|
pub fn Session::variables(self : Session) -> Map[String, Value] {
  self.vars.copy()
}

///|
pub fn Session::events(self : Session) -> Array[Event] {
  self.delivered.copy()
}

///|
pub fn Session::node(self : Session) -> String {
  self.story.code[self.pc].node
}

///|
pub fn Session::source_line(self : Session) -> Int32 {
  self.story.code[self.pc].line
}

///|
pub fn Session::action_count(self : Session) -> Int32 {
  self.actions.length()
}

///|
fn enabled(e : Expr, vars : Map[String, Value]) -> Bool raise StoryError {
  match eval(e, vars) {
    Flag(b) => b
    _ => raise Runtime("type", "expected boolean")
  }
}

///|
fn target(story : Story, label : String) -> Int32 raise StoryError {
  match story.labels.get(label) {
    Some(i) => i
    None => raise Runtime("target", "missing node " + label)
  }
}

///|
fn drain(
  story : Story,
  vars : Map[String, Value],
  begin : Int32,
  actions : Array[String],
  initial_sequence : Int32,
) -> Session raise StoryError {
  let mut pc = begin
  let mut sequence = initial_sequence
  let events : Array[Event] = []
  let mut steps = 0
  let mut current = Ended("")
  while true {
    if steps >= 512 {
      raise Limit("more than 512 automatic instructions in one transition")
    }
    steps = steps + 1
    if pc < 0 || pc >= story.code.length() {
      raise Runtime("cursor", "execution left the story")
    }
    let ins = story.code[pc]
    match ins.op {
      Say(speaker, text) => {
        current = Line(speaker, template(text, vars, ins.line))
        break
      }
      Pick(_, _, _, _) => {
        let choices = []
        let mut i = pc
        while i < story.code.length() {
          guard story.code[i].op is Pick(id, text, dest, condition) else {
            break
          }
          if enabled(condition, vars) {
            choices.push({
              id,
              text: template(text, vars, story.code[i].line),
              target: dest,
            })
          }
          i = i + 1
        }
        if choices.is_empty() {
          raise Runtime("blocked", "all choices are hidden at " + ins.node)
        }
        current = Choices(choices)
        break
      }
      Assign(name, e) => {
        vars[name] = eval(e, vars)
        pc = pc + 1
      }
      Emit(name, e) => {
        let value = eval(e, vars)
        sequence = sequence + 1
        events.push({ sequence, name, value, })
        pc = pc + 1
      }
      Jump(label) => pc = target(story, label)
      Branch(e, label) =>
        pc = if enabled(e, vars) { target(story, label) } else { pc + 1 }
      End(ending) => {
        current = Ended(ending)
        break
      }
    }
  }
  { story, vars, pc, current, delivered: events, sequence, actions, }
}

///|
/// Evaluate until the first line, choice group or ending. This performs no I/O.
pub fn start(story : Story) -> Session raise StoryError {
  drain(story, story.initial.copy(), 0, [], 0)
}

///|
fn Session::next_actions(
  self : Session,
  action : String,
) -> Array[String] raise StoryError {
  if self.actions.length() >= 10000 {
    raise Limit("session exceeds 10000 player actions")
  }
  let actions = self.actions.copy()
  actions.push(action)
  actions
}

///|
/// Immutable transition: failure never changes self, including events and journal.
pub fn Session::advance(self : Session) -> Session raise StoryError {
  guard self.current is Line(_, _) else {
    raise Runtime("action", "advance requires a dialogue line")
  }
  drain(
    self.story,
    self.vars.copy(),
    self.pc + 1,
    self.next_actions(""),
    self.sequence,
  )
}

///|
/// Select by stable identifier, never by the visible list position.
pub fn Session::choose(self : Session, id : String) -> Session raise StoryError {
  guard self.current is Choices(cs) else {
    raise Runtime("action", "choose requires a choice group")
  }
  let mut destination : String? = None
  for c in cs {
    if c.id == id {
      destination = Some(c.target)
      break
    }
  }
  guard destination is Some(label) else {
    raise Runtime("choice", "unknown or hidden choice " + id)
  }
  drain(
    self.story,
    self.vars.copy(),
    target(self.story, label),
    self.next_actions(id),
    self.sequence,
  )
}
