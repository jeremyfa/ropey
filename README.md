# ropey (Haxe port)

A pure Haxe port of [ropey](https://github.com/cessen/ropey) **2.0.0-beta.1**, the UTF-8 text rope written in Rust by Nathan Vegdahl. It also contains the parts of [str_indices](https://github.com/cessen/str_indices) **0.4.4** (same author) that ropey uses, in `ropey.str_indices`.

A rope is a tree of text chunks: edits and queries run in `O(log N)` time, and cloning a rope is `O(1)` (clones share their tree until one of them is edited). It is the text buffer of the gpui-kit text inputs and editor in ceramic-gpui.

It has no dependency (no Ceramic, no other haxelib) and runs on every Haxe target. The text is stored as UTF-8 in `haxe.io.Bytes`, so the results are the same on targets with UTF-16 strings (JavaScript) and UTF-8 strings.

All credit for the design and the algorithms goes to ropey. This port translates the Rust source file by file: each Haxe module starts with a header naming the Rust file it comes from. The code is distributed under the same terms as ropey, MIT OR Apache-2.0 (see [LICENSE](LICENSE)).

## What is ported

Everything gpui-kit uses, which is the whole public API of ropey 2.0.0-beta.1 with the features `metric_chars`, `metric_utf16`, `metric_lines_lf` and `metric_lines_lf_cr` (the default one):

- `Rope`: `new`, `fromStr`, `clone`, `insert`, `insertChar`, `remove`, `slice`, the `try*` versions, and the debug helpers (`assertInvariants`...);
- `RopeSlice`, from a rope or from a string;
- the methods shared by both (`shared_impl.rs`, in `RopeBase`): lengths in bytes, chars, UTF-16 code units and lines, char boundaries, `byte`, `char`, `line`, `chunk`, every metric conversion (`byteToCharIdx`, `charToByteIdx`, `byteToUtf16Idx`, `utf16ToByteIdx`, `byteToLineIdx`, `lineToByteIdx`), `trailingLineBreakIdx`, `asStr`, the `get*` versions, equality, ordering, hashing and `toString`;
- the iterators `Bytes`, `Chars`, `CharIndices`, `Lines` and `Chunks`, with `next`, `prev`, `reversed` and the size hints, and the `ChunkCursor`;
- `RopeBuilder`;
- `extra::esoterica` (`Esoterica.ropesAreInstances`, `Esoterica.disconnectSlice`);
- `LineType.LF` and `LineType.LF_CR`.

Not ported:

- the `metric_lines_unicode` feature (`LineType::Unicode`), not enabled in gpui-kit;
- `Rope::from_reader` and `Rope::write_to` (`std::io`), the `FromIterator` and `Cow` conversions;
- the SIMD code paths of str_indices (the scalar code path gives the same results).

## Differences with the Rust API

- Names are converted to camelCase (`byte_to_char_idx` becomes `byteToCharIdx`).
- Indices are UTF-8 byte offsets, exactly like Rust. A Haxe `String` argument is encoded to UTF-8 first; `insertBytes` and `Rope.fromUtf8` take UTF-8 bytes directly.
- Ranges are `(start, end)` pairs: `slice(start, end)` and `remove(start, end)`, with `sliceFrom(start)` and `removeFrom(start)` for `start..`.
- A `char` is an `Int` code point. `Chars.next()` and `Bytes.next()` return `-1` at the end (Rust's `None`); `Chunks.next()` and `Lines.next()` return `null`.
- Tuples: `chunk()` returns a `Chunk` (`bytes`, `start`, `end`, `byteIdx`, `text()`); `chunksAt()` returns the iterator and stores the start byte index in `startByteIdx`; `CharIndices.next()` returns the char and stores its byte index in `index`.
- `reversed()` reverses the iterator in place (and returns it). `sizeHint()` is the lower bound of Rust's `size_hint()`, `sizeHintMax()` the upper bound when there is one. `clone()` copies an iterator.
- The iterators also work with Haxe `for` loops (`for (line in rope.lines(LF))`, `for (byteIdx => c in rope.charIndices())`), in their current direction.
- Methods that panic in Rust throw a `RopeyException` (with its `Error`). The `try*` methods return `null` on success or the `Error`; `trySlice` returns `null` on failure, with the cause in `trySliceError()`. `getChar` returns `null` on failure, `tryChar` tells why.
- `PartialEq` and `Ord` are `equals`, `equalsStr` and `compare` (negative, zero or positive). `Hash` is `hash()`, a 32 bit FNV-1a of the content (independent of the chunking, like upstream); pass a previous result as `state` to hash several values in a row.
- `attemptFullRebalance` returns the success flag and stores the iteration count in `lastRebalanceIterations` (Rust returns a tuple).
- The Rust tree shares nodes with `Arc` and copies them on write with `Arc::make_mut`. Here each node carries a reference count (`rc`) that clones increment, and edits copy shared nodes. Haxe has no destructors, so a clone that is dropped without being edited keeps its nodes marked as shared: the next edits of the other ropes copy the nodes on their path once, which costs time but never changes results.
- Like in Rust, a `RopeSlice`, an iterator or a `ChunkCursor` must not be used after the rope it comes from is modified (Rust enforces it with lifetimes). Clone the rope first to keep a snapshot.

## Usage

```haxe
import ropey.LineType;
import ropey.Rope;

class Main {

    static function main() {
        var rope = Rope.fromStr("Hello\nこんにちは\n");
        rope.insert(5, " world");
        trace(rope.len(), rope.lenChars(), rope.lenLines(LineType.LF)); // 28 18 3

        var line = rope.line(1, LineType.LF);
        trace(line.toString()); // こんにちは\n
        trace(rope.byteToUtf16Idx(rope.lineToByteIdx(1, LineType.LF))); // 12

        for (c in rope.chars()) {
            // c is a code point
        }
    }

}
```

## Tests

The `test` folder contains a runner that does not need Ceramic, with the ported tests of ropey (the `#[cfg(test)]` modules of every source file and `tests/proptest_tests.rs`) and of the str_indices modules:

- 307 unit tests;
- the 16 property tests, run on 512 generated inputs each like proptest, from a seeded random generator (the expected values come from small reference implementations in the test file, upstream uses str_indices and `String`).

Upstream runs its unit tests with small tree nodes (`cfg(test)`: 5 children, 15 bytes of text per leaf). `run.sh` runs the whole suite twice, with the normal sizes and with the small ones (`-D ropey_small_chunks`).

```sh
cd test
./run.sh                    # JavaScript builds, run with node
./run.sh SliceTests         # only the tests whose name contains "SliceTests"
haxe build-cpp.hxml && ./bin/cpp/Main
haxe -cp ../src -cp src -main Main --interp
```

`run.sh` uses `haxe` from the `PATH` (override with the `HAXE` environment variable). The hxcpp build needs hxcpp: a local repository can be set up in the test folder with `haxelib newrepo && haxelib dev hxcpp <path to hxcpp>`.

Tests not ported: the ones that need `metric_lines_unicode`. `try_remove_failure_01` reads `fuzz/fuzz_targets/small.txt`, which is not shipped in the crate: it uses `benches/small.txt` with a 3 byte char inserted so that the removal still fails on a char boundary.

## License

MIT OR Apache-2.0, like upstream ropey and str_indices. See [LICENSE](LICENSE): Copyright (c) 2023 Nathan Vegdahl.
