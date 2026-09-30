#import "/src/exports.typ": gate-symbol, GATES
#set page(width: auto, height: auto, margin: 0.4cm, fill: white)
#table(
  columns: 8,
  align: center + horizon,
  stroke: none,
  ..GATES.keys().map(k => [#gate-symbol(k, size: 0.8cm) \ #raw(k)]),
)
