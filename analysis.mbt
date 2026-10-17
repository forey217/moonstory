///|
pub struct Diagnostic {
  code : String
  node : String
  line : Int32
  message : String
} derive(Eq, @debug.Debug)

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
fn successors(story : Story, pc : Int32) -> Array[Int32] {
  let out = []
  match story.code[pc].op {
    End(_) => ()
    Jump(t) => if story.labels.get(t) is Some(dest) { out.push(dest) }
    Branch(_, t) | Pick(_, _, t, _) => {
      if story.labels.get(t) is Some(dest) {
        out.push(dest)
      }
      match story.code[pc].op {
        Branch(_, _) => out.push(pc + 1)
        _ =>
          if pc + 1 < story.code.length() &&
            story.code[pc + 1].node == story.code[pc].node {
            // Later alternatives in a contiguous choice group are also possible.
            out.push(pc + 1)
          }
      }
    }
    _ => out.push(pc + 1)
  }
  out
}

///|
fn walk_graph(edges : Array[Array[Int32]], seeds : Array[Int32]) -> Array[Bool] {
  let seen = Array::make(edges.length(), false)
  let queue = seeds.copy()
  for seed in seeds {
    seen[seed] = true
  }
  let mut head = 0
  while head < queue.length() {
    let pc = queue[head]
    head = head + 1
    for next in edges[pc] {
      if !seen[next] {
        seen[next] = true
        queue.push(next)
      }
    }
  }
  seen
}

///|
/// Structural analysis ignores condition truth and does not prove playability.
pub fn Story::diagnostics(self : Story) -> Array[Diagnostic] {
  let edges : Array[Array[Int32]] = []
  let reverse : Array[Array[Int32]] = []
  let endings = []
  for i = 0; i < self.code.length(); i = i + 1 {
    edges.push(successors(self, i))
    reverse.push([])
    if self.code[i].op is End(_) {
      endings.push(i)
    }
  }
  for i = 0; i < edges.length(); i = i + 1 {
    for dest in edges[i] {
      reverse[dest].push(i)
    }
  }
  let reachable = walk_graph(edges, [0])
  let can_end = walk_graph(reverse, endings)
  let out = []
  for node in self.order {
    if self.labels.get(node) is Some(pc) {
      if !reachable[pc] {
        out.push({
          code: "unreachable",
          node,
          line: self.code[pc].line,
          message: "node has no structural path from entry",
        })
      }
      if !can_end[pc] {
        out.push({
          code: "no_end_path",
          node,
          line: self.code[pc].line,
          message: "node has no structural path to an end instruction",
        })
      }
    }
  }
  out
}
