#import "/src/exports.typ" as circuitz: logic, gate, gate-symbol, cetz, GATES

#let VERSION = toml("/typst.toml").package.version

#set page(numbering: "1", margin: 2cm)
#set par(justify: true)
#set heading(numbering: "1.")
#show link: underline.with(stroke: 1pt + blue.lighten(70%))
#show raw.where(block: true): set text(8pt)
#show raw.where(block: true): block.with(fill: luma(97%), inset: 8pt, radius: 3pt, width: 100%)

// Show the source of an example next to its output.
#let scope = (logic: logic, gate: gate, gate-symbol: gate-symbol, cetz: cetz, GATES: GATES)
#let example(src, dir: ltr) = {
  let out = eval(src.text, mode: "markup", scope: scope)
  if dir == ltr {
    grid(columns: (1fr, auto), column-gutter: 1em, align: horizon, src, out)
  } else {
    stack(spacing: 0.8em, src, align(center, out))
  }
}

#align(center)[
  #v(2cm)
  #text(2.6em, `circuitz`) \
  #v(0.5em)
  _Gate-level logic circuit diagrams for Typst_ \
  #v(1em)
  #logic(```
  in a b cin
  p    = xor(a, b)
  s    = xor(p, cin)
  cout = or(and(a, b), and(p, cin))
  ```)
  #v(1em)
  *Version #VERSION*
  #v(1fr)
  #outline(indent: 1.5em)
  #v(1fr)
]

#pagebreak()

= Introduction

`circuitz` draws digital logic circuits with the _distinctive-shape_ gate
symbols of IEEE Std 91/91a-1991, on top of
#link("https://cetz-package.github.io")[CeTZ]. It has two layers:

- *`logic()`*: write a netlist in a tiny language (think Mermaid or D2 for
  gates) and the gates, wires, junction dots and labels are laid out for you.
- *`gate()`*: a single gate as a CeTZ element with named pin anchors, for
  placing gates by hand.

```typ
#import "@preview/circuitz:0.1.0": logic, gate, gate-symbol
```

= The netlist language

#example(````typ
#logic(```
y = or(a, and(b, c))
```)
````)

Each line assigns a gate to a name. Gates nest like function calls, and any
name that is never assigned is a primary input.

#table(
  columns: (auto, 1fr),
  stroke: (x: none),
  inset: 6pt,
  table.header[*Syntax*][*Meaning*],
  `y = and(a, b)`, [Gate `y` with inputs `a` and `b`. Any number of inputs (except `not`, `buf`).],
  `y = or(a, and(b, c))`, [Nested gates are anonymous; they get names `_g1`, `_g2`, ...],
  `and(!a, b)`, [`!a` (or `~a`) puts an inversion bubble on that input instead of a NOT gate.],
  `in a b c`, [Optional. Fixes the order (top to bottom) of the inputs. Otherwise: order of first use.],
  `out y z`, [Optional. Which signals get an output label. Default: named gates that nothing else uses.],
  `// ...`, [Comment until the end of the line.],
)

Gates: #GATES.keys().map(k => [#raw(k) #gate-symbol(k)]).join(", ").

Identical sub-expressions (up to argument order) are shared, so writing
`and(a, b)` twice gives one gate that fans out. Name an intermediate signal
to reuse it explicitly:

#example(````typ
#logic(```
in a b
m = nand(a, b)
y = nand(nand(a, m), nand(b, m))
```)
````)

Bubbles versus explicit inverters:

#grid(columns: 2, column-gutter: 1em,
  example(dir: ttb, ````typ
  #logic(```
  in a b c
  z = or(and(a, b), and(not(b), c),
         and(b, not(c)))
  ```)
  ````),
  example(dir: ttb, ````typ
  #logic(```
  in a b c
  z = or(and(a, b), and(!b, c),
         and(b, !c))
  ```)
  ````),
)

Several outputs in one circuit share their inputs:

#example(dir: ttb, ````typ
#logic(```
in a1 a0
out d0 d1 d2 d3
d0 = and(!a1, !a0)
d1 = and(!a1, a0)
d2 = and(a1, !a0)
d3 = and(a1, a0)
```)
````)

Signal names of the form `a`, `b'` or `x1` are typeset as math ($a$, $b'$,
$x_1$); longer names stay plain text. Turn this off with `math-labels: false`.

== Errors

Mistakes are reported with a `circuitz:` message: unknown gates, unbalanced
parentheses, names defined twice, `not` with two inputs, unknown outputs and
feedback loops. Circuits with feedback (latches, flip-flops) cannot be laid
out automatically; draw them by hand with `gate()` (@manual).

= Options of `logic()`

#table(
  columns: (auto, auto, 1fr),
  stroke: (x: none),
  inset: 5pt,
  table.header[*Option*][*Default*][*Meaning*],
  `unit`, `0.55cm`, [Height of a 2-input gate. All other distances are in this unit.],
  `gate-stroke`, `0.8pt`, [Outline of the gate bodies.],
  `wire-stroke`, `0.6pt`, [Wires and pin stubs.],
  `fill`, `white`, [Fill of the gate bodies and bubbles.],
  `label-size`, `10pt`, [Size of input and output labels.],
  `math-labels`, `true`, [Typeset short signal names as math.],
  `show-names`, `false`, [Print gate names above the gates (handy for `extra`).],
  `layering`, `"alap"`, [`"alap"`: gates as close to their consumers as possible, so gates of the same kind line up in columns. `"asap"`: as close to the inputs as possible.],
  `sweeps`, `4`, [Placement refinement passes. `0` keeps the inputs evenly stacked.],
  `snap`, `0.4`, [How far a gate may move to make an almost-straight wire straight.],
  `input-sep`, `1.0`, [Minimum vertical distance between inputs.],
  `gate-sep`, `0.6`, [Minimum free space between stacked gates.],
  `wire-sep`, `0.45`, [Minimum spacing of wires passing through a column.],
  `track`, `0.28`, [Spacing of the vertical wire segments between columns.],
  `min-gap`, `0.9`, [Minimum horizontal gap between columns.],
  `dot`, `0.065`, [Radius of the junction dots.],
  `extra`, `none`, [CeTZ elements drawn on top (see below).],
)

== Styling and annotations

Gates are CeTZ groups named after their signal, and inputs are groups named
after the input, so `extra` can refer to anchors like `"c.out"` or `"a.out"`.

#example(````typ
#logic(
  gate-stroke: 1pt + blue.darken(30%),
  fill: blue.lighten(90%),
  extra: {
    import cetz.draw: *
    content("c.out", text(red, 8pt)[carry],
      anchor: "south-west", padding: 0.1)
  },
  ```
  s = xor(a, b)
  c = and(a, b)
  ```,
)
````)

= Gates by hand <manual>

`gate(kind, pos, ..)` draws a gate inside any CeTZ canvas. `pos` is the left
end of the input pins at the vertical centre. With `name: "g"` the anchors
`"g.in1"`, ..., `"g.inN"` (top to bottom) and `"g.out"` are available.

#table(
  columns: (auto, auto, 1fr),
  stroke: (x: none),
  inset: 5pt,
  table.header[*Argument*][*Default*][*Meaning*],
  `kind`, [], [One of #GATES.keys().map(raw).join(", ").],
  `pos`, [], [CeTZ coordinate of the input side.],
  `inputs`, `auto`, [Number of inputs (`auto`: 1 for `not`/`buf`, else 2). Beyond 4, IEEE-style extension lines are drawn.],
  `inverted`, `()`, [1-based indices of inputs that get a bubble.],
  `name`, `none`, [Group name for anchors.],
  `stroke`, `0.8pt`, [Body outline.],
  `wire`, `0.6pt`, [Pin stubs.],
  `fill`, `white`, [Body fill.],
)

#example(dir: ttb, ````typ
#cetz.canvas(length: 0.7cm, {
  import cetz.draw: *
  set-style(stroke: 0.6pt)
  gate("nor", (0, 1), name: "top")
  gate("nor", (0, -1), name: "bot")
  let dot(p) = circle(p, radius: 0.065, fill: black, stroke: none)
  line("top.out", (3.3, 1))
  line((2.4, 1), (2.4, 0.2), (-0.4, 0.2), ((), "|-", "bot.in1"), "bot.in1")
  line("bot.out", (3.3, -1))
  line((2.7, -1), (2.7, -0.2), (-0.7, -0.2), ((), "|-", "top.in2"), "top.in2")
  dot((2.4, 1)); dot((2.7, -1))
  line("top.in1", (rel: (-1, 0)), name: "r")
  line("bot.in2", (rel: (-1, 0)), name: "s")
  content("r.end", $R$, anchor: "east", padding: 0.1)
  content("s.end", $S$, anchor: "east", padding: 0.1)
  content((3.3, 1), $Q$, anchor: "west", padding: 0.1)
  content((3.3, -1), $overline(Q)$, anchor: "west", padding: 0.1)
})
````)

`gate-symbol(kind, size: 0.45cm, ..)` wraps a single gate as inline content,
e.g. a #gate-symbol("nand") in running text, or in tables:

#example(````typ
#table(columns: 4, align: center + horizon,
  ..("and", "or", "xor", "not").map(gate-symbol),
  [$a b$], [$a + b$], [$a xor b$], [$overline(a)$],
)
````)

#table(
  columns: 8,
  align: center + horizon,
  stroke: none,
  ..GATES.keys().map(k => [#gate-symbol(k, size: 0.7cm) \ #raw(k)]),
  gate-symbol("and", inputs: 3, size: 0.7cm),
  gate-symbol("or", inputs: 4, size: 0.7cm),
  gate-symbol("nand", inputs: 6, size: 0.7cm),
  gate-symbol("xor", inputs: 5, size: 0.7cm),
  gate-symbol("or", inverted: (1, 2), size: 0.7cm),
  gate-symbol("and", inverted: (2,), size: 0.7cm),
  [], [],
)

= How the layout works

The automatic layout is a layered ("Sugiyama-style") graph drawing:

+ *Layering.* Inputs go in column 0. With `"alap"`, every gate is placed in the
  column just before its first consumer; outputs share the last column.
+ *Dummies.* A wire that skips columns gets a pass-through node in each
  column it crosses, so gates are never placed on top of it.
+ *Placement.* Each column is solved as an order-preserving least-squares
  problem (every node wants to sit at the mean height of its drivers and
  consumers, subject to minimum spacing), with alternating forward and
  backward sweeps. A final pass snaps nodes so that almost-straight wires
  become straight.
+ *Routing.* Wires are orthogonal. Each bending net gets its own vertical
  track between two columns, ordered to avoid crossings where possible.
  Junction dots mark every point where three or more wire segments meet.

The result is deterministic but heuristic: reordering the `in` line is the
quickest way to untangle a circuit.
