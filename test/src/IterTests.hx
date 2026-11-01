// Ported from ropey 2.0.0-beta.1: src/iter.rs (tests)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

import TestUtil.*;
import ropey.LineType;
import ropey.Rope;
import ropey.RopeBuilder;
import ropey.RopeSlice;

using IterCount;

class IterTests {

    public function new() {}

    function linesText():String {
        var text = new StringBuf();
        text.add("\r\n");
        for (_ in 0...16) {
            text.add("Hello there!  How're you doing?  It's a fine day, "
                + "isn't it?  Aren't you glad we're alive?\r\n"
                + "こんにちは！元気ですか？日はいいですね。"
                + "私たちが生きだって嬉しいではないか？\r\n");
        }
        return text.toString();
    }

    function helloWorldRepeatRope():Rope {
        var rb = new RopeBuilder();
        for (_ in 0...4) {
            rb._appendChunkAsLeaf("Hello ");
            rb._appendChunkAsLeaf("world!");
        }
        return rb.finish();
    }

    public function test_chunks_iter_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var text = TEXT;
            var chunks = t.chunks();
            var stack = [];

            // Forward.
            var chunk;
            while ((chunk = chunks.next()) != null) {
                eq(bto(text, blen(chunk)), chunk);
                stack.push(chunk);
                text = bfrom(text, blen(chunk));
            }
            eq("", text);

            // Backward.
            while ((chunk = chunks.prev()) != null) {
                eq(stack.pop(), chunk);
            }
            eq(0, stack.length);
        }
    }

    public function test_chunks_iter_02() {
        var r = helloWorldRepeatRope();

        var chunks = r.chunks();

        eq(("Hello "), chunks.next());
        eq(("world!"), chunks.next());
        eq(("Hello "), chunks.next());
        eq(("world!"), chunks.next());
        eq(("Hello "), chunks.next());
        eq(("world!"), chunks.next());
        eq(("Hello "), chunks.next());
        eq(("world!"), chunks.next());
        eq(null, chunks.next());

        eq(("world!"), chunks.prev());
        eq(("Hello "), chunks.prev());
        eq(("world!"), chunks.prev());
        eq(("Hello "), chunks.prev());
        eq(("world!"), chunks.prev());
        eq(("Hello "), chunks.prev());
        eq(("world!"), chunks.prev());
        eq(("Hello "), chunks.prev());
        eq(null, chunks.prev());
    }

    public function test_chunks_iter_03() {
        var r = Rope.fromStr("");

        for (t in makeTestData(r, "")) {
            var chunks = t.chunks();
            eq(null, chunks.next());
            eq(null, chunks.prev());
        }
    }

    public function test_chunks_iter_04() {
        var r = helloWorldRepeatRope();
        var s = r.slice(3, 45);

        var chunks = s.chunks();

        eq(("lo "), chunks.next());
        eq(("world!"), chunks.next());
        eq(("Hello "), chunks.next());
        eq(("world!"), chunks.next());
        eq(("Hello "), chunks.next());
        eq(("world!"), chunks.next());
        eq(("Hello "), chunks.next());
        eq(("wor"), chunks.next());
        eq(null, chunks.next());

        eq(("wor"), chunks.prev());
        eq(("Hello "), chunks.prev());
        eq(("world!"), chunks.prev());
        eq(("Hello "), chunks.prev());
        eq(("world!"), chunks.prev());
        eq(("Hello "), chunks.prev());
        eq(("world!"), chunks.prev());
        eq(("lo "), chunks.prev());
        eq(null, chunks.prev());
    }

    public function test_chunks_iter_05() {
        var r = helloWorldRepeatRope();
        var s = r.slice(8, 40);

        var chunks = s.chunks();

        eq(("rld!"), chunks.next());
        eq(("Hello "), chunks.next());
        eq(("world!"), chunks.next());
        eq(("Hello "), chunks.next());
        eq(("world!"), chunks.next());
        eq(("Hell"), chunks.next());
        eq(null, chunks.next());

        eq(("Hell"), chunks.prev());
        eq(("world!"), chunks.prev());
        eq(("Hello "), chunks.prev());
        eq(("world!"), chunks.prev());
        eq(("Hello "), chunks.prev());
        eq(("rld!"), chunks.prev());
        eq(null, chunks.prev());
    }

    public function test_chunks_iter_06() {
        var r = helloWorldRepeatRope();
        var s = r.slice(14, 14);

        var chunks = s.chunks();
        eq(null, chunks.next());
        eq(null, chunks.prev());
    }

    public function test_chunks_iter_07() {
        var r = Rope.fromStr("A");
        for (t in makeTestData(r, "A")) {
            var chunks = t.chunks();

            eq(("A"), chunks.next());
            eq(null, chunks.next());
            eq(("A"), chunks.prev());
            eq(null, chunks.prev());

            eq(("A"), chunks.next());
            eq(("A"), chunks.prev());
            eq(("A"), chunks.next());
        }
    }

    public function test_chunks_iter_08() {
        var r =
            makeRopeFromChunks(["ABC", "DEF", "GHI", "JKL", "MNO", "PQR", "STU", "VWX", "YZ"]);
        var chunks = r.chunks();

        eq(("ABC"), chunks.next());
        eq(("ABC"), chunks.prev());
        eq(null, chunks.prev());

        eq(("ABC"), chunks.next());
        eq(("DEF"), chunks.next());
        eq(("DEF"), chunks.prev());

        eq(("DEF"), chunks.next());
        eq(("GHI"), chunks.next());
        eq(("JKL"), chunks.next());
        eq(("JKL"), chunks.prev());

        eq(("JKL"), chunks.next());
        eq(("MNO"), chunks.next());
        eq(("PQR"), chunks.next());
        eq(("STU"), chunks.next());
        eq(("VWX"), chunks.next());
        eq(("VWX"), chunks.prev());

        eq(("VWX"), chunks.next());
        eq(("YZ"), chunks.next());
        eq(null, chunks.next());
        eq(("YZ"), chunks.prev());

        eq(("YZ"), chunks.next());
        eq(null, chunks.next());
    }

    public function test_chunks_at_01() {
        var r = Rope.fromStr(TEXT);

        for (t in makeTestData(r, TEXT)) {
            for (i in 0...blen(TEXT)) {
                var currentByte = t.chunk(i).byteIdx;
                var chunks = t.chunksAt(i);
                var idx = chunks.startByteIdx;
                eq(currentByte, idx);

                var chunk1;
                while ((chunk1 = chunks.next()) != null) {
                    var chunk2 = t.chunk(currentByte);
                    eq(chunk2.text(), chunk1);
                    currentByte += chunk2.len();
                }
            }

            var chunks = t.chunksAt(blen(TEXT));
            var idx = chunks.startByteIdx;
            eq(blen(TEXT), idx);
            eq(null, chunks.next());
        }
    }

    public function test_chunks_at_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(5, 124);
            var text = bsub(TEXT, 5, 124);

            for (i in 0...blen(text)) {
                var currentByte = s.chunk(i).byteIdx;
                var chunks = s.chunksAt(i);
                var idx = chunks.startByteIdx;
                eq(currentByte, idx);

                var chunk1;
                while ((chunk1 = chunks.next()) != null) {
                    var chunk2 = s.chunk(currentByte);
                    eq(chunk2.text(), chunk1);
                    currentByte += chunk2.len();
                }
            }

            var chunks = s.chunksAt(blen(text));
            var idx = chunks.startByteIdx;
            eq(blen(text), idx);
            eq(null, chunks.next());
        }
    }

    public function test_chunks_at_03() {
        panics(() -> {
            var r = Rope.fromStr("foo");
            r.chunksAt(4);
        });
    }

    public function test_chunks_at_04() {
        panics(() -> {
            var r = Rope.fromStr("foo");
            var s = r.slice(1, 2);
            s.chunksAt(2);
        });
    }

    public function test_chunks_iter_size_hint_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(5, 124);

            var chunks = s.chunks();

            // Forward.
            isTrue(chunks.clone().count() >= chunks.sizeHint());
            while (chunks.next() != null) {
                isTrue(chunks.clone().count() >= chunks.sizeHint());
            }
            eq(0, chunks.sizeHint());

            // Backward.
            chunks = chunks.reversed();
            isTrue(chunks.clone().count() >= chunks.sizeHint());
            while (chunks.next() != null) {
                isTrue(chunks.clone().count() >= chunks.sizeHint());
            }
            eq(0, chunks.sizeHint());
        }
    }

    function checkBytesAgainstText(bytes:ropey.iter.Bytes, text:String) {
        // Forward.
        var iterF = bytesArrayOf(text);
        var i = 0;
        while (true) {
            var b1 = bytes.next();
            var b2 = i < iterF.length ? iterF[i++] : -1;

            eq(b1, b2);

            if (b1 == -1 && b2 == -1) {
                break;
            }
        }

        // Backward.
        var iterB = bytesArrayOf(text);
        iterB.reverse();
        i = 0;
        while (true) {
            var b1 = bytes.prev();
            var b2 = i < iterB.length ? iterB[i++] : -1;

            eq(b1, b2);

            if (b1 == -1 && b2 == -1) {
                break;
            }
        }
    }

    public function test_bytes_iter_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var iter = t.bytes();

            checkBytesAgainstText(iter, TEXT);
        }
    }

    public function test_bytes_iter_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(5, 124);
            var iter = s.bytes();

            checkBytesAgainstText(iter, bsub(TEXT, 5, 124));
        }
    }

    public function test_bytes_iter_03() {
        var text = "abc";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var text = bytesArrayOf(text);

            var bytes = t.bytes();

            eq((text[0]), bytes.next());
            eq((text[0]), bytes.prev());
            eq(-1, bytes.prev());

            eq((text[0]), bytes.next());
            eq((text[1]), bytes.next());
            eq((text[1]), bytes.prev());

            eq((text[1]), bytes.next());
            eq((text[2]), bytes.next());
            eq((text[2]), bytes.prev());

            eq((text[2]), bytes.next());
            eq(-1, bytes.next());
            eq((text[2]), bytes.prev());
        }
    }

    public function test_bytes_iter_04() {
        var r = Rope.fromStr("");
        for (t in makeTestData(r, "")) {
            eq(-1, t.bytes().next());
            eq(-1, t.bytes().prev());
        }
    }

    public function test_bytes_at_01() {
        var r = Rope.fromStr(TEXT);

        for (t in makeTestData(r, TEXT)) {
            for (i in 0...blen(TEXT)) {
                var bytes = t.bytesAt(i);
                eq(bytesArrayOf(TEXT)[i], bytes.next());
            }

            var bytes = t.bytesAt(blen(TEXT));
            eq(-1, bytes.next());
        }
    }

    public function test_bytes_at_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(5, 124);
            var text = bsub(TEXT, 5, 124);

            for (i in 0...blen(text)) {
                var bytes = s.bytesAt(i);
                eq(bytesArrayOf(text)[i], bytes.next());
            }

            var bytes = s.bytesAt(blen(text));
            eq(-1, bytes.next());
        }
    }

    public function test_bytes_at_03() {
        panics(() -> {
            var r = Rope.fromStr("foo");
            r.bytesAt(4);
        });
    }

    public function test_bytes_at_04() {
        panics(() -> {
            var r = Rope.fromStr("foo");
            var s = r.slice(1, 2);
            s.bytesAt(2);
        });
    }

    public function test_bytes_iter_size_hint_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(5, 124);

            var bytes = s.bytes();

            // Forward.
            eq(bytes.clone().count(), bytes.sizeHint());
            while (bytes.next() != -1) {
                eq(bytes.clone().count(), bytes.sizeHint());
            }
            eq(0, bytes.sizeHint());

            // Backward.
            bytes = bytes.reversed();
            eq(bytes.clone().count(), bytes.sizeHint());
            while (bytes.next() != -1) {
                eq(bytes.clone().count(), bytes.sizeHint());
            }
            eq(0, bytes.sizeHint());
        }
    }

    function checkCharsAgainstText(chars:ropey.iter.Chars, text:String) {
        // Forward.
        var iterF = charsOf(text);
        var i = 0;
        while (true) {
            var c1 = chars.next();
            var c2 = i < iterF.length ? iterF[i++] : -1;

            eq(c1, c2);

            if (c1 == -1 && c2 == -1) {
                break;
            }
        }

        // Backward.
        var iterB = charsOf(text);
        iterB.reverse();
        i = 0;
        while (true) {
            var c1 = chars.prev();
            var c2 = i < iterB.length ? iterB[i++] : -1;

            eq(c1, c2);

            if (c1 == -1 && c2 == -1) {
                break;
            }
        }
    }

    public function test_chars_iter_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var iter = t.chars();

            checkCharsAgainstText(iter, TEXT);
        }
    }

    public function test_chars_iter_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(5, 124);
            var iter = s.chars();

            checkCharsAgainstText(iter, bsub(TEXT, 5, 124));
        }
    }

    public function test_chars_iter_03() {
        var text = "abc";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var chars = t.chars();

            eq(("a".code), chars.next());
            eq(("a".code), chars.prev());
            eq(-1, chars.prev());

            eq(("a".code), chars.next());
            eq(("b".code), chars.next());
            eq(("b".code), chars.prev());

            eq(("b".code), chars.next());
            eq(("c".code), chars.next());
            eq(("c".code), chars.prev());

            eq(("c".code), chars.next());
            eq(-1, chars.next());
            eq(("c".code), chars.prev());
        }
    }

    public function test_chars_iter_04() {
        var r = Rope.fromStr("");

        for (t in makeTestData(r, "")) {
            eq(-1, t.chars().next());
            eq(-1, t.chars().prev());
        }
    }

    public function test_chars_at_t1() {
        var r = Rope.fromStr(TEXT);

        for (t in makeTestData(r, TEXT)) {
            for (i in 0...blen(TEXT)) {
                if (!isCharBoundary(TEXT, i)) {
                    continue;
                }
                var chars = t.charsAt(i);
                eq(charsOf(bfrom(TEXT, i))[0], chars.next());
            }

            var chars = t.charsAt(blen(TEXT));
            eq(-1, chars.next());
        }
    }

    public function test_chars_at_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(5, 124);
            var text = bsub(TEXT, 5, 124);

            for (i in 0...blen(text)) {
                if (!isCharBoundary(text, i)) {
                    continue;
                }
                var chars = s.charsAt(i);
                eq(charsOf(bfrom(text, i))[0], chars.next());
            }

            var chars = s.charsAt(blen(text));
            eq(-1, chars.next());
        }
    }

    public function test_chars_at_03() {
        panics(() -> {
            var r = Rope.fromStr("foo");
            r.charsAt(4);
        });
    }

    public function test_chars_at_04() {
        panics(() -> {
            var r = Rope.fromStr("foo");
            var s = r.slice(1, 2);
            s.charsAt(2);
        });
    }

    public function test_chars_iter_size_hint_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(5, 124);

            var chars = s.chars();

            // Forward.
            isTrue(chars.clone().count() >= chars.sizeHint());
            isTrue(chars.clone().count() <= chars.sizeHintMax());
            while (chars.next() != -1) {
                isTrue(chars.clone().count() >= chars.sizeHint());
                isTrue(chars.clone().count() <= chars.sizeHintMax());
            }
            eq(0, chars.sizeHint());
            eq(0, chars.sizeHintMax());

            // Backward.
            chars = chars.reversed();
            isTrue(chars.clone().count() >= chars.sizeHint());
            isTrue(chars.clone().count() <= chars.sizeHintMax());
            while (chars.next() != -1) {
                isTrue(chars.clone().count() >= chars.sizeHint());
                isTrue(chars.clone().count() <= chars.sizeHintMax());
            }
            eq(0, chars.sizeHint());
            eq(0, chars.sizeHintMax());
        }
    }

    public function test_lines_01() {
        var r = makeRopeFromChunks([
            "\nHi ",
            "there",
            " thing\nwith\n",
            "\nline\nbreaks",
            "\nand ",
            "stuff ",
            "in ",
            "it\n",
            "yar",
        ]);
        var lines = r.lines(LineType.LF_CR);

        // Forward.
        eq("\n", lines.next());
        eq("Hi there thing\n", lines.next());
        eq("with\n", lines.next());
        eq("\n", lines.next());
        eq("line\n", lines.next());
        eq("breaks\n", lines.next());
        eq("and stuff in it\n", lines.next());
        eq("yar", lines.next());
        eq(null, lines.next());

        // Backward.
        eq("yar", lines.prev());
        eq("and stuff in it\n", lines.prev());
        eq("breaks\n", lines.prev());
        eq("line\n", lines.prev());
        eq("\n", lines.prev());
        eq("with\n", lines.prev());
        eq("Hi there thing\n", lines.prev());
        eq("\n", lines.prev());
        eq(null, lines.prev());
    }

    public function test_lines_02() {
        var text = "hi\nyo\nbye";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var lines = t.lines(LineType.LF_CR);

            eq("hi\n", lines.next());
            eq("hi\n", lines.prev());
            eq(null, lines.prev());

            eq("hi\n", lines.next());
            eq("yo\n", lines.next());
            eq("yo\n", lines.prev());

            eq("yo\n", lines.next());
            eq("bye", lines.next());
            eq(null, lines.next());
            eq("bye", lines.prev());
        }
    }

    public function test_lines_03() {
        var text = "Hello there!\nHow goes it?";
        var r = Rope.fromStr(text);
        var s = r.sliceFrom(0);
        var t = RopeSlice.fromStr(text);

        eq(2, r.lines(LineType.LF_CR).count());
        eq(2, s.lines(LineType.LF_CR).count());
        eq(2, t.lines(LineType.LF_CR).count());

        var lines = r.lines(LineType.LF_CR);
        eq("Hello there!\n", lines.next());
        eq("How goes it?", lines.next());
        isTrue(lines.next() == null);

        var lines = s.lines(LineType.LF_CR);
        eq("Hello there!\n", lines.next());
        eq("How goes it?", lines.next());
        isTrue(lines.next() == null);

        var lines = t.lines(LineType.LF_CR);
        eq("Hello there!\n", lines.next());
        eq("How goes it?", lines.next());
        isTrue(lines.next() == null);
    }

    public function test_lines_04() {
        var text = "Hello there!\nHow goes it?\n";
        var r = Rope.fromStr(text);
        var s = r.sliceFrom(0);
        var t = RopeSlice.fromStr(text);

        eq(3, r.lines(LineType.LF_CR).count());
        eq(3, s.lines(LineType.LF_CR).count());
        eq(3, t.lines(LineType.LF_CR).count());

        var lines = r.lines(LineType.LF_CR);
        eq("Hello there!\n", lines.next());
        eq("How goes it?\n", lines.next());
        eq("", lines.next());
        isTrue(lines.next() == null);

        var lines = s.lines(LineType.LF_CR);
        eq("Hello there!\n", lines.next());
        eq("How goes it?\n", lines.next());
        eq("", lines.next());
        isTrue(lines.next() == null);

        var lines = t.lines(LineType.LF_CR);
        eq("Hello there!\n", lines.next());
        eq("How goes it?\n", lines.next());
        eq("", lines.next());
        isTrue(lines.next() == null);
    }

    public function test_lines_05() {
        var text = "Hello there!\nHow goes it?\nYeah!";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var s1 = t.slice(0, 25);
            var s2 = t.slice(0, 26);

            eq(2, s1.lines(LineType.LF_CR).count());
            eq(3, s2.lines(LineType.LF_CR).count());

            var lines = s1.lines(LineType.LF_CR);
            eq("Hello there!\n", lines.next());
            eq("How goes it?", lines.next());
            isTrue(lines.next() == null);

            var lines = s2.lines(LineType.LF_CR);
            eq("Hello there!\n", lines.next());
            eq("How goes it?\n", lines.next());
            eq("", lines.next());
            isTrue(lines.next() == null);
        }
    }

    public function test_lines_06() {
        var text = "";
        var r = Rope.fromStr(text);
        var s = r.sliceFrom(0);
        var t = RopeSlice.fromStr(text);

        eq(1, r.lines(LineType.LF_CR).count());
        eq(1, s.lines(LineType.LF_CR).count());
        eq(1, t.lines(LineType.LF_CR).count());

        var lines = r.lines(LineType.LF_CR);
        eq("", lines.next());
        isTrue(lines.next() == null);

        var lines = s.lines(LineType.LF_CR);
        eq("", lines.next());
        isTrue(lines.next() == null);

        var lines = t.lines(LineType.LF_CR);
        eq("", lines.next());
        isTrue(lines.next() == null);
    }

    public function test_lines_07() {
        var text = "a";
        var r = Rope.fromStr(text);
        var s = r.sliceFrom(0);
        var t = RopeSlice.fromStr(text);

        eq(1, r.lines(LineType.LF_CR).count());
        eq(1, s.lines(LineType.LF_CR).count());
        eq(1, t.lines(LineType.LF_CR).count());

        var lines = r.lines(LineType.LF_CR);
        eq("a", lines.next());
        isTrue(lines.next() == null);

        var lines = s.lines(LineType.LF_CR);
        eq("a", lines.next());
        isTrue(lines.next() == null);

        var lines = t.lines(LineType.LF_CR);
        eq("a", lines.next());
        isTrue(lines.next() == null);
    }

    public function test_lines_08() {
        var text = "a\nb";
        var r = Rope.fromStr(text);
        var s = r.sliceFrom(0);
        var t = RopeSlice.fromStr(text);

        eq(2, r.lines(LineType.LF_CR).count());
        eq(2, s.lines(LineType.LF_CR).count());
        eq(2, t.lines(LineType.LF_CR).count());

        var lines = r.lines(LineType.LF_CR);
        eq("a\n", lines.next());
        eq("b", lines.next());
        isTrue(lines.next() == null);

        var lines = s.lines(LineType.LF_CR);
        eq("a\n", lines.next());
        eq("b", lines.next());
        isTrue(lines.next() == null);

        var lines = t.lines(LineType.LF_CR);
        eq("a\n", lines.next());
        eq("b", lines.next());
        isTrue(lines.next() == null);
    }

    public function test_lines_09() {
        var text = "\n";
        var r = Rope.fromStr(text);
        var s = r.sliceFrom(0);
        var t = RopeSlice.fromStr(text);

        eq(2, r.lines(LineType.LF_CR).count());
        eq(2, s.lines(LineType.LF_CR).count());
        eq(2, t.lines(LineType.LF_CR).count());

        var lines = r.lines(LineType.LF_CR);
        eq("\n", lines.next());
        eq("", lines.next());
        isTrue(lines.next() == null);

        var lines = s.lines(LineType.LF_CR);
        eq("\n", lines.next());
        eq("", lines.next());
        isTrue(lines.next() == null);

        var lines = t.lines(LineType.LF_CR);
        eq("\n", lines.next());
        eq("", lines.next());
        isTrue(lines.next() == null);
    }

    public function test_lines_10() {
        var text = "a\nb\n";
        var r = Rope.fromStr(text);
        var s = r.sliceFrom(0);
        var t = RopeSlice.fromStr(text);

        eq(3, r.lines(LineType.LF_CR).count());
        eq(3, s.lines(LineType.LF_CR).count());
        eq(3, t.lines(LineType.LF_CR).count());

        var lines = r.lines(LineType.LF_CR);
        eq("a\n", lines.next());
        eq("b\n", lines.next());
        eq("", lines.next());
        isTrue(lines.next() == null);

        var lines = s.lines(LineType.LF_CR);
        eq("a\n", lines.next());
        eq("b\n", lines.next());
        eq("", lines.next());
        isTrue(lines.next() == null);

        var lines = t.lines(LineType.LF_CR);
        eq("a\n", lines.next());
        eq("b\n", lines.next());
        eq("", lines.next());
        isTrue(lines.next() == null);
    }

    public function test_lines_11() {
        var text = linesText();
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var itr = t.lines(LineType.LF_CR);

            eq(null, itr.prev());
            eq(null, itr.prev());
        }
    }

    public function test_lines_12() {
        var text = linesText();
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var lines = [];
            var itr = t.lines(LineType.LF_CR);

            var line;
            while ((line = itr.next()) != null) {
                lines.push(line);
            }

            var line;
            while ((line = itr.prev()) != null) {
                eq(line, lines.pop());
            }

            isTrue(lines.length == 0);
        }
    }

    public function test_lines_13() {
        var text = linesText();
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var s = t.slice(34, 2031);

            var lines = [];
            var itr = s.lines(LineType.LF_CR);

            var line;
            while ((line = itr.next()) != null) {
                lines.push(line);
            }

            var line;
            while ((line = itr.prev()) != null) {
                eq(line, lines.pop());
            }

            isTrue(lines.length == 0);
        }
    }

    public function test_lines_14() {
        var text = "";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var s = t.sliceFrom(0);

            var lines = [];
            var itr = s.lines(LineType.LF_CR);

            var text;
            while ((text = itr.next()) != null) {
                lines.push(text);
            }

            var text;
            while ((text = itr.prev()) != null) {
                eq(text, lines.pop());
            }

            isTrue(lines.length == 0);
        }
    }

    public function test_lines_15() {
        var text = "a";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var s = t.sliceFrom(0);

            var lines = [];
            var itr = s.lines(LineType.LF_CR);

            var text;
            while ((text = itr.next()) != null) {
                lines.push(text);
            }

            var text;
            while ((text = itr.prev()) != null) {
                eq(text, lines.pop());
            }

            isTrue(lines.length == 0);
        }
    }

    public function test_lines_16() {
        var text = "a\nb";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var s = t.sliceFrom(0);

            var lines = [];
            var itr = s.lines(LineType.LF_CR);

            var text;
            while ((text = itr.next()) != null) {
                lines.push(text);
            }

            var text;
            while ((text = itr.prev()) != null) {
                eq(text, lines.pop());
            }

            isTrue(lines.length == 0);
        }
    }

    public function test_lines_17() {
        var text = "\n";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var s = t.sliceFrom(0);

            var lines = [];
            var itr = s.lines(LineType.LF_CR);

            var text;
            while ((text = itr.next()) != null) {
                lines.push(text);
            }

            var text;
            while ((text = itr.prev()) != null) {
                eq(text, lines.pop());
            }

            isTrue(lines.length == 0);
        }
    }

    public function test_lines_18() {
        var text = "a\nb\n";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var s = t.sliceFrom(0);

            var lines = [];
            var itr = s.lines(LineType.LF_CR);

            var text;
            while ((text = itr.next()) != null) {
                lines.push(text);
            }

            var text;
            while ((text = itr.prev()) != null) {
                eq(text, lines.pop());
            }

            isTrue(lines.length == 0);
        }
    }

    public function test_lines_19() {
        var text = linesText();
        var r = Rope.fromStr(text);
        var s = r.sliceFrom(0);
        var t = RopeSlice.fromStr(text);

        eq(34, r.lines(LineType.LF_CR).count());
        eq(34, s.lines(LineType.LF_CR).count());
        eq(34, t.lines(LineType.LF_CR).count());

        // Rope
        var lines = r.lines(LineType.LF_CR);
        eq("\r\n", lines.next());
        for (_ in 0...16) {
            eq(
                "Hello there!  How're you doing?  It's a fine day, isn't it?  Aren't you glad we're alive?\r\n",
                lines.next()
            );
            eq(
                "こんにちは！元気ですか？日はいいですね。私たちが生きだって嬉しいではないか？\r\n",
                lines.next()
            );
        }
        eq("", lines.next());
        isTrue(lines.next() == null);

        // Slice
        var lines = s.lines(LineType.LF_CR);
        eq("\r\n", lines.next());
        for (_ in 0...16) {
            eq(
                "Hello there!  How're you doing?  It's a fine day, isn't it?  Aren't you glad we're alive?\r\n",
                lines.next()
            );
            eq(
                "こんにちは！元気ですか？日はいいですね。私たちが生きだって嬉しいではないか？\r\n",
                lines.next()
            );
        }
        eq("", lines.next());
        isTrue(lines.next() == null);

        // Slice from str
        var lines = t.lines(LineType.LF_CR);
        eq("\r\n", lines.next());
        for (_ in 0...16) {
            eq(
                "Hello there!  How're you doing?  It's a fine day, isn't it?  Aren't you glad we're alive?\r\n",
                lines.next()
            );
            eq(
                "こんにちは！元気ですか？日はいいですね。私たちが生きだって嬉しいではないか？\r\n",
                lines.next()
            );
        }
        eq("", lines.next());
        isTrue(lines.next() == null);
    }

    public function test_lines_20() {
        var text = "a\nb\nc\nd\ne\nf\ng\nh\n";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            // `zip` stops at the shorter of the two.
            var lines = t.lines(LineType.LF_CR);
            for (c in "a".code..."h".code + 1) {
                eq(lines.next(), strOfChar(c) + "\n");
            }
            var lines = t.linesAt(t.lenLines(LineType.LF_CR) - 1, LineType.LF_CR).reversed();
            var c = "h".code;
            var line;
            while ((line = lines.next()) != null && c >= "a".code) {
                eq(line, strOfChar(c) + "\n");
                c--;
            }
        }

        var text = "ab\nc\nd\ne\nf\ng\nh\n";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var lines = t.sliceFrom(1).lines(LineType.LF_CR);
            for (c in "b".code..."h".code + 1) {
                eq(lines.next(), strOfChar(c) + "\n");
            }
        }
    }

    public function test_lines_at_01() {
        var text = linesText();
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            for (i in 0...t.lenLines(LineType.LF_CR)) {
                var line = t.line(i, LineType.LF_CR);
                var lines = t.linesAt(i, LineType.LF_CR);
                eq(line, lines.next());
            }

            var lines = t.linesAt(t.lenLines(LineType.LF_CR), LineType.LF_CR);
            eq(null, lines.next());
        }
    }

    public function test_lines_at_02() {
        var text = linesText();
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var s = t.slice(34, 2031);

            for (i in 0...s.lenLines(LineType.LF_CR)) {
                var line = s.line(i, LineType.LF_CR);
                var lines = s.linesAt(i, LineType.LF_CR);
                eq(line, lines.next());
            }

            var lines = s.linesAt(s.lenLines(LineType.LF_CR), LineType.LF_CR);
            eq(null, lines.next());
        }
    }

    public function test_lines_at_03() {
        var text = linesText();
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var s = t.slice(34, 34);

            var lines = s.linesAt(0, LineType.LF_CR);
            eq("", lines.next());

            var lines = s.linesAt(1, LineType.LF_CR);
            eq(null, lines.next());
        }
    }

    public function test_lines_at_04() {
        panics(() -> {
            var r = Rope.fromStr("AA\nA");
            r.linesAt(3, LineType.LF_CR);
        });
    }

    public function test_lines_at_05() {
        panics(() -> {
            var r = Rope.fromStr("AA\nA");
            var s = r.slice(1, 2);
            s.linesAt(2, LineType.LF_CR);
        });
    }

    public function test_lines_iter_size_hint_01() {
        var text = linesText();
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            var s = t.slice(34, 2031);

            var lines = s.lines(LineType.LF_CR);
            var lineCount = lines.clone().count();

            // Forward.
            eq(lineCount, lines.sizeHint());
            while (lines.next() != null) {
                lineCount -= 1;
                eq(lineCount, lines.sizeHint());
            }
            eq(lineCount, 0);
            eq(lineCount, lines.sizeHint());

            // Backward.
            lines = lines.reversed();
            lineCount = lines.clone().count();
            eq(lineCount, lines.sizeHint());
            while (lines.next() != null) {
                lineCount -= 1;
                eq(lineCount, lines.sizeHint());
            }
            eq(lineCount, 0);
            eq(lineCount, lines.sizeHint());
        }
    }

    // Not from upstream: the Haxe `for` loop adapters.
    public function test_haxe_iterators() {
        var r = makeRopeFromChunks(["ab\n", "c\nd", "é"]);
        eq([for (c in r.chunks()) c], ["ab\n", "c\nd", "é"]);
        eq([for (b in r.bytes()) b], bytesArrayOf("ab\nc\ndé"));
        eq([for (c in r.chars()) c], charsOf("ab\nc\ndé"));
        eq([for (l in r.lines(LineType.LF)) l.toString()], ["ab\n", "c\n", "dé"]);
        eq([for (i => c in r.charIndices()) i], [0, 1, 2, 3, 4, 5, 6]);
        eq([for (i => c in r.charIndices()) c], charsOf("ab\nc\ndé"));
        eq([for (c in r.charsAt(r.len()).reversed()) c], [0xE9, "d".code, "\n".code, "c".code, "\n".code, "b".code, "a".code]);
    }

}
