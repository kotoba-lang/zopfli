# Kotoba v1 for Zopfli

First-class sibling tree to `src/` (C) and `go/`. This directory is a Kotoba
encode surface for the fork, not a language binding over `libzopfli`.

Public operator: awai.network. Sales: Ryo Awai.

License: Apache-2.0 (same as this repository).

## Honest scope

v1 encodes **one stored zlib block** of a 5-byte fixture (`hello`).

- RFC 1950 zlib wrapper (CMF/FLG + Adler-32) around RFC 1951 deflate.
- Deflate payload is **stored** (`BFINAL=1`, `BTYPE=00`) plus `LEN`/`NLEN`.
- CMF/FLG matches `src/zopfli/zlib_container.c`: CM=8, CINFO=7, FLEVEL=3
  (`0x78 0xDA`).
- Adler-32 of the plaintext is computed in-language (mod 65521).
- The fixture bytes are independently inflatable by any zlib decoder.

This is **not**:

- a drop-in replacement for the C library or the Go cgo wrapper
- Zopfli's LZ77 / Huffman / block-splitter / squeeze path
- gzip, PNG, or `zopflipng`
- 50Hz, real-time, or robotics-ready
- an FFI or C/C++ driver

A full Zopfli compressor will not fit on wasm32 i64-v1. That dialect has no
IEEE floats, no admitted byte-builder, and no host imports in the
host-independent profile. Shrinking to stored zlib of a short fixture is the
smallest encode that still proves real bytes. The shrink is documented here,
not stubbed.

## Module

`zopfli.kotoba` is one compilation unit (`zopfli.v1`).

| export | meaning |
|---|---|
| `zlib-byte` | byte `i` of the computed stored-zlib stream |
| `zlib-len` | stream length (16 for this fixture) |
| `adler32-fixture` | Adler-32 of `hello` (`0x062c0215`) |
| `fixture-ok` / `main` | `1` if every computed byte matches the fixture |

Plaintext and expected stream:

```
hello
78 da 01 05 00 fa ff 68 65 6c 6c 6f 06 2c 02 15
```

Also vendored as `fixtures/hello.plain` and `fixtures/hello.zlib.hex`.

## Build (kotoba CLI v0.7.2)

Language authority: [kotoba-lang/kotoba-lang](https://github.com/kotoba-lang/kotoba-lang).
CLI: [kotoba-lang/kotoba](https://github.com/kotoba-lang/kotoba) tag **v0.7.2**.

```sh
kotoba compile kotoba/zopfli.kotoba --target wasm --output zopfli.wasm --json
```

Accept `kotoba.cli/ok?` true, `kotoba.cli/code` `emitted`,
`value-profile` `i64-v1`. The artifact is host-independent wasm32
(`wasm32-kotoba-v1`, `value-abi` `direct-v1`): no `kotoba:typed` imports, no
libzopfli.

`kotoba compile --target wasm --run` is not used. The i64-v1 guest does not
match the kototama/chicory runner on v0.7.2. Fixture execution is
`--target web --run` (`js-kotoba-v1`), which still reports `value-profile`
`i64-v1`.

```sh
kotoba/checks.sh
```

Install the CLI from the v0.7.2 release tarball or
`brew tap kotoba-lang/kotoba && brew trust kotoba-lang/kotoba && brew install kotoba`.
