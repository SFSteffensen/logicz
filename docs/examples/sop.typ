#import "/src/exports.typ": logic
#set page(width: auto, height: auto, margin: 0.4cm, fill: white)
#logic(```
in a b c
y = or(a, and(b, c))
z = or(and(a, b), and(not(b), c), and(b, not(c)))
```)
