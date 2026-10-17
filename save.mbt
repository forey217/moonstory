///|
pub fn Session::save(self : Session) -> String raise StoryError {
  // Check the exact encoded size before joining the full journal. A valid script
  // may contain very long choice identifiers reused by thousands of actions.
  let mut encoded_length = Json::object(
      Map([
        ("format", Json::string("moonstory-save/1")),
        ("source", Json::string(self.story.source)),
        ("actions", Json::array([])),
      ]),
    )
    .stringify()
    .length()
  for i = 0; i < self.actions.length(); i = i + 1 {
    encoded_length = encoded_length +
      Json::string(self.actions[i]).stringify().length() +
      (if i > 0 { 1 } else { 0 })
    if encoded_length > 2097152 {
      raise Limit("save exceeds 2097152 code units")
    }
  }
  let result = Json::object(
    Map([
      ("format", Json::string("moonstory-save/1")),
      ("source", Json::string(self.story.source)),
      ("actions", Json::array(self.actions.map(Json::string))),
    ]),
  ).stringify()
  if result.length() > 2097152 {
    raise Limit("save exceeds 2097152 code units")
  }
  result
}

///|
/// Validate and replay a save against the exact expected story. Historical emit
/// events are suppressed; the next transition resumes their sequence numbers.
pub fn restore(story : Story, saved : String) -> Session raise StoryError {
  if saved.length() > 2097152 {
    raise Limit("save exceeds 2097152 code units")
  }
  let value = @json.parse(saved) catch { _ => raise Save("invalid save JSON") }
  guard value is Object(o) else { raise Save("save must be an object") }
  if o.length() != 3 ||
    o.get("format") != Some(Json::string("moonstory-save/1")) {
    raise Save("unsupported save format or fields")
  }
  if o.get("source") != Some(Json::string(story.source)) {
    raise Save("save belongs to different story source")
  }
  guard o.get("actions") is Some(Array(actions)) else {
    raise Save("actions must be an array")
  }
  if actions.length() > 10000 {
    raise Limit("save exceeds 10000 player actions")
  }
  let mut state = start(story)
  for action in actions {
    guard action is String(id) else { raise Save("actions must be strings") }
    if !id.is_empty() && !identifier(id) {
      raise Save("invalid choice id in save")
    }
    state = if id.is_empty() { state.advance() } else { state.choose(id) }
  }
  {
    story: state.story,
    vars: state.vars,
    pc: state.pc,
    current: state.current,
    delivered: [],
    sequence: state.sequence,
    actions: state.actions,
  }
}
