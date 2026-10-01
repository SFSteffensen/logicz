# Changelog

## 0.1.1

### Changed

- Much cleaner automatic layout in `logic()`:
  - Gates are placed so that most wires are perfectly straight, which
    removes the small jogs before gate inputs.
  - Groups of gates and inputs joined by straight wires move together to
    straighten more wires, without breaking spacing or input order.
  - Wires never run on top of each other, and the order of the vertical
    wire segments between columns is chosen to minimise crossings.
  - Wires that bend over separate stretches share a vertical segment, so
    they turn at the same point.
- `snap` is now the maximum distance a group of gates may move to straighten
  a wire. Its default changed from `0.4` to `2`.

### Development

- Tests for layout quality: no overlapping wires and no tiny jogs.
- CI runs the tests, builds the manual and builds the package with Typst
  0.14.0 and the latest release.
- A release workflow builds `manual.pdf` and the source archive, and creates
  the GitHub release from this changelog.
- `just package` packs the files that ship into `dist/`.

## 0.1.0

Initial release.

- IEEE 91 distinctive-shape gates: and, or, nand, nor, xor, xnor, not, buf.
- `logic()`: netlist language with nesting, inversion bubbles, shared
  sub-expressions, and an automatic layered layout.
- `gate()` and `gate-symbol()` for manual CeTZ drawings and inline symbols.
- Built on CeTZ 0.5.2 (requires Typst 0.14 or newer).
