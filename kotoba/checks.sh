#!/usr/bin/env bash
# Compile zopfli.kotoba with kotoba 0.7.2 and run the stored-zlib fixture.
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

if ! command -v kotoba >/dev/null 2>&1; then
  echo "kotoba CLI is required (kotoba-lang/kotoba v0.7.2)" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to parse kotoba --json and check wasm/fixtures" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

plain=$(cat kotoba/fixtures/hello.plain)
if [ "$plain" != "hello" ] || [ "${#plain}" -ne 5 ]; then
  echo "fixture plaintext must be exactly 5 bytes: hello" >&2
  exit 1
fi

python3 - "$root" <<'PY'
import pathlib, sys, zlib
root = pathlib.Path(sys.argv[1])
plain = (root / "kotoba/fixtures/hello.plain").read_bytes()
hexs = (root / "kotoba/fixtures/hello.zlib.hex").read_text().strip()
expected = bytes.fromhex(hexs)
if plain != b"hello":
    raise SystemExit("hello.plain is not ASCII hello")
if expected != bytes.fromhex("78da010500faff68656c6c6f062c0215"):
    raise SystemExit("hello.zlib.hex does not match the stored-zlib vector")
if zlib.decompress(expected) != plain:
    raise SystemExit("expected zlib bytes do not inflate to hello")
print("fixture independent inflate ok", expected.hex())
PY

compile_json=$(kotoba compile kotoba/zopfli.kotoba --target wasm --output "$work/zopfli.wasm" --json)
echo "$compile_json" | python3 - "$work/zopfli.wasm" <<'PY'
import json, sys
wasm_path = sys.argv[1]
d = json.load(sys.stdin)
ok = d.get("kotoba.cli/ok?")
code = d.get("kotoba.cli/code")
data = d.get("kotoba.cli/data") or {}
profile = data.get("value-profile")
compat = data.get("compatibility") or {}
print("wasm", ok, code, "profile", profile, "abi", compat.get("value-abi"), "target", compat.get("target"))
if not ok or code != "emitted":
    raise SystemExit(d.get("kotoba.cli/message") or "wasm compile failed")
if profile != "i64-v1":
    raise SystemExit("expected value-profile i64-v1, got %r" % (profile,))
if compat.get("value-abi") != "direct-v1":
    raise SystemExit("expected value-abi direct-v1")
if compat.get("target") != "wasm32-kotoba-v1":
    raise SystemExit("expected target wasm32-kotoba-v1")
blob = open(wasm_path, "rb").read()
if blob[:4] != b"\x00asm":
    raise SystemExit("not wasm magic")

def read_u32(buf, i):
    n = 0
    shift = 0
    while True:
        b = buf[i]
        i += 1
        n |= (b & 0x7F) << shift
        if b < 0x80:
            return n, i
        shift += 7

i = 8
imports = False
while i < len(blob):
    sid = blob[i]
    i += 1
    size, i = read_u32(blob, i)
    if sid == 2:
        imports = True
    i += size
if imports:
    raise SystemExit("wasm has an import section; host-independent i64-v1 must not")
print("wasm host-independent", len(blob), "bytes")
PY

run_json=$(kotoba compile kotoba/zopfli.kotoba --target web --output "$work/zopfli.mjs" --run --json)
echo "$run_json" | python3 - <<'PY'
import json, sys
d = json.load(sys.stdin)
ok = d.get("kotoba.cli/ok?")
code = d.get("kotoba.cli/code")
data = d.get("kotoba.cli/data") or {}
result = data.get("result")
profile = data.get("value-profile")
print("web", ok, code, "result", result, "profile", profile)
if not ok or code != "ran":
    raise SystemExit(d.get("kotoba.cli/message") or "web fixture run failed")
if profile != "i64-v1":
    raise SystemExit("expected value-profile i64-v1 on web run")
if result != 1:
    raise SystemExit("fixture-ok returned %r, expected 1" % (result,))
print("fixture encode match ok")
PY
