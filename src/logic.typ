#import "@preview/cetz:0.5.2"
#import "geometry.typ": stub
#import "gate.typ": gate
#import "parse.typ": parse
#import "layout.typ": layout-netlist

/// Draw a gate-level circuit from a netlist.
///
/// ```typ
/// #logic(```
///   in a b c
///   y = or(a, and(b, c))
/// ```)
/// ```
///
/// - src (raw, str): the netlist (see the manual for the syntax).
/// - extra (none, cetz): drawn on top, in the same CeTZ coordinates. Gates and
///   inputs are named groups, so e.g. `content("y.out", ..)` works.
///
/// All lengths other than `unit`, strokes and `label-size` are in units of
/// `unit`, where a 2-input gate is 1 unit tall.
#let logic(
  src,
  unit: 0.55cm,
  gate-stroke: 0.8pt,
  wire-stroke: 0.6pt,
  fill: white,
  label-size: 10pt,
  math-labels: true, // render signal names as $a$
  show-names: false, // print gate names above the gates (debugging)
  input-sep: 1.0, // vertical distance between primary inputs
  gate-sep: 0.6, // minimum free space between stacked gates
  wire-sep: 0.45, // minimum distance for wires passing a layer
  track: 0.28, // distance between vertical wire tracks
  min-gap: 0.9, // minimum horizontal gap between layers
  dot: 0.065, // junction dot radius
  layering: "alap", // "alap": gates next to their consumers, "asap": next to their inputs
  snap: 2, // max distance a group of gates may move to straighten a wire
  sweeps: 4, // placement refinement passes (0 = inputs stay stacked)
  extra: none,
) = {
  let src = if type(src) == str { src } else { src.text }
  let cfg = (
    input-sep: input-sep,
    gate-sep: gate-sep,
    wire-sep: wire-sep,
    track: track,
    min-gap: min-gap,
    sweeps: sweeps,
    layering: layering,
    snap: snap,
  )
  let net = parse(src)
  let lay = layout-netlist(net, cfg)
  let (nodes, layers, y, pin-y, gaps, X, W) = lay
  let P(x, yy) = (x, -yy) // layout is y-down, CeTZ is y-up
  // a, b', x1 -> $a$, $b'$, $x_1$; anything else stays plain text
  let lbl(s) = text(size: label-size, if not math-labels { s } else if s.match(regex("^[A-Za-z]'*$")) != none {
    eval(s, mode: "math")
  } else if s.match(regex("^[A-Za-z][0-9]+$")) != none {
    eval(s.first() + "_" + s.slice(1), mode: "math")
  } else { s })

  let out-x(id) = {
    let n = nodes.at(id)
    let x = X.at(n.layer)
    if n.type == "dummy" { x + W.at(n.layer) } else { x + n.len }
  }

  let gate-fill = fill
  cetz.canvas(
    length: unit,
    {
      import cetz.draw: *
      set-style(stroke: wire-stroke)

      // wires between layers
      for (L, gap) in gaps.enumerate() {
        let x-end = X.at(L + 1)
        let x-start = X.at(L) + W.at(L)
        for (s, net) in gap.nets {
          let sx = out-x(s)
          let k = gap.track.at(s, default: none)
          if k == none {
            line(P(sx, net.y), P(x-end, net.y))
            continue
          }
          let tx = x-start + (k + 1) * gap.width / (gap.ntracks + 1)
          let ys = (net.y, ..net.ts)
          let (y0, y1) = (calc.min(..ys), calc.max(..ys))
          line(P(sx, net.y), P(tx, net.y))
          line(P(tx, y0), P(tx, y1))
          for t in net.ts {
            line(P(tx, t), P(x-end, t))
          }
          // a dot wherever three or more segments meet
          for yy in ys.dedup() {
            let deg = ys.filter(v => v == yy).len()
            deg += (if yy > y0 { 1 } else { 0 }) + (if yy < y1 { 1 } else { 0 })
            if deg >= 3 { circle(P(tx, yy), radius: dot, fill: black, stroke: none) }
          }
        }
      }

      // nodes
      for L in range(layers.len()) {
        for id in layers.at(L) {
          let n = nodes.at(id)
          let x = X.at(L)
          let yy = y.at(id)
          if n.type == "input" {
            group(name: id, {
              line(P(x, yy), P(x + stub, yy))
              content(P(x, yy), lbl(id), anchor: "east", padding: 0.12)
              anchor("out", P(x + stub, yy))
            })
          } else if n.type == "output" {
            line(P(x, yy), P(x + stub, yy))
            content(P(x + stub, yy), lbl(n.label), anchor: "west", padding: 0.12)
          } else if n.type == "dummy" {
            line(P(x, yy), P(x + W.at(L), yy))
          } else {
            let inv = range(n.pins.len()).filter(k => n.pins.at(k).inv).map(k => k + 1)
            gate(
              n.kind,
              P(x, yy),
              inputs: n.pins.len(),
              inverted: inv,
              name: id,
              stroke: gate-stroke,
              wire: wire-stroke,
              fill: gate-fill,
            )
            if show-names {
              content(P(x + n.geom.x0 + 0.5, yy - n.geom.ext), text(size: 0.7 * label-size, raw(id)), anchor: "south", padding: 0.08)
            }
          }
        }
      }

      if extra != none { extra }
    },
  )
}
