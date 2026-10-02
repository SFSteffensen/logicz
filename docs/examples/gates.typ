#import "/src/exports.typ": gate-symbol, GATES
#set page(width: auto, height: auto, margin: 0.4cm, fill: white)
// GitHub shows SVGs at their natural size; double it to read well in the README
#show: scale.with(200%, reflow: true)
#table(
  columns: 8,
  align: center + horizon,
  stroke: none,
  ..GATES.keys().map(k => [#gate-symbol(k, size: 0.8cm) \ #raw(k)]),
)
