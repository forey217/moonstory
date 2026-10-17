///|
pub(all) suberror StoryError {
  Syntax(Int32, Int32, String)
  Type(Int32, String)
  Runtime(String, String)
  Limit(String)
  Save(String)
} derive(@debug.Debug)

///|
pub extend StoryError with @debug.Debug::{to_repr}

///|
priv enum TokenKind {
  Word(String)
  Quoted(String)
} derive(Eq)

///|
priv struct Token {
  kind : TokenKind
  col : Int32
}

///|
fn ident_start(c : UInt16) -> Bool {
  (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
}

///|
fn identifier(s : String) -> Bool {
  if s.is_empty() || !ident_start(s[0]) {
    return false
  }
  for i = 1; i < s.length(); i = i + 1 {
    if !ident_start(s[i]) && !(s[i] >= 48 && s[i] <= 57) {
      return false
    }
  }
  true
}

///|
fn lex(s : String, line : Int32) -> Array[Token] raise StoryError {
  let out = []
  let mut i = 0
  while i < s.length() {
    let c = s[i]
    if c == 32 || c == 9 || c == 13 {
      i = i + 1
      continue
    }
    if c == 35 && out.is_empty() {
      break
    }
    let begin = i
    if c == 34 {
      i = i + 1
      let mut closed = false
      while i < s.length() {
        if s[i] == 92 {
          i = i + 2
          continue
        }
        if s[i] == 34 {
          i = i + 1
          closed = true
          break
        }
        i = i + 1
      }
      if !closed {
        raise Syntax(line, begin + 1, "unterminated string")
      }
      let raw = s[begin:i].to_owned()
      let value = @json.parse(raw) catch {
        _ => raise Syntax(line, begin + 1, "invalid JSON string escape")
      }
      guard value is String(v) else {
        raise Syntax(line, begin + 1, "expected string")
      }
      out.push({ kind: Quoted(v), col: begin + 1, })
    } else if ident_start(c) || (c >= 48 && c <= 57) {
      i = i + 1
      while i < s.length() && (ident_start(s[i]) || (s[i] >= 48 && s[i] <= 57)) {
        i = i + 1
      }
      out.push({ kind: Word(s[begin:i].to_owned()), col: begin + 1, })
    } else {
      i = i + 1
      let mut op = s[begin:i].to_owned()
      if i < s.length() {
        let pair = s[begin:i + 1].to_owned()
        if ["::", "->", "==", "!=", "<=", ">=", "&&", "||"].contains(pair) {
          op = pair
          i = i + 1
        }
      }
      if ![
          "::", "->", "==", "!=", "<=", ">=", "&&", "||", "=", "<", ">", "+", "-",
          "!", "(", ")",
        ].contains(op) {
        raise Syntax(line, begin + 1, "unexpected character")
      }
      out.push({ kind: Word(op), col: begin + 1, })
    }
    if out.length() > 512 {
      raise Limit("more than 512 tokens on a line")
    }
  }
  out
}
