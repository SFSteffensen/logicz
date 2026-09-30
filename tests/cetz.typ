// Placing gates by hand in a CeTZ canvas (an SR latch has feedback, which
// the netlist language rejects).
#import "/src/exports.typ": *
#set page(width: auto, height: auto, margin: 1em)

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
  dot((2.4, 1))
  dot((2.7, -1))
  line("top.in1", (rel: (-1, 0)), name: "r")
  line("bot.in2", (rel: (-1, 0)), name: "s")
  content("r.end", $R$, anchor: "east", padding: 0.1)
  content("s.end", $S$, anchor: "east", padding: 0.1)
  content((3.3, 1), $Q$, anchor: "west", padding: 0.1)
  content((3.3, -1), $overline(Q)$, anchor: "west", padding: 0.1)
})
