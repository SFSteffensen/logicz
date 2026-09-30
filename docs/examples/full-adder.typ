#import "/src/exports.typ": logic
#set page(width: auto, height: auto, margin: 0.4cm, fill: white)
#logic(```
in a b cin
p    = xor(a, b)
s    = xor(p, cin)
cout = or(and(a, b), and(p, cin))
```)
