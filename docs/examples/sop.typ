#import "/src/exports.typ": logic
#set page(width: auto, height: auto, margin: 0.4cm, fill: white)
// GitHub shows SVGs at their natural size; double it to read well in the README
#show: scale.with(200%, reflow: true)
#logic(```
in a b c
y = or(a, and(b, c))
z = or(and(a, b), and(not(b), c), and(b, not(c)))
```)
