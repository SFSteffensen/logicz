#import "@preview/cetz:0.5.2"
#import "geometry.typ": *

/// Draw one gate inside a CeTZ canvas.
///
/// `pos` is the left end of the input pins, at the vertical centre of the
/// gate. The gate is a CeTZ group with anchors `in1` .. `inN` (top to bottom)
/// and `out`, so with `name: "g"` you can connect to `"g.in2"` or `"g.out"`.
///
/// - kind (str): `"and"`, `"nand"`, `"or"`, `"nor"`, `"xor"`, `"xnor"`, `"not"` or `"buf"`.
/// - inputs (int, auto): number of inputs; `auto` is 1 for not/buf, else 2.
/// - inverted (array): 1-based input indices that get an inversion bubble.
/// - stroke (stroke): outline of the body and bubbles.
/// - wire (stroke): stroke of the pin stubs.
/// - fill (color, none): body fill.
#let gate(kind, pos, inputs: auto, inverted: (), name: none, stroke: 0.8pt, wire: 0.6pt, fill: white) = {
  let (body-stroke, body-fill) = (stroke, fill) // cetz.draw exports fill() and stroke()
  import cetz.draw: *
  assert(kind in GATES, message: "logicz: unknown gate '" + kind + "' (known: " + GATES.keys().join(", ") + ")")
  let n = if inputs == auto { default-inputs(kind) } else { inputs }
  let g = gate-geometry(kind, n)
  let (x0, tip, h) = (g.x0, g.tip, g.half)
  let k = 0.5523 // cubic bezier approximation of a quarter circle

  group(name: name, {
    set-origin(pos)
    set-style(stroke: body-stroke)

    // input pins (+ optional bubbles)
    for (i, v) in g.pins.enumerate() {
      let bx = back-x(g, v)
      if (i + 1) in inverted {
        line((0, v), (bx - 2 * bubble, v), stroke: wire)
        circle((bx - bubble, v), radius: bubble, fill: body-fill)
      } else {
        line((0, v), (bx, v), stroke: wire)
      }
      anchor("in" + str(i + 1), (0, v))
    }

    // input extension lines (IEEE 91 style) for many-input gates
    if g.ext > h {
      let ex = if g.shape == "xor" { stub } else { x0 }
      line((ex, h), (ex, g.ext))
      line((ex, -h), (ex, -g.ext))
    }

    // body
    if g.shape == "and" {
      let a = tip - 0.5 // start of the semicircle
      merge-path(close: true, fill: body-fill, {
        line((x0, -0.5), (a, -0.5))
        bezier((a, -0.5), (tip, 0), (a + k * 0.5, -0.5), (tip, -k * 0.5))
        bezier((tip, 0), (a, 0.5), (tip, k * 0.5), (a + k * 0.5, 0.5))
        line((a, 0.5), (x0, 0.5))
      })
    } else if g.shape in ("or", "xor") {
      let L = tip - x0
      merge-path(close: true, fill: body-fill, {
        bezier((x0, -0.5), (x0, 0.5), (x0 + 2 * or-depth, 0))
        bezier((x0, 0.5), (tip, 0), (x0 + 0.45 * L, 0.5), (x0 + 0.8 * L, 0.3))
        bezier((tip, 0), (x0, -0.5), (x0 + 0.8 * L, -0.3), (x0 + 0.45 * L, -0.5))
      })
      if g.shape == "xor" {
        bezier((stub, -0.5), (stub, 0.5), (stub + 2 * or-depth, 0), fill: none)
      }
    } else {
      line((x0, -h), (tip, 0), (x0, h), close: true, fill: body-fill)
    }

    // output (+ bubble)
    let ox = tip
    if g.neg {
      circle((tip + bubble, 0), radius: bubble, fill: body-fill)
      ox = tip + 2 * bubble
    }
    line((ox, 0), (g.len, 0), stroke: wire)
    anchor("out", (g.len, 0))
  })
}

/// A single gate as inline content, e.g. in text or a table.
///
/// - size (length): the height of a 2-input gate body.
/// - ..args: passed on to `gate()`.
#let gate-symbol(kind, inputs: auto, size: 0.45cm, ..args) = box(baseline: 30%, cetz.canvas(length: size, gate(kind, (0, 0), inputs: inputs, ..args)))
