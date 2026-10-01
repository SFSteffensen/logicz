// Layout quality: no overlapping wire segments, no tiny jogs.
#import "/src/parse.typ": parse
#import "/src/layout.typ": layout-netlist

#let cfg = (input-sep: 1.0, gate-sep: 0.6, wire-sep: 0.45, track: 0.28, min-gap: 0.9,
  sweeps: 4, layering: "alap", snap: 2)

#let check(name, src) = {
  let lay = layout-netlist(parse(src), cfg)
  for (L, gap) in lay.gaps.enumerate() {
    // horizontal segments in this gap: (y, x0, x1, net), x in [0, 1]
    let segs = ()
    for (s, net) in gap.nets {
      let k = gap.track.at(s, default: none)
      let tx = if k == none { 1 } else { (k + 1) / (gap.ntracks + 1) }
      segs.push((net.y, 0, tx, s))
      for t in net.ts { segs.push((t, if k == none { 0 } else { tx }, 1, s)) }
    }
    for (i, a) in segs.enumerate() {
      for b in segs.slice(i + 1) {
        if a.at(3) != b.at(3) and calc.abs(a.at(0) - b.at(0)) < 1e-3 {
          assert(calc.min(a.at(2), b.at(2)) - calc.max(a.at(1), b.at(1)) < 1e-6,
            message: name + ": nets " + a.at(3) + " and " + b.at(3) + " overlap in gap " + str(L))
        }
      }
    }
  }
  for (id, n) in lay.nodes {
    for (k, p) in n.pins.enumerate() {
      let d = calc.abs(lay.y.at(p.src) - lay.pin-y.at(id).at(k))
      assert(d < 1e-6 or d > 0.3, message: name + ": tiny jog of " + str(d) + " on " + p.src + " -> " + id)
    }
  }
}

#check("nand-xor", "in a b\nm = nand(a, b)\ny = nand(nand(a, m), nand(b, m))")
#check("full-adder", "in a b cin\np = xor(a, b)\ns = xor(p, cin)\ncout = or(and(a, b), and(p, cin))")
#check("sop", "in a b c\ny = or(a, and(b, c))\nz = or(and(a, b), and(not(b), c), and(b, not(c)))")
#check("bubbles", "z = or(and(a, b), and(!b, c), and(b, !c))")
#check("mux", "in d0 d1 s\ny = or(and(d0, not(s)), and(d1, s))")
#check("decoder", "in a1 a0\nd0 = and(!a1, !a0)\nd1 = and(!a1, a0)\nd2 = and(a1, !a0)\nd3 = and(a1, a0)")
#check("wide", "p = and(a, b, c, d, e)\nq = or(p, f)\nout p q")

ok
