///|
pub(all) enum Value {
  Number(Int32)
  Flag(Bool)
  Text(String)
} derive(Eq, @debug.Debug)

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
pub fn Value::text(self : Value) -> String {
  match self {
    Number(n) => n.to_string()
    Flag(b) => b.to_string()
    Text(s) => s
  }
}

///|
fn Value::kind(self : Value) -> Int32 {
  match self {
    Number(_) => 0
    Flag(_) => 1
    Text(_) => 2
  }
}

///|
priv enum Expr {
  Lit(Value)
  Read(String)
  Unary(String, Expr)
  Binary(String, Expr, Expr)
}

///|
priv struct ExprParser {
  ts : Array[Token]
  line : Int32
  mut pos : Int32
}

///|
fn precedence(op : String) -> Int32 {
  match op {
    "||" => 1
    "&&" => 2
    "==" | "!=" => 3
    "<" | "<=" | ">" | ">=" => 4
    "+" | "-" => 5
    _ => 0
  }
}

///|
fn ExprParser::take(self : ExprParser, word : String) -> Bool {
  if self.pos < self.ts.length() && self.ts[self.pos].kind == Word(word) {
    self.pos = self.pos + 1
    true
  } else {
    false
  }
}

///|
fn ExprParser::parse(
  self : ExprParser,
  minimum : Int32,
  depth : Int32,
) -> Expr raise StoryError {
  if depth > 32 {
    raise Limit("expression nesting exceeds 32")
  }
  if self.pos >= self.ts.length() {
    raise Syntax(self.line, 1, "expected expression")
  }
  let tok = self.ts[self.pos]
  self.pos = self.pos + 1
  let mut left = match tok.kind {
    Quoted(s) => Lit(Text(s))
    Word("true") => Lit(Flag(true))
    Word("false") => Lit(Flag(false))
    Word("(") => {
      let inner = self.parse(1, depth + 1)
      if !self.take(")") {
        raise Syntax(self.line, tok.col, "missing closing parenthesis")
      }
      inner
    }
    Word("!" | "-" as op) =>
      // Permit the negative Int32 boundary without first overflowing its positive magnitude.
      if op == "-" &&
        self.pos < self.ts.length() &&
        self.ts[self.pos].kind == Word("2147483648") {
        self.pos = self.pos + 1
        Lit(Number(-2147483648))
      } else {
        Unary(op, self.parse(6, depth + 1))
      }
    Word(s) =>
      if identifier(s) {
        Read(s)
      } else {
        let n = @string.parse_int(s[:]) catch {
          _ => raise Syntax(self.line, tok.col, "invalid Int32 literal")
        }
        Lit(Number(n))
      }
  }
  while self.pos < self.ts.length() {
    guard self.ts[self.pos].kind is Word(op) else { break }
    let p = precedence(op)
    if p < minimum || p == 0 {
      break
    }
    self.pos = self.pos + 1
    left = Binary(op, left, self.parse(p + 1, depth + 1))
  }
  left
}

///|
fn expression(ts : Array[Token], line : Int32) -> Expr raise StoryError {
  let p = ExprParser::{ ts, line, pos: 0, }
  let e = p.parse(1, 0)
  if p.pos != ts.length() {
    raise Syntax(line, ts[p.pos].col, "unexpected token after expression")
  }
  e
}

///|
fn expr_kind(
  e : Expr,
  vars : Map[String, Value],
  line : Int32,
) -> Int32 raise StoryError {
  match e {
    Lit(v) => v.kind()
    Read(name) =>
      match vars.get(name) {
        Some(v) => v.kind()
        None => raise Type(line, "undeclared variable " + name)
      }
    Unary(op, a) => {
      let kind = expr_kind(a, vars, line)
      let wanted = if op == "!" { 1 } else { 0 }
      if kind != wanted {
        raise Type(line, "invalid operand for " + op)
      }
      wanted
    }
    Binary(op, a, b) => {
      let ka = expr_kind(a, vars, line)
      let kb = expr_kind(b, vars, line)
      if ka != kb {
        raise Type(line, "operands have different types")
      }
      match op {
        "&&" | "||" => {
          if ka != 1 {
            raise Type(line, "boolean operands required")
          }
          1
        }
        "==" | "!=" => 1
        "<" | "<=" | ">" | ">=" => {
          if ka != 0 {
            raise Type(line, "integer comparison required")
          }
          1
        }
        "+" => {
          if ka == 1 {
            raise Type(line, "cannot add booleans")
          }
          ka
        }
        _ => {
          if ka != 0 {
            raise Type(line, "integer operands required")
          }
          0
        }
      }
    }
  }
}

///|
fn checked(n : Int64) -> Value raise StoryError {
  if n < -2147483648L || n > 2147483647L {
    raise Runtime("overflow", "Int32 arithmetic overflow")
  }
  Number(n.to_int())
}

///|
fn eval(e : Expr, vars : Map[String, Value]) -> Value raise StoryError {
  match e {
    Lit(v) => v
    Read(name) =>
      match vars.get(name) {
        Some(v) => v
        None => raise Runtime("variable", "missing " + name)
      }
    Unary("!", a) =>
      match eval(a, vars) {
        Flag(b) => Flag(!b)
        _ => raise Runtime("type", "expected boolean")
      }
    Unary(_, a) =>
      match eval(a, vars) {
        Number(n) => checked(-n.to_int64())
        _ => raise Runtime("type", "expected integer")
      }
    Binary(op, a, b) => {
      let va = eval(a, vars)
      if op == "&&" && va == Flag(false) {
        return Flag(false)
      }
      if op == "||" && va == Flag(true) {
        return Flag(true)
      }
      let vb = eval(b, vars)
      if op == "==" {
        return Flag(va == vb)
      }
      if op == "!=" {
        return Flag(va != vb)
      }
      match (va, vb) {
        (Number(x), Number(y)) =>
          match op {
            "+" => checked(x.to_int64() + y.to_int64())
            "-" => checked(x.to_int64() - y.to_int64())
            "<" => Flag(x < y)
            "<=" => Flag(x <= y)
            ">" => Flag(x > y)
            _ => Flag(x >= y)
          }
        (Text(x), Text(y)) => {
          if x.length() + y.length() > 262144 {
            raise Limit("string value exceeds 262144 code units")
          }
          Text(x + y)
        }
        (Flag(x), Flag(y)) => Flag(if op == "&&" { x && y } else { x || y })
        _ => raise Runtime("type", "invalid expression operands")
      }
    }
  }
}
