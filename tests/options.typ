// Styling options, `extra`, asap layering, string source.
#import "/src/exports.typ": *
#set page(width: auto, height: auto, margin: 1em)

#logic(
  unit: 0.7cm,
  gate-stroke: 1pt + blue.darken(30%),
  fill: blue.lighten(90%),
  extra: {
    import cetz.draw: *
    content("c.out", text(red, 8pt)[carry], anchor: "south-west", padding: 0.1)
  },
  ```
  s = xor(a, b)
  c = and(a, b)
  ```,
)

#logic(layering: "asap", sweeps: 0, math-labels: false, "y = or(and(d1, s), and(d0, not(s)))")
