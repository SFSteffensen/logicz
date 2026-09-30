// All gate symbols, many-input extensions and input bubbles.
#import "/src/exports.typ": *
#set page(width: auto, height: auto, margin: 1em)

#table(
  columns: 8,
  align: center + horizon,
  stroke: none,
  ..GATES.keys().map(k => [#gate-symbol(k, size: 0.8cm) \ #raw(k)]),
)

#table(
  columns: 6,
  align: center + horizon,
  stroke: none,
  gate-symbol("and", inputs: 3, size: 0.8cm),
  gate-symbol("or", inputs: 4, size: 0.8cm),
  gate-symbol("nand", inputs: 6, size: 0.8cm),
  gate-symbol("xor", inputs: 5, size: 0.8cm),
  gate-symbol("or", inverted: (1, 2), size: 0.8cm),
  gate-symbol("and", inverted: (2,), size: 0.8cm),
)

Inline: a #gate-symbol("nand") is universal, and so is a #gate-symbol("nor").
