// Parser behaviour, checked with assertions (no drawing).
#import "/src/exports.typ": parse

#let n = parse("y = or(a, and(b, c))")
#assert.eq(n.inputs, ("a", "b", "c"))
#assert.eq(n.outputs, ("y",))
#assert.eq(n.gates.len(), 2)

// declared input order wins, undeclared inputs are appended
#assert.eq(parse("in c a\ny = and(a, b, c)").inputs, ("c", "a", "b"))

// identical sub-expressions (up to argument order) share one gate
#let n = parse("y = or(and(a, b), and(b, a))\nz = xor(and(a, b), c)")
#assert.eq(n.gates.len(), 3)

// bubbles, double negation, comments
#let n = parse("y = and(!a, ~~b) // comment")
#assert.eq(n.gates.y.ins, ((src: "a", inv: true), (src: "b", inv: false)))

// explicit outputs
#assert.eq(parse("out p\np = and(a, b)\nq = or(p, c)").outputs, ("p",))


// statements may span lines while parentheses are open
#let n = parse("y = or(\n  and(a, b), // first\n  and(c, d),\n)")
#assert.eq(n.gates.len(), 3)

ok
