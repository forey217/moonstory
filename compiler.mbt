///|
priv enum Op {
  Say(String, String)
  Pick(String, String, String, Expr)
  Assign(String, Expr)
  Emit(String, Expr)
  Jump(String)
  Branch(Expr, String)
  End(String)
}

///|
priv struct Instruction {
  op : Op
  line : Int32
  node : String
}

///|
pub struct Story {
  id : String
  title : String
  priv source : String
  priv initial : Map[String, Value]
  priv code : Array[Instruction]
  priv labels : Map[String, Int32]
  priv order : Array[String]
}

///|
pub fn Story::node_names(self : Story) -> Array[String] {
  self.order.copy()
}

///|
pub fn Story::instruction_count(self : Story) -> Int32 {
  self.code.length()
}

///|
fn word(ts : Array[Token], i : Int32, line : Int32) -> String raise StoryError {
  if i >= ts.length() {
    raise Syntax(line, 1, "missing token")
  }
  match ts[i].kind {
    Word(s) => s
    _ => raise Syntax(line, ts[i].col, "expected keyword or identifier")
  }
}

///|
fn quoted(
  ts : Array[Token],
  i : Int32,
  line : Int32,
) -> String raise StoryError {
  if i >= ts.length() {
    raise Syntax(line, 1, "missing string")
  }
  match ts[i].kind {
    Quoted(s) => s
    _ => raise Syntax(line, ts[i].col, "expected quoted string")
  }
}

///|
fn expect(
  ts : Array[Token],
  i : Int32,
  s : String,
  line : Int32,
) -> Unit raise StoryError {
  if word(ts, i, line) != s {
    raise Syntax(line, ts[i].col, "expected " + s)
  }
}

///|
fn name_at(
  ts : Array[Token],
  i : Int32,
  line : Int32,
) -> String raise StoryError {
  let name = word(ts, i, line)
  if !identifier(name) || name == "true" || name == "false" {
    raise Syntax(line, ts[i].col, "invalid identifier")
  }
  name
}

///|
fn tail(ts : Array[Token], begin : Int32, end : Int32) -> Array[Token] {
  let out = []
  for i = begin; i < end; i = i + 1 {
    out.push(ts[i])
  }
  out
}

///|
fn count(ts : Array[Token], n : Int32, line : Int32) -> Unit raise StoryError {
  if ts.length() != n {
    raise Syntax(line, 1, "wrong number of arguments")
  }
}

///|
fn height(e : Expr) -> Int32 {
  match e {
    Lit(_) | Read(_) => 1
    Unary(_, a) => 1 + height(a)
    Binary(_, a, b) => 1 + Int32::max(height(a), height(b))
  }
}

///|
fn typed_expr(
  ts : Array[Token],
  line : Int32,
  vars : Map[String, Value],
  wanted : Int32?,
) -> Expr raise StoryError {
  let e = expression(ts, line)
  if height(e) > 32 {
    raise Limit("expression tree depth exceeds 32")
  }
  let k = expr_kind(e, vars, line)
  if wanted is Some(w) && w != k {
    raise Type(line, "expression has incompatible type")
  }
  e
}

///|
fn template(
  text : String,
  vars : Map[String, Value],
  line : Int32,
) -> String raise StoryError {
  let out = StringBuilder()
  let mut rendered_length = 0
  let mut i = 0
  while i < text.length() {
    if i + 2 < text.length() &&
      text[i] == 36 &&
      text[i + 1] == 36 &&
      text[i + 2] == 123 {
      rendered_length = rendered_length + 2
      out.write_string("${")
      i = i + 3
    } else if i + 1 < text.length() && text[i] == 36 && text[i + 1] == 123 {
      let begin = i + 2
      i = begin
      while i < text.length() && text[i] != 125 {
        i = i + 1
      }
      if i == text.length() {
        raise Syntax(line, begin, "unclosed interpolation")
      }
      let name = text[begin:i].to_owned()
      match vars.get(name) {
        Some(value) => {
          let part = value.text()
          rendered_length = rendered_length + part.length()
          if rendered_length > 262144 {
            raise Limit("rendered text exceeds 262144 code units")
          }
          out.write_string(part)
        }
        None => raise Type(line, "unknown interpolation variable " + name)
      }
      i = i + 1
    } else {
      // Copy contiguous UTF-16 as a string slice, never split a surrogate pair.
      let begin = i
      i = i + 1
      while i < text.length() && text[i] != 36 {
        i = i + 1
      }
      rendered_length = rendered_length + i - begin
      out.write_string(text[begin:i].to_owned())
    }
    if rendered_length > 262144 {
      raise Limit("rendered text exceeds 262144 code units")
    }
  }
  out.to_string()
}

///|
fn verify_node(
  code : Array[Instruction],
  begin : Int32,
  line : Int32,
) -> Unit raise StoryError {
  if code.length() == begin {
    raise Syntax(line, 1, "empty node")
  }
  let seen : Map[String, Bool] = Map([])
  let mut choices = false
  for i = begin; i < code.length(); i = i + 1 {
    match code[i].op {
      Pick(id, _, _, _) => {
        if seen.contains(id) {
          raise Syntax(code[i].line, 1, "duplicate choice id " + id)
        }
        seen[id] = true
        choices = true
        if seen.length() > 256 {
          raise Limit("more than 256 choices in one group")
        }
      }
      _ =>
        if choices {
          raise Syntax(code[i].line, 1, "choice group must end its node")
        }
    }
  }
  match code[code.length() - 1].op {
    Jump(_) | End(_) | Pick(_, _, _, _) => ()
    _ => raise Syntax(line, 1, "node must end with jump, end or choice")
  }
}

///|
/// Compile the complete MoonStory 1 language. No external code is evaluated.
pub fn compile(source : String) -> Story raise StoryError {
  if source.length() > 262144 {
    raise Limit("source exceeds 262144 code units")
  }
  let initial : Map[String, Value] = Map([])
  let labels : Map[String, Int32] = Map([])
  let code : Array[Instruction] = []
  let order = []
  let mut id = ""
  let mut title = ""
  let mut node = ""
  let mut node_begin = 0
  let mut header = false
  let mut lineno = 0
  for raw in source.split("\n") {
    lineno = lineno + 1
    let ts = lex(raw.to_owned(), lineno)
    if ts.is_empty() {
      continue
    }
    let command = word(ts, 0, lineno)
    if !header {
      expect(ts, 0, "story", lineno)
      count(ts, 3, lineno)
      id = quoted(ts, 1, lineno)
      title = quoted(ts, 2, lineno)
      if id.is_empty() || id.length() > 128 {
        raise Syntax(lineno, 1, "story id must contain 1..128 code units")
      }
      header = true
      continue
    }
    if command == "var" {
      if !node.is_empty() {
        raise Syntax(lineno, 1, "variables must precede nodes")
      }
      let name = name_at(ts, 1, lineno)
      if initial.contains(name) {
        raise Syntax(lineno, 1, "duplicate variable " + name)
      }
      expect(ts, 2, "=", lineno)
      let empty : Map[String, Value] = Map([])
      let e = typed_expr(tail(ts, 3, ts.length()), lineno, empty, None)
      initial[name] = eval(e, empty)
      if initial.length() > 256 {
        raise Limit("more than 256 variables")
      }
      continue
    }
    if command == "::" {
      count(ts, 2, lineno)
      if !node.is_empty() {
        verify_node(code, node_begin, lineno)
      }
      node = name_at(ts, 1, lineno)
      if labels.contains(node) {
        raise Syntax(lineno, 1, "duplicate node " + node)
      }
      node_begin = code.length()
      labels[node] = node_begin
      order.push(node)
      continue
    }
    if node.is_empty() {
      raise Syntax(lineno, 1, "instruction outside a node")
    }
    let op = match command {
      "line" => {
        count(ts, 3, lineno)
        let text = quoted(ts, 2, lineno)
        template(text, initial, lineno) |> ignore
        Say(name_at(ts, 1, lineno), text)
      }
      "choice" => {
        let cid = name_at(ts, 1, lineno)
        let text = quoted(ts, 2, lineno)
        template(text, initial, lineno) |> ignore
        expect(ts, 3, "->", lineno)
        let target = name_at(ts, 4, lineno)
        let guard_expr = if ts.length() == 5 {
          Lit(Flag(true))
        } else {
          expect(ts, 5, "if", lineno)
          typed_expr(tail(ts, 6, ts.length()), lineno, initial, Some(1))
        }
        Pick(cid, text, target, guard_expr)
      }
      "set" => {
        let name = name_at(ts, 1, lineno)
        guard initial.get(name) is Some(value) else {
          raise Type(lineno, "undeclared variable " + name)
        }
        expect(ts, 2, "=", lineno)
        Assign(
          name,
          typed_expr(
            tail(ts, 3, ts.length()),
            lineno,
            initial,
            Some(value.kind()),
          ),
        )
      }
      "emit" =>
        Emit(
          quoted(ts, 1, lineno),
          typed_expr(tail(ts, 2, ts.length()), lineno, initial, None),
        )
      "jump" => {
        count(ts, 2, lineno)
        Jump(name_at(ts, 1, lineno))
      }
      "if" => {
        if ts.length() < 4 {
          raise Syntax(lineno, 1, "if requires expression -> target")
        }
        expect(ts, ts.length() - 2, "->", lineno)
        Branch(
          typed_expr(tail(ts, 1, ts.length() - 2), lineno, initial, Some(1)),
          name_at(ts, ts.length() - 1, lineno),
        )
      }
      "end" => {
        count(ts, 2, lineno)
        End(quoted(ts, 1, lineno))
      }
      _ => raise Syntax(lineno, 1, "unknown instruction " + command)
    }
    code.push({ op, line: lineno, node, })
    if code.length() > 10000 {
      raise Limit("more than 10000 instructions")
    }
  }
  if !header || order.is_empty() {
    raise Syntax(lineno, 1, "story header and a node are required")
  }
  verify_node(code, node_begin, lineno)
  for ins in code {
    let target = match ins.op {
      Jump(t) | Branch(_, t) | Pick(_, _, t, _) => Some(t)
      _ => None
    }
    if target is Some(t) && !labels.contains(t) {
      raise Syntax(ins.line, 1, "unknown target " + t)
    }
  }
  { id, title, source, initial, code, labels, order, }
}
