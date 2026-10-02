#import "/src/exports.typ": logic
#set page(width: auto, height: auto, margin: 0.4cm, fill: white)
// GitHub shows SVGs at their natural size; double it to read well in the README
#show: scale.with(200%, reflow: true)
#logic(```
in a b cin
p    = xor(a, b)
s    = xor(p, cin)
cout = or(and(a, b), and(p, cin))
```)
