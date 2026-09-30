// The netlist language on typical textbook circuits.
#import "/src/exports.typ": *
#set page(width: 16cm, height: auto, margin: 1em)
#set text(size: 10pt)

== $y = a + b c$
#logic(```
y = or(a, and(b, c))
```)

== $z = a b + b' c + b c'$ (NOT gates)
#logic(```
in a b c
z = or(and(a, b), and(not(b), c), and(b, not(c)))
```)

== Same, with input bubbles
#logic(```
z = or(and(a, b), and(!b, c), and(b, !c))
```)

== Two outputs, shared inputs
#logic(```
in a b c
y = or(a, and(b, c))
z = or(and(a, b), and(not(b), c), and(b, not(c)))
```)

== Half adder, full adder
#grid(columns: 2, column-gutter: 2cm,
  logic(```
  s = xor(a, b)
  c = and(a, b)
  ```),
  logic(```
  in a b cin
  p    = xor(a, b)
  s    = xor(p, cin)
  cout = or(and(a, b), and(p, cin))
  ```),
)

== 2:1 multiplexer
#logic(```
in d0 d1 s
y = or(and(d0, not(s)), and(d1, s))
```)

== XOR from NANDs (`show-names`)
#logic(show-names: true, ```
in a b
m = nand(a, b)
y = nand(nand(a, m), nand(b, m))
```)

== 2-to-4 decoder
#logic(```
in a1 a0
out d0 d1 d2 d3
d0 = and(!a1, !a0)
d1 = and(!a1, a0)
d2 = and(a1, !a0)
d3 = and(a1, a0)
```)

== Many-input gate, output that is also used internally
#logic(```
p = and(a, b, c, d, e)
q = or(p, f)
out p q
```)
