///|
pub fn Value::json(self : Value) -> Json {
  match self {
    Number(n) => Json::number(n.to_double())
    Flag(b) => Json::boolean(b)
    Text(s) => Json::string(s)
  }
}

///|
fn field(o : Map[String, Json], key : String) -> String raise StoryError {
  match o.get(key) {
    Some(String(s)) => s
    _ => raise Runtime("request", key + " must be a string")
  }
}

///|
fn diagnostic_json(d : Diagnostic) -> Json {
  Json::object(
    Map([
      ("code", Json::string(d.code)),
      ("node", Json::string(d.node)),
      ("line", Json::number(d.line.to_double())),
      ("message", Json::string(d.message)),
    ]),
  )
}

///|
/// Metadata includes structural edges for host graph displays, without evaluating conditions.
pub fn Story::json(self : Story) -> Json {
  let nodes = []
  for name in self.order {
    let edges = []
    let mut line = 1
    for ins in self.code {
      if ins.node != name {
        continue
      }
      if self.labels.get(name) is Some(pc) {
        line = self.code[pc].line
      }
      match ins.op {
        Jump(t) =>
          edges.push(
            Json::object(
              Map([("target", Json::string(t)), ("kind", Json::string("jump"))]),
            ),
          )
        Branch(_, t) =>
          edges.push(
            Json::object(
              Map([("target", Json::string(t)), ("kind", Json::string("if"))]),
            ),
          )
        Pick(id, text, t, _) =>
          edges.push(
            Json::object(
              Map([
                ("target", Json::string(t)),
                ("kind", Json::string("choice")),
                ("id", Json::string(id)),
                ("text", Json::string(text)),
              ]),
            ),
          )
        _ => ()
      }
    }
    nodes.push(
      Json::object(
        Map([
          ("name", Json::string(name)),
          ("line", Json::number(line.to_double())),
          ("edges", Json::array(edges)),
        ]),
      ),
    )
  }
  Json::object(
    Map([
      ("id", Json::string(self.id)),
      ("title", Json::string(self.title)),
      ("instructions", Json::number(self.code.length().to_double())),
      ("nodes", Json::array(nodes)),
      ("diagnostics", Json::array(self.diagnostics().map(diagnostic_json))),
    ]),
  )
}

///|
pub fn Session::json(self : Session) -> Json {
  let frame = match self.current {
    Line(speaker, text) =>
      Json::object(
        Map([
          ("kind", Json::string("line")),
          ("speaker", Json::string(speaker)),
          ("text", Json::string(text)),
        ]),
      )
    Choices(cs) =>
      Json::object(
        Map([
          ("kind", Json::string("choices")),
          (
            "choices",
            Json::array(
              cs.map(fn(c) {
                Json::object(
                  Map([
                    ("id", Json::string(c.id)),
                    ("text", Json::string(c.text)),
                    ("target", Json::string(c.target)),
                  ]),
                )
              }),
            ),
          ),
        ]),
      )
    Ended(ending) =>
      Json::object(
        Map([("kind", Json::string("ended")), ("ending", Json::string(ending))]),
      )
  }
  let vars : Map[String, Json] = Map([])
  for k, v in self.vars {
    vars[k] = v.json()
  }
  let events = self.delivered.map(fn(e) {
    Json::object(
      Map([
        ("sequence", Json::number(e.sequence.to_double())),
        ("name", Json::string(e.name)),
        ("value", e.value.json()),
      ]),
    )
  })
  Json::object(
    Map([
      ("frame", frame),
      ("node", Json::string(self.node())),
      ("line", Json::number(self.source_line().to_double())),
      ("variables", Json::object(vars)),
      ("events", Json::array(events)),
      ("actions", Json::number(self.actions.length().to_double())),
    ]),
  )
}

///|
fn error_json(e : Error) -> Json {
  let (code, line, column, message) = match e {
    StoryError::Syntax(l, c, m) => ("syntax", l, c, m)
    StoryError::Type(l, m) => ("type", l, 1, m)
    StoryError::Runtime(code, m) => (code, 0, 0, m)
    StoryError::Limit(m) => ("limit", 0, 0, m)
    StoryError::Save(m) => ("save", 0, 0, m)
    _ => ("request", 0, 0, "invalid JSON request")
  }
  Json::object(
    Map([
      ("ok", Json::boolean(false)),
      ("code", Json::string(code)),
      ("line", Json::number(line.to_double())),
      ("column", Json::number(column.to_double())),
      ("error", Json::string(message)),
    ]),
  )
}

///|
/// Stateless JSON host boundary. Runtime decisions and save validation remain in MoonBit.
pub fn run_json(request : String) -> String {
  try {
    if request.length() > 3000000 {
      raise Limit("request exceeds 3000000 code units")
    }
    guard @json.parse(request) is Object(o) else {
      raise Runtime("request", "request must be an object")
    }
    let story = compile(field(o, "source"))
    let command = field(o, "command")
    let result = if command == "check" {
      story.json()
    } else {
      let state = if command == "start" {
        start(story)
      } else {
        let loaded = restore(story, field(o, "save"))
        match command {
          "restore" => loaded
          "advance" => loaded.advance()
          "choose" => loaded.choose(field(o, "choice"))
          _ => raise Runtime("request", "unknown command " + command)
        }
      }
      Json::object(
        Map([("state", state.json()), ("save", Json::string(state.save()))]),
      )
    }
    Json::object(Map([("ok", Json::boolean(true)), ("result", result)])).stringify()
  } catch {
    error => error_json(error).stringify()
  }
}
