# circuitz development tasks. `just --list` to see them.

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
      if out=$(typst compile --root . "$f" /tmp/circuitz-fail.pdf 2>&1); then
        echo "FAIL $n: compiled but should not"; fails=1
      elif grep -qF "$want" <<< "$out"; then
        echo "ok   fail/$n"
      else
        echo "FAIL $n: expected '$want', got:"; echo "$out" | head -3; fails=1
      fi
    done
    exit $fails

# build the manual
docs:
    typst compile --root . docs/manual.typ docs/manual.pdf

# render the README images
images:
    for f in docs/examples/*.typ; do typst compile --root . "$f" "${f%.typ}.png" --ppi 200; done

# symlink this checkout as @local/circuitz:{{version}}
install:
    mkdir -p "{{local}}/circuitz"
    ln -sfn "{{justfile_directory()}}" "{{local}}/circuitz/{{version}}"
    @echo 'installed: #import "@local/circuitz:{{version}}": *'

# remove the @local symlink
uninstall:
    rm -f "{{local}}/circuitz/{{version}}"
