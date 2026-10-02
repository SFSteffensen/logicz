// Layered ("Sugiyama-style") layout for gate netlists.
//
//  1. layering:  inputs in column 0; gates as late as possible (or as soon)
//  2. dummies:   wires spanning several columns get a pass-through node per
//                crossed column, so gates never sit on top of them
//  3. placement: ordered L1 (weighted median) placement per column, refined
//                by alternating sweeps, then snapped to make wires straight
//  4. routing:   orthogonal wires; bending nets get vertical tracks in the
//                gap between two columns, ordered to avoid crossings and
//                overlaps, and shared when their extents are apart
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
    assert(rounds <= gates.len() + 2, message: "logicz: combinational loop detected")
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

  // 3. vertical placement (y grows downwards here). Every wire "wants" its
  //    two ends at the same height. Each column is solved as an ordered L1
  //    problem (weighted medians, pool-adjacent-violators): unlike a mean, a
  //    median lands exactly on one of the candidate heights, so most wires
  //    come out perfectly straight. Wires through pass-through nodes weigh
  //    more, keeping long wires straight. One forward sweep (drivers only),
  //    then alternating backward / forward sweeps (drivers and consumers).
  let y = (:)
  for (k, i) in inputs.enumerate() {
    y.insert(i, k * cfg.input-sep)
  }
  let half(n) = if n.type == "gate" { n.geom.ext + cfg.gate-sep / 2 } else if n.type == "dummy" { cfg.wire-sep / 2 } else if n.type == "input" { cfg.input-sep / 2 } else { 0.35 }
  let mean(a) = a.sum() / a.len()
  let pins-of(id, n, y) = if n.type == "gate" { n.geom.pins.map(v => y.at(id) - v) } else { (y.at(id),) }
  // offset of pin k from the node's reference height (0 for wires/labels)
  let pin-off(n, k) = if n.type == "gate" { -n.geom.pins.at(k) } else { 0 }
  let weight(a, b) = (1, 2, 8).at(int(nodes.at(a).type == "dummy") + int(nodes.at(b).type == "dummy"))
  // weighted median of (pos, w) pairs; inside a tie interval take the end
  // nearest to `ref`, so the result is always some wire's straight position
  let wmedian(cands, ref) = {
    let s = cands.sorted(key: c => c.at(0))
    let total = s.map(c => c.at(1)).sum()
    let acc = 0
    for i in range(s.len()) {
      acc += s.at(i).at(1)
      if calc.abs(2 * acc - total) < 1e-9 and i + 1 < s.len() {
        let (lo, hi) = (s.at(i).at(0), s.at(i + 1).at(0))
        return if calc.abs(ref - lo) <= calc.abs(ref - hi) + 1e-9 { lo } else { hi }
      }
      if 2 * acc > total { return s.at(i).at(0) }
    }
    s.last().at(0)
  }
  let passes = (("down", false),) + range(cfg.sweeps).map(_ => (("up", true), ("down", true))).flatten().chunks(2)
  for (pass, (dir, both)) in passes.enumerate() {
    let order = if dir == "down" { range(1, nlayers) } else { range(nlayers - 1).rev() }
    for L in order {
      let items = layers.at(L).map(id => {
        let n = nodes.at(id)
        let cands = ()
        for (k, p) in n.pins.enumerate() {
          cands.push((y.at(p.src) - pin-off(n, k), weight(id, p.src)))
        }
        if both and L + 1 < nlayers {
          for c in layers.at(L + 1) {
            let cn = nodes.at(c)
            let py = pins-of(c, cn, y)
            for (k, p) in cn.pins.enumerate() {
              if p.src == id { cands.push((py.at(k), weight(id, c))) }
            }
          }
        }
        if cands.len() == 0 { cands.push((y.at(id), 1)) }
        let cur = y.at(id, default: mean(cands.map(c => c.at(0))))
        (id: id, cands: cands, cur: cur, half: half(n), want: wmedian(cands, cur))
      })
      if L > 0 { items = items.sorted(key: it => it.want) } // inputs keep their order
      let blocks = ()
      for it in items {
        let b = (items: (it,), offs: (0,), p: it.want)
        while blocks.len() > 0 {
          let pb = blocks.last()
          let base = pb.offs.last() + pb.items.last().half + b.items.first().half
          if pb.p + base <= b.p + 1e-9 { break }
          let its = pb.items + b.items
          let offs = pb.offs + b.offs.map(o => o + base)
          let cands = range(its.len()).map(k => its.at(k).cands.map(((v, w)) => (v - offs.at(k), w))).join()
          let ref = mean(range(its.len()).map(k => its.at(k).cur - offs.at(k)))
          b = (items: its, offs: offs, p: wmedian(cands, ref))
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
  // 3b. straighten. Nodes joined by straight wires form rigid groups. Move a
  //     whole group up or down when that makes another wire straight, keeps
  //     every column's spacing and the pin order of every gate, and lowers
  //     the number of bent wires. Repeat until nothing improves.
  let wires = ()
  for (id, n) in nodes {
    for (k, p) in n.pins.enumerate() {
      wires.push((src: p.src, dst: id, k: k, w: weight(p.src, id)))
    }
  }
  let delta(wi, y) = y.at(wi.src) - y.at(wi.dst) - pin-off(nodes.at(wi.dst), wi.k)
  let badness(y) = wires.map(wi => {
    let d = calc.abs(delta(wi, y))
    if d > 1e-6 { wi.w * (1 + 0.05 * d) } else { 0 }
  }).sum(default: 0)
  let feasible(y) = {
    for ids in layers {
      for k in range(ids.len() - 1) {
        let (a, b) = (ids.at(k), ids.at(k + 1))
        if y.at(b) - y.at(a) < half(nodes.at(a)) + half(nodes.at(b)) - 1e-6 { return false }
      }
    }
    for (id, n) in nodes {
      if n.type == "gate" {
        let src = n.pins.map(p => y.at(p.src))
        for k in range(src.len() - 1) {
          if src.at(k) > src.at(k + 1) + 1e-6 { return false }
        }
      }
    }
    true
  }
  let group-of(start, y) = {
    let seen = (start,)
    let todo = (start,)
    while todo.len() > 0 {
      let u = todo.pop()
      for wi in wires {
        if calc.abs(delta(wi, y)) > 1e-6 { continue }
        let v = if wi.src == u { wi.dst } else if wi.dst == u { wi.src } else { none }
        if v != none and v not in seen {
          seen.push(v)
          todo.push(v)
        }
      }
    }
    seen
  }
  let cost = badness(y)
  for _ in range(6) {
    let improved = false
    for wi in wires.sorted(key: wi => -wi.w) {
      let d = delta(wi, y)
      if calc.abs(d) < 1e-6 or calc.abs(d) > cfg.snap { continue }
      let gs = group-of(wi.src, y)
      if wi.dst in gs { continue }
      for (grp, shift) in ((gs, -d), (group-of(wi.dst, y), d)) {
        let y2 = y
        for id in grp {
          y2.insert(id, y.at(id) + shift)
        }
        if not feasible(y2) { continue }
        let c2 = badness(y2)
        if c2 < cost - 1e-9 {
          y = y2
          cost = c2
          improved = true
          break
        }
      }
    }
    if not improved { break }
  }
  let pin-y = (:)
  for (id, n) in nodes {
    if n.type != "input" { pin-y.insert(id, pins-of(id, n, y)) }
  }

  // 4. channel routing. Between two columns each bending net gets a vertical
  //    track. The track order minimises crossings and forbids overlaps: if
  //    net A ends at the height where net B starts, A's track must be right
  //    of B's. Nets whose vertical extents are apart share a track.
  let gaps = ()
  for L in range(nlayers - 1) {
    let nets = (:)
    for id in layers.at(L + 1) {
      for (k, p) in nodes.at(id).pins.enumerate() {
        if p.src not in nets { nets.insert(p.src, (y: y.at(p.src), ts: ())) }
        nets.at(p.src).ts.push(pin-y.at(id).at(k))
      }
    }
    let bend = nets.keys().filter(s => nets.at(s).ts.any(t => calc.abs(t - nets.at(s).y) > 1e-6))
    let span = (:)
    for s in bend {
      let ys = (nets.at(s).y, ..nets.at(s).ts)
      span.insert(s, (calc.min(..ys), calc.max(..ys)))
    }
    // how bad is it to put a's track left of b's?
    let cost(a, b) = {
      let (A, B, sb, sa) = (nets.at(a), nets.at(b), span.at(b), span.at(a))
      let c = 0
      // a's pin wires run right from a's track and cross b's vertical
      for t in A.ts {
        if calc.abs(t - B.y) < 1e-3 { c += 1000 } // would overlap b's source wire
        else if t > sb.at(0) + cfg.track and t < sb.at(1) - cfg.track { c += 1 }
        else if t > sb.at(0) - cfg.track and t < sb.at(1) + cfg.track { c += 20 } // grazes an end: looks joined
      }
      // b's source wire runs left to b's track and crosses a's vertical
      if B.y > sa.at(0) + cfg.track and B.y < sa.at(1) - cfg.track { c += 1 }
      else if B.y > sa.at(0) - cfg.track and B.y < sa.at(1) + cfg.track { c += 20 }
      c
    }
    let apart(a, b) = span.at(a).at(1) + cfg.wire-sep <= span.at(b).at(0) or span.at(b).at(1) + cfg.wire-sep <= span.at(a).at(0)
    let pair-cost(a, b) = if apart(a, b) { 0 } else { cost(a, b) }
    // start: down-going nets (upper source further right), then up-going
    let goes-down(s) = mean(nets.at(s).ts) > nets.at(s).y
    let rest = bend.filter(goes-down).sorted(key: s => -nets.at(s).y) + bend.filter(s => not goes-down(s)).sorted(key: s => nets.at(s).y)
    // greedy: repeatedly take the net that is cheapest to put leftmost
    let order = ()
    while rest.len() > 0 {
      let scores = rest.map(a => rest.map(b => if a == b { 0 } else { pair-cost(a, b) }).sum())
      let k = scores.position(v => v == calc.min(..scores))
      order.push(rest.remove(k))
    }
    // then adjacent swaps while they help
    let improved = true
    while improved {
      improved = false
      for k in range(order.len() - 1) {
        let (a, b) = (order.at(k), order.at(k + 1))
        if pair-cost(b, a) < pair-cost(a, b) {
          order.at(k) = b
          order.at(k + 1) = a
          improved = true
        }
      }
    }
    // left-edge packing that keeps the order of every overlapping pair
    let track = (:)
    for (k, a) in order.enumerate() {
      let t = 0
      for b in order.slice(0, k) {
        if not apart(a, b) { t = calc.max(t, track.at(b) + 1) }
      }
      track.insert(a, t)
    }
    let ntracks = calc.max(0, ..track.values().map(t => t + 1))
    let w = calc.max(cfg.min-gap, (ntracks + 1) * cfg.track)
    gaps.push((nets: nets, track: track, ntracks: ntracks, width: w))
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
