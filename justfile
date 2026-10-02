# logicz development tasks. `just --list` to see them.

version := `grep '^version' typst.toml | cut -d '"' -f2`
local := if os() == "macos" { env("HOME") / "Library/Application Support/typst/packages/local" } else { env("XDG_DATA_HOME", env("HOME") / ".local/share") / "typst/packages/local" }

# run all tests
test: test-pass test-fail

# every tests/*.typ must compile; renders PNGs to tests/out/ for eyeballing
test-pass:
    #!/usr/bin/env bash
    set -e
    mkdir -p tests/out
    for f in tests/*.typ; do
      n=$(basename "$f" .typ)
      typst compile --root . "$f" "tests/out/$n-{0p}.png" --ppi 144
      echo "ok   $n"
    done

# every tests/fail/*.typ must fail with the message in its `// expect:` line
test-fail:
    #!/usr/bin/env bash
    fails=0
    for f in tests/fail/*.typ; do
      n=$(basename "$f" .typ)
      want=$(head -1 "$f" | sed 's|^// expect: ||')
      if out=$(typst compile --root . "$f" /tmp/logicz-fail.pdf 2>&1); then
        echo "FAIL $n: compiled but should not"; fails=1
      elif grep -qF "$want" <<< "$out"; then
        echo "ok   fail/$n"
      else
        echo "FAIL $n: expected '$want', got:"; echo "$out" | head -3; fails=1
      fi
    done
    exit $fails

# pack the files that ship (see `exclude` in typst.toml) into dist/
package:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="dist/logicz-{{version}}"
    rm -rf dist && mkdir -p "$dir"
    cp -R typst.toml README.md LICENSE CHANGELOG.md src "$dir/"
    tar -czf "dist/logicz-{{version}}.tar.gz" -C dist "logicz-{{version}}"
    echo "packed dist/logicz-{{version}}.tar.gz"

# build the manual
docs:
    typst compile --root . docs/manual.typ docs/manual.pdf

# live-preview
docs-watch:
    tinymist preview --root . --open docs/manual.typ

# render the README images
images:
    for f in docs/examples/*.typ; do typst compile --root . "$f" "${f%.typ}.svg"; done

# symlink this checkout as @local/logicz:{{version}}
install:
    mkdir -p "{{ local }}/logicz"
    ln -sfn "{{ justfile_directory() }}" "{{ local }}/logicz/{{ version }}"
    @echo 'installed: #import "@local/logicz:{{ version }}": *'

# remove the @local symlink
uninstall:
    rm -f "{{ local }}/logicz/{{ version }}"
