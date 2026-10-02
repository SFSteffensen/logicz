// The netlist language.

//   in  a b c              // optional: fixes the input order
//   out y z                // optional: default = named gates nobody uses
//   y  = or(a, and(b, c))  // gates nest like function calls
//   n1 = nand(a, !b)       // !x (or ~x) = inversion bubble on that input
//
// Any name that is never assigned is a primary input. Identical
// sub-expressions are shared (one gate, fan-out).

#import "geometry.typ": GATES

#let ident = "[A-Za-z_][A-Za-z0-9_']*"

#let tokenize(line) = {
  let toks = line.matches(regex(ident + "|[(),!~=]|\S")).map(m => m.text)
  let bad = toks.filter(t => t.match(regex("^(" + ident + "|[(),!~=])$")) == none)
  assert(bad.len() == 0, message: "logicz: unexpected '" + bad.join() + "' in: " + line)
  toks
}

// expr := {'!' | '~'} ( ident | ident '(' expr {',' expr} ')' )
#let parse-expr(toks, i) = {
  assert(i < toks.len(), message: "logicz: unexpected end of line")
  let inv = false
  while toks.at(i) in ("!", "~") {
    inv = not inv
    i += 1
    assert(i < toks.len(), message: "logicz: unexpected end of line after '!'")
  }
  let id = toks.at(i)
  assert(id.match(regex("^" + ident + "$")) != none, message: "logicz: expected a name but got '" + id + "'")
  i += 1
  if i < toks.len() and toks.at(i) == "(" {
    i += 1
    let args = ()
    while true {
      let (e, j) = parse-expr(toks, i)
      args.push(e)
      i = j
      assert(i < toks.len(), message: "logicz: missing ')' after " + id)
      if toks.at(i) == ")" { i += 1; break }
      assert(toks.at(i) == ",", message: "logicz: expected ',' or ')' but got '" + toks.at(i) + "'")
      i += 1
      if i < toks.len() and toks.at(i) == ")" { i += 1; break } // trailing comma
    }
    ((call: lower(id), args: args, inv: inv), i)
  } else {
    ((ref: id, inv: inv), i)
  }
}

// Lower an expression into gates. Returns (pin, state); a pin is (src, inv).
#let lower-expr(e, st, name: none) = {
  if "ref" in e {
    st.refs.push(e.ref)
    return ((src: e.ref, inv: e.inv), st)
  }
  assert(e.call in GATES, message: "logicz: unknown gate '" + e.call + "' (known: " + GATES.keys().join(", ") + ")")
  let ins = ()
  for a in e.args {
    let (p, s) = lower-expr(a, st)
    st = s
    ins.push(p)
  }
  if GATES.at(e.call).shape == "tri" {
    assert(ins.len() == 1, message: "logicz: " + e.call + "() takes exactly one input")
  }
  let pin-key(p) = (if p.inv { "!" } else { "" }) + p.src
  let key = e.call + "(" + ins.map(pin-key).sorted().join(",") + ")"
  let gname = name
  if gname == none {
    gname = st.keys.at(key, default: none)
    if gname == none {
      st.count += 1
      gname = "_g" + str(st.count)
    }
  }
  if gname not in st.gates {
    st.gates.insert(gname, (kind: e.call, ins: ins))
    if key not in st.keys { st.keys.insert(key, gname) }
  }
  ((src: gname, inv: e.inv), st)
}

/// Parse netlist source into `(gates, inputs, outputs)`.
/// `gates` maps a name to `(kind, ins)`, where each input is `(src, inv)`.
#let parse(src) = {
  let st = (gates: (:), keys: (:), refs: (), count: 0)
  let ins = none
  let outs = none
  // a statement continues onto the next line while parentheses are open
  let stmts = ()
  let pending = ""
  for raw-line in src.split("\n") {
    pending += " " + raw-line.split("//").first()
    let depth = pending.matches("(").len() - pending.matches(")").len()
    if depth <= 0 and pending.trim() != "" {
      stmts.push(pending.trim())
      pending = ""
    }
  }
  assert(pending.trim() == "", message: "logicz: missing ')' in: " + pending.trim())
  for line in stmts {
    let toks = tokenize(line)
    if toks.first() in ("in", "inputs") {
      ins = toks.slice(1).filter(t => t != ",")
    } else if toks.first() in ("out", "outputs") {
      outs = toks.slice(1).filter(t => t != ",")
    } else {
      assert(toks.len() >= 3 and toks.at(1) == "=",
        message: "logicz: expected `name = gate(...)` but got: " + line)
      let name = toks.first()
      assert(name not in st.gates, message: "logicz: '" + name + "' is defined twice")
      let (e, j) = parse-expr(toks, 2)
      assert(j == toks.len(), message: "logicz: trailing tokens in: " + line)
      assert("call" in e and not e.inv,
        message: "logicz: right-hand side must be a gate call, e.g. `" + name + " = buf(x)`")
      let (_, s) = lower-expr(e, st, name: name)
      st = s
    }
  }
  let gates = st.gates
  // primary inputs: declared order first, then order of appearance
  let inputs = if ins == none { () } else { ins }
  for i in inputs { assert(i not in gates, message: "logicz: '" + i + "' is declared as an input but also assigned") }
  for r in st.refs {
    if r not in gates and r not in inputs { inputs.push(r) }
  }
  let used = gates.values().map(g => g.ins.map(p => p.src)).flatten()
  if outs == none {
    outs = gates.keys().filter(g => not g.starts-with("_g") and g not in used)
  }
  for o in outs { assert(o in gates or o in inputs, message: "logicz: unknown output '" + o + "'") }
  (gates: gates, inputs: inputs, outputs: outs)
}
