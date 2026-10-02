// Gate geometry for the IEEE Std 91/91a-1991 distinctive-shape symbols.

#let stub = 0.3 // pin wire length outside the body
#let bubble = 0.09 // inversion bubble radius
#let xor-gap = 0.18 // gap between the XOR's extra curve and the body
#let or-depth = 0.16 // how far the OR back curve bulges into the body

/// Every supported gate: its body shape and whether the output is negated.
#let GATES = (
  "and": (shape: "and", neg: false),
  "nand": (shape: "and", neg: true),
  "or": (shape: "or", neg: false),
  "nor": (shape: "or", neg: true),
  "xor": (shape: "xor", neg: false),
  "xnor": (shape: "xor", neg: true),
  "buf": (shape: "tri", neg: false),
  "not": (shape: "tri", neg: true),
)

#let body-len = ("and": 1.05, "or": 1.2, "xor": 1.2, "tri": 0.62)

#let default-inputs(kind) = if GATES.at(kind).shape == "tri" { 1 } else { 2 }

/// Geometry of a gate with `n` inputs. Pin offsets are y-up relative to the
/// gate centre, top pin first; x is measured from the input pin ends.
#let gate-geometry(kind, n) = {
  assert(kind in GATES, message: "logicz: unknown gate '" + kind + "' (known: " + GATES.keys().join(", ") + ")")
  let k = GATES.at(kind)
  if k.shape == "tri" { assert(n == 1, message: "logicz: " + kind + " takes exactly one input") }
  assert(n >= 1, message: "logicz: " + kind + " needs at least one input")
  let pitch = if n <= 2 { 0.5 } else if n == 3 { 1 / 3 } else { 0.28 }
  let pins = range(n).map(i => ((n - 1) / 2 - i) * pitch)
  let half = if k.shape == "tri" { 0.35 } else { 0.5 }
  // IEEE input extension: the back line grows when the pins do not fit
  let ext = calc.max(half, (n - 1) * pitch / 2 + pitch / 2)
  let x0 = stub + if k.shape == "xor" { xor-gap } else { 0 }
  let tip = x0 + body-len.at(k.shape)
  let len = tip + (if k.neg { 2 * bubble } else { 0 }) + stub
  (shape: k.shape, neg: k.neg, pins: pins, half: half, ext: ext, x0: x0, tip: tip, len: len)
}

/// x where an input pin at height `v` meets the body (the back curve for OR / XOR).
#let back-x(g, v) = {
  let base = if g.shape == "xor" { stub } else { g.x0 }
  if g.shape in ("or", "xor") and calc.abs(v) < 0.5 {
    base + or-depth * (1 - calc.pow(2 * v, 2))
  } else { base }
}
