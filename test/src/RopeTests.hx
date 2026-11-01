// Ported from ropey 2.0.0-beta.1: src/rope.rs (tests)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

import TestUtil.*;
import ropey.LineType;
import ropey.Rope;

class RopeTests {

    public function new() {}

    function makeRopeAndTextFromChunks(chunks:Array<String>):Rope {
        return makeRopeFromChunks(chunks);
    }

    public function test_insert_01() {
        var r = Rope.fromStr(TEXT);
        r.insert(3, "AA");

        eq(r, "HelAAlo there!  How're you doing?  It's "
            + "a fine day, isn't it?  Aren't you glad "
            + "we're alive?  こんにちは、みんなさん！");

        r.assertInvariants();
    }

    public function test_insert_02() {
        var r = Rope.fromStr(TEXT);
        r.insert(0, "AA");

        eq(r, "AAHello there!  How're you doing?  It's "
            + "a fine day, isn't it?  Aren't you glad "
            + "we're alive?  こんにちは、みんなさん！");

        r.assertInvariants();
    }

    public function test_insert_03() {
        var r = Rope.fromStr(TEXT);
        r.insert(127, "AA");

        eq(r, "Hello there!  How're you doing?  It's "
            + "a fine day, isn't it?  Aren't you glad "
            + "we're alive?  こんにちは、みんなさん！AA");

        r.assertInvariants();
    }

    public function test_insert_04() {
        var r = Rope.fromStr(TEXT);
        r.insert(3, "");

        eq(r, "Hello there!  How're you doing?  It's "
            + "a fine day, isn't it?  Aren't you glad "
            + "we're alive?  こんにちは、みんなさん！");

        r.assertInvariants();
    }

    public function test_insert_05() {
        var r = new Rope();
        r.insert(0, "He");
        r.insert(2, "l");
        r.insert(3, "l");
        r.insert(4, "o w");
        r.insert(7, "o");
        r.insert(8, "rl");
        r.insert(10, "d!");
        r.insert(3, "zopter");

        eq("Helzopterlo world!", r);

        r.assertInvariants();
    }

    public function test_insert_06() {
        var r = new Rope();
        r.insert(0, "こんいちは、みんなさん！");
        r.insert(21, "zopter");
        eq("こんいちは、みzopterんなさん！", r);

        r.assertInvariants();
    }

    public function test_insert_07() {
        var r = new Rope();
        r.insert(0, "こ");
        r.insert(3, "ん");
        r.insert(6, "い");
        r.insert(9, "ち");
        r.insert(12, "は");
        r.insert(15, "、");
        r.insert(18, "み");
        r.insert(21, "ん");
        r.insert(24, "な");
        r.insert(27, "さ");
        r.insert(30, "ん");
        r.insert(33, "！");
        r.insert(21, "zopter");
        eq("こんいちは、みzopterんなさん！", r);

        r.assertInvariants();
    }

    public function test_insert_08() {
        var r = Rope.fromStr(TEXT);
        // Out of bounds.
        panics(() -> r.insert(128, "A"));
    }

    public function test_insert_09() {
        var r = Rope.fromStr(TEXT);
        // Out of bounds.
        panics(() -> r.insert(128, ""));
    }

    public function test_insert_10() {
        var r = Rope.fromStr(TEXT);
        // Non-char boundary.
        panics(() -> r.insert(126, "A"));
    }

    public function test_insert_11() {
        var r = Rope.fromStr(TEXT);
        // Non-char boundary.
        panics(() -> r.insert(126, ""));
    }

    public function test_insert_12() {
        var r0 = makeRopeAndTextFromChunks(["\n\r", "\r\n", "\n\r", "\r\n", "\n\r"]);

        var inserts:Array<Array<Dynamic>> = [[0, "\r"], [2, "\n"], [4, "\r"], [6, "\n"], [8, "\r"], [10, "\n"]];
        for (insert in inserts) {
            var r = r0.clone();
            r.insert(insert[0], insert[1]);
            r.assertNoCrlfSplits();
            r.assertAccurateTextInfo();
        }
    }

    public function test_remove_01() {
        var rope = Rope.fromStr(TEXT);
        rope.remove(0, 4);
        rope.remove(5, 7);
        rope.remove(28, 37);
        rope.remove(35, 109);

        eq(rope, "o the!  How're you doing?  Ie day, ！");
    }

    public function test_remove_02() {
        var rope = Rope.fromStr(TEXT);
        rope.remove(0, 42);

        eq(rope, "ne day, isn't it?  Aren't you glad we're "
            + "alive?  こんにちは、みんなさん！");
    }

    public function test_remove_03() {
        var rope = Rope.fromStr(TEXT);
        rope.removeFrom(42);

        eq(rope, "Hello there!  How're you doing?  It's a fi");
    }

    public function test_remove_04() {
        var rope = Rope.fromStr(TEXT);
        rope.removeFrom(0);

        eq(rope, "");
    }

    public function test_remove_05() {
        var rope = Rope.fromStr(TEXT);
        rope.remove(42, 42);

        eq(rope, TEXT);
    }

    public function test_remove_06() {
        var rope = Rope.fromStr(TEXT);
        // Out of bounds.
        panics(() -> rope.remove(42, 128));
    }

    public function test_remove_07() {
        var rope = Rope.fromStr(TEXT);
        // Out of bounds.
        panics(() -> rope.remove(128, 128));
    }

    public function test_remove_08() {
        var rope = Rope.fromStr(TEXT);
        // Non-char boundary.
        panics(() -> rope.remove(42, 126));
    }

    public function test_remove_09() {
        var rope = Rope.fromStr(TEXT);
        // Non-char boundary.
        panics(() -> rope.remove(126, 127));
    }

    public function test_remove_10() {
        var rope = Rope.fromStr(TEXT);
        // Non-char boundary.
        panics(() -> rope.remove(126, 126));
    }

    public function test_remove_11() {
        var rope = Rope.fromStr(TEXT);
        // Invalid range.
        panics(() -> rope.remove(42, 21));
    }

    // Removal failure should be atomic: either it fails with no modification,
    // or the whole intended modification completes.
    //
    // Note: upstream uses `fuzz/fuzz_targets/small.txt`, which is not shipped
    // in the crate. This uses the crate's `benches/small.txt` (ASCII only)
    // with a 3 byte char inserted at byte 558, so that byte 559 is not a char
    // boundary and the removal fails.
    public function test_try_remove_failure_01() {
        var text = bto(SmallText.SMALL_TEXT, 558) + "こ" + bfrom(SmallText.SMALL_TEXT, 558);
        var r = Rope.fromStr(text);
        var rOriginal = r.clone();
        var result = r.tryRemove(19, 559);

        isTrue(result != null);
        eq(r, rOriginal);
        r.assertInvariants();
    }

    public function test_byte_to_char_idx_01() {
        var r = Rope.fromStr(TEXT);

        eq(0, r.byteToCharIdx(0));
        eq(1, r.byteToCharIdx(1));
        eq(2, r.byteToCharIdx(2));

        eq(91, r.byteToCharIdx(91));
        eq(91, r.byteToCharIdx(92));
        eq(91, r.byteToCharIdx(93));

        eq(92, r.byteToCharIdx(94));
        eq(92, r.byteToCharIdx(95));
        eq(92, r.byteToCharIdx(96));

        eq(102, r.byteToCharIdx(124));
        eq(102, r.byteToCharIdx(125));
        eq(102, r.byteToCharIdx(126));
        eq(103, r.byteToCharIdx(127));
    }

    public function test_char_to_byte_idx_01() {
        var r = Rope.fromStr(TEXT);

        eq(0, r.charToByteIdx(0));
        eq(1, r.charToByteIdx(1));
        eq(2, r.charToByteIdx(2));

        eq(91, r.charToByteIdx(91));
        eq(94, r.charToByteIdx(92));
        eq(97, r.charToByteIdx(93));
        eq(100, r.charToByteIdx(94));

        eq(124, r.charToByteIdx(102));
        eq(127, r.charToByteIdx(103));
    }

    public function test_byte_to_utf16_idx_01() {
        var r = Rope.fromStr(TEXT_EMOJI);

        eq(0, r.byteToUtf16Idx(0));

        eq(12, r.byteToUtf16Idx(12));
        eq(12, r.byteToUtf16Idx(13));
        eq(14, r.byteToUtf16Idx(16));

        eq(33, r.byteToUtf16Idx(35));
        eq(33, r.byteToUtf16Idx(36));
        eq(35, r.byteToUtf16Idx(39));

        eq(63, r.byteToUtf16Idx(67));
        eq(63, r.byteToUtf16Idx(70));
        eq(65, r.byteToUtf16Idx(71));

        eq(95, r.byteToUtf16Idx(101));
        eq(95, r.byteToUtf16Idx(102));
        eq(97, r.byteToUtf16Idx(105));

        eq(111, r.byteToUtf16Idx(143));
    }

    public function test_utf16_to_byte_idx_01() {
        var r = Rope.fromStr(TEXT_EMOJI);

        eq(0, r.utf16ToByteIdx(0));

        eq(12, r.utf16ToByteIdx(12));
        eq(16, r.utf16ToByteIdx(14));

        eq(35, r.utf16ToByteIdx(33));
        eq(39, r.utf16ToByteIdx(35));

        eq(67, r.utf16ToByteIdx(63));
        eq(71, r.utf16ToByteIdx(65));

        eq(101, r.utf16ToByteIdx(95));
        eq(105, r.utf16ToByteIdx(97));

        eq(143, r.utf16ToByteIdx(111));
    }

    public function test_byte_to_line_idx_01() {
        var r = Rope.fromStr(TEXT_LINES);
        var byteToLineIdxs = [
            [0, 0],
            [1, 0],
            [31, 0],
            [32, 1],
            [33, 1],
            [58, 1],
            [59, 2],
            [60, 2],
            [87, 2],
            [88, 3],
            [89, 3],
            [124, 3],
        ];
        for (bl in byteToLineIdxs) {
            var b = bl[0];
            var l = bl[1];
            eq(l, r.byteToLineIdx(b, LineType.LF));
            eq(l, r.byteToLineIdx(b, LineType.LF_CR));
        }
    }

    public function test_byte_to_line_idx_02() {
        var r = Rope.fromStr("");

        eq(0, r.byteToLineIdx(0, LineType.LF));
        eq(0, r.byteToLineIdx(0, LineType.LF_CR));
    }

    public function test_byte_to_line_idx_03() {
        var r = Rope.fromStr(TEXT_LINES);
        panics(() -> r.byteToLineIdx(125, LineType.LF));
    }

    public function test_byte_to_line_idx_04() {
        var r = Rope.fromStr(TEXT_LINES);
        panics(() -> r.byteToLineIdx(125, LineType.LF_CR));
    }

    public function test_line_to_byte_idx_01() {
        var r = Rope.fromStr(TEXT_LINES);
        var byteToLineIdxs = [[0, 0], [32, 1], [59, 2], [88, 3], [124, 4]];
        for (bl in byteToLineIdxs) {
            var b = bl[0];
            var l = bl[1];
            eq(b, r.lineToByteIdx(l, LineType.LF));
            eq(b, r.lineToByteIdx(l, LineType.LF_CR));
        }
    }

    public function test_line_to_byte_idx_02() {
        var r = Rope.fromStr("");
        eq(0, r.lineToByteIdx(0, LineType.LF));
        eq(0, r.lineToByteIdx(1, LineType.LF));
        eq(0, r.lineToByteIdx(0, LineType.LF_CR));
        eq(0, r.lineToByteIdx(1, LineType.LF_CR));
    }

    public function test_line_to_byte_idx_03() {
        var r = Rope.fromStr(TEXT_LINES);
        panics(() -> r.lineToByteIdx(5, LineType.LF));
    }

    public function test_line_to_byte_idx_04() {
        var r = Rope.fromStr(TEXT_LINES);
        panics(() -> r.lineToByteIdx(5, LineType.LF_CR));
    }

    public function test_hash_01() {
        var r1 = makeRopeFromChunks(["Hello ", "world!"]);
        var r2 = makeRopeFromChunks(["Hell", "o world!"]);

        eq(r1.hash(), r2.hash());
    }

    public function test_hash_02() {
        var r1 = Rope.fromStr("Hello there!");
        var r2 = Rope.fromStr("Hello there.");

        ne(r1.hash(), r2.hash());
    }

    public function test_hash_03() {
        // `Rope::hash_slice(&s, &mut h2)`: the ropes of `s` hashed in a row.
        var r = Rope.fromStr("Hello there!");
        var s = [Rope.fromStr("Hello "), Rope.fromStr("there!")];

        var h1 = r.hash();
        var h2 = s[1].hash(s[0].hash());

        ne(h1, h2);
    }

}
