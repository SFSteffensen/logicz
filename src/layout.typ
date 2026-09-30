// Layered ("Sugiyama-style") layout for gate netlists.
//
//  1. layering:  inputs in column 0; gates as late as possible (or as soon)
//  2. dummies:   wires spanning several columns get a pass-through node per
//                crossed column, so gates never sit on top of them
//  3. placement: ordered least-squares placement per column, refined by
//                alternating sweeps, then snapped to make wires straight
//  4. routing:   orthogonal wires; each bending net gets its own vertical
//                track in the gap between two columns
//
// Coordinates here are y-down; the renderer flips them for CeTZ.

#import "geometry.typ": gate-geometry, stub

#let layout-netlist(net, cfg) = {
  let (gates, inputs, outputs) = net

  // 1. layer = longest path from the inputs
  let level = (:)
  for i in inputs {
    level.insert(i, 0)
  }
  for g in gates.keys() {
    level.insert(g, 1)
  }
  let changed = true
  let rounds = 0
  while changed {
    changed = false
    rounds += 1
    assert(rounds <= gates.len() + 2, message: "circuitz: combinational loop detected")
    for (g, gate) in gates {
      let l = 1 + calc.max(..gate.ins.map(p => level.at(p.src)))
      if l != level.at(g) { level.insert(g, l); changed = true }
    }
  }
  let max-level = calc.max(0, ..gates.keys().map(g => level.at(g)))
  if cfg.layering == "alap" {
    // pull every gate as close to its consumers as possible, so that gates
    // doing the same job line up in one column (NOTs, then ANDs, then ORs)
    let users = (:)
    for (g, gate) in gates {
      for p in gate.ins {
        if p.src in gates { users.insert(p.src, users.at(p.src, default: ()) + (g,)) }
      }
    }
    let changed = true
    while changed {
      changed = false
      for g in gates.keys() {
        let l = if g in users {
          calc.min(..users.at(g).map(u => level.at(u))) - 1
        } else { max-level }
        if l != level.at(g) { level.insert(g, l); changed = true }
      }
    }
  }
  let out-layer = max-level + 1
  let nlayers = out-layer + 1

  // 2. nodes; long wires get one dummy per crossed layer (shared per signal)
  let nodes = (:)
  let layers = range(nlayers).map(_ => ())
  for i in inputs {
    nodes.insert(i, (type: "input", layer: 0, pins: (), len: stub))
    layers.at(0).push(i)
  }
  let consumers = gates.pairs().map(((g, gate)) => (id: g, type: "gate", kind: gate.kind, layer: level.at(g), ins: gate.ins))
  consumers += outputs.map(o => (id: "»" + o, type: "output", label: o, layer: out-layer, ins: ((src: o, inv: false),)))
  for c in consumers {
    let pins = ()
    for p in c.ins {
      let s = p.src
      for l in range(level.at(p.src) + 1, c.layer) {
        let did = "~" + p.src + "@" + str(l)
        if did not in nodes {
          nodes.insert(did, (type: "dummy", layer: l, pins: ((src: s, inv: false),), len: 0))
          layers.at(l).push(did)
        }
        s = did
      }
      pins.push((src: s, inv: p.inv))
    }
    let n = (type: c.type, layer: c.layer, pins: pins)
    if c.type == "gate" {
      let g = gate-geometry(c.kind, pins.len())
      n += (kind: c.kind, geom: g, len: g.len)
    } else { n += (label: c.label, len: stub) }
    nodes.insert(c.id, n)
    layers.at(c.layer).push(c.id)
  }

  // 3. vertical placement (y grows downwards here). One forward sweep puts
  //    every node at the mean of its drivers; then alternating backward /
  //    forward sweeps pull nodes towards drivers *and* consumers. Each layer
  //    is solved as an ordered least-squares problem with minimum spacing.
  let y = (:)
  for (k, i) in inputs.enumerate() {
    y.insert(i, k * cfg.input-sep)
  }
  let half(n) = if n.type == "gate" { n.geom.ext + cfg.gate-sep / 2 } else if n.type == "dummy" { cfg.wire-sep / 2 } else if n.type == "input" { cfg.input-sep / 2 } else { 0.35 }
  let mean(a) = a.sum() / a.len()
  let pins-of(id, n, y) = if n.type == "gate" { n.geom.pins.map(v => y.at(id) - v) } else { (y.at(id),) }
  let passes = (("down", false),) + range(cfg.sweeps).map(_ => (("up", true), ("down", true))).flatten().chunks(2)
  for (dir, both) in passes {
    let order = if dir == "down" { range(1, nlayers) } else { range(nlayers - 1).rev() }
    for L in order {
      let items = layers.at(L).map(id => {
        let n = nodes.at(id)
        let wants = ()
        if n.pins.len() > 0 { wants.push(mean(n.pins.map(p => y.at(p.src)))) }
        if both and L + 1 < nlayers {
          let ts = ()
          for c in layers.at(L + 1) {
            let cn = nodes.at(c)
            let py = pins-of(c, cn, y)
            for (k, p) in cn.pins.enumerate() {
              if p.src == id { ts.push(py.at(k)) }
            }
          }
          if ts.len() > 0 { wants.push(mean(ts)) }
        }
        (id: id, want: if wants.len() > 0 { mean(wants) } else { y.at(id) }, half: half(n))
      })
      if L > 0 { items = items.sorted(key: it => it.want) } // inputs keep their order
      let blocks = ()
      for it in items {
        let b = (items: (it,), offs: (0,), p: it.want)
        while blocks.len() > 0 {
          let pb = blocks.last()
          let base = pb.offs.last() + pb.items.last().half + b.items.first().half
          if pb.p + base <= b.p { break }
          let its = pb.items + b.items
          let offs = pb.offs + b.offs.map(o => o + base)
          let p = mean(range(its.len()).map(k => its.at(k).want - offs.at(k)))
          b = (items: its, offs: offs, p: p)
          let _ = blocks.pop()
        }
        blocks.push(b)
      }
      for b in blocks {
        for (k, it) in b.items.enumerate() {
          y.insert(it.id, b.p + b.offs.at(k))
        }
      }
      layers.at(L) = items.map(it => it.id)
      // commutative gates take their sources top-to-bottom
      for Lc in (L, L + 1) {
        if Lc < 1 or Lc >= nlayers { continue }
        for id in layers.at(Lc) {
          if nodes.at(id).type == "gate" {
            nodes.at(id).pins = nodes.at(id).pins.sorted(key: p => y.at(p.src))
          }
        }
      }
    }
  }
  // 3b. straighten: shift a node so one of its wires becomes exactly
  //     horizontal, if that fits between its neighbours. Removes small jogs.
  for _ in range(2) {
    for L in range(nlayers) {
      let ids = layers.at(L)
      for (i, id) in ids.enumerate() {
        let n = nodes.at(id)
        let cands = ()
        if L == 0 {
          for c in layers.at(1) {
            let cn = nodes.at(c)
            let py = pins-of(c, cn, y)
            for (k, p) in cn.pins.enumerate() {
              if p.src == id { cands.push(py.at(k) - y.at(id)) }
            }
          }
        } else {
          let py = pins-of(id, n, y)
          for (k, p) in n.pins.enumerate() {
            cands.push(y.at(p.src) - py.at(k))
          }
        }
        let limit = if n.type == "gate" and n.pins.len() > 1 { cfg.snap } else { 3 * cfg.snap }
        let lo = if i > 0 { y.at(ids.at(i - 1)) + half(nodes.at(ids.at(i - 1))) + half(n) } else { -1e9 }
        let hi = if i + 1 < ids.len() { y.at(ids.at(i + 1)) - half(nodes.at(ids.at(i + 1))) - half(n) } else { 1e9 }
        let ok = cands.filter(d => calc.abs(d) <= limit and y.at(id) + d >= lo - 1e-9 and y.at(id) + d <= hi + 1e-9)
        if ok.len() > 0 {
          let d = ok.sorted(key: calc.abs).first()
          y.insert(id, y.at(id) + d)
        }
      }
    }
  }
  for id in nodes.keys() {
    if nodes.at(id).type == "gate" {
      nodes.at(id).pins = nodes.at(id).pins.sorted(key: p => y.at(p.src))
    }
  }
  let pin-y = (:)
  for (id, n) in nodes {
    if n.type != "input" { pin-y.insert(id, pins-of(id, n, y)) }
  }

  // 4. nets between neighbouring layers; each bending net gets its own track
  let gaps = ()
  for L in range(nlayers - 1) {
    let nets = (:)
    for id in layers.at(L + 1) {
      for (k, p) in nodes.at(id).pins.enumerate() {
        if p.src not in nets { nets.insert(p.src, (y: y.at(p.src), ts: ())) }
        nets.at(p.src).ts.push(pin-y.at(id).at(k))
      }
    }
    let bending = nets.pairs().filter(((_, n,)) => n.ts.any(t => calc.abs(t - n.y) > 1e-6))
    let down = bending.filter(((_, n,)) => n.ts.sum() / n.ts.len() > n.y).sorted(key: ((_, n,)) => -n.y)
    let up = bending.filter(((_, n,)) => n.ts.sum() / n.ts.len() <= n.y).sorted(key: ((_, n,)) => n.y)
    let order = (down + up).map(((s, _,)) => s)
    let w = calc.max(cfg.min-gap, (order.len() + 1) * cfg.track)
    gaps.push((nets: nets, order: order, width: w))
  }

  // 5. x positions
  let X = (0,)
  let W = ()
  for L in range(nlayers) {
    W.push(calc.max(0, ..layers.at(L).map(id => nodes.at(id).len)))
    if L < nlayers - 1 { X.push(X.at(L) + W.at(L) + gaps.at(L).width) }
  }

  (nodes: nodes, layers: layers, y: y, pin-y: pin-y, gaps: gaps, X: X, W: W)
}
