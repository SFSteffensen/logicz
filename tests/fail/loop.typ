// expect: combinational loop
#import "/src/exports.typ": logic
#logic("q = nor(r, p)\np = nor(s, q)")
