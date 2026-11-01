// Ported from ropey 2.0.0-beta.1: src/slice.rs (tests)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

import TestUtil.*;
import ropey.LineType;
import ropey.Rope;
import ropey.RopeSlice;

@:access(ropey)
class SliceTests {

    public function new() {}

    // `reslice` and `iterator_of_tmp_slice` are compile time lifetime checks
    // in Rust: they are kept as plain calls.
    public function test_reslice() {
        var r = Rope.fromStr(TEXT);
        var s = {
            var s1 = r.slice(4, 32);
            s1.slice(2, 24);
        };
        eq(s, bsub(TEXT, 6, 28));
    }

    public function test_iterator_of_tmp_slice() {
        var r = Rope.fromStr(TEXT);
        var s1 = r.slice(4, 32);
        var iterators:Array<Dynamic> = [
            s1.bytes(),
            s1.bytesAt(1),
            s1.chars(),
            s1.charsAt(1),
            s1.lines(LineType.LF_CR),
            s1.linesAt(1, LineType.LF_CR),
            s1.chunks(),
            s1.chunksAt(1),
            s1.chunkCursor(),
            s1.chunkCursorAt(1),
        ];
        eq(iterators.length, 10);
    }

    public function test_len_01() {
        var r = Rope.fromStr(TEXT);

        for (t in makeTestData(r, TEXT, 7, 97)) {
            eq(t.len(), 90);
        }
    }

    public function test_len_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 43, 43)) {
            eq(t.len(), 0);
        }
    }

    public function test_len_chars_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 7, 97)) {
            eq(t.lenChars(), 86);
        }
    }

    public function test_len_chars_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 43, 43)) {
            eq(t.lenChars(), 0);
        }
    }

    public function test_len_lines_01() {
        var r = Rope.fromStr(TEXT_LINES);
        for (t in makeTestData(r, TEXT_LINES, 34, 97)) {
            eq(t.lenLines(LineType.LF_CR), 3);
        }
    }

    public function test_len_lines_02() {
        var r = Rope.fromStr(TEXT_LINES);
        for (t in makeTestData(r, TEXT_LINES, 43, 43)) {
            eq(t.lenLines(LineType.LF_CR), 1);
        }
    }

    public function test_len_utf16_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            eq(t.lenUtf16(), 103);
        }
    }

    public function test_len_utf16_02() {
        var r = Rope.fromStr(TEXT_EMOJI);
        for (t in makeTestData(r, TEXT_EMOJI)) {
            eq(t.lenUtf16(), 111);
        }
    }

    public function test_len_utf16_03() {
        var r = Rope.fromStr(TEXT_EMOJI);
        for (t in makeTestData(r, TEXT_EMOJI, 16, 39)) {
            eq(t.lenUtf16(), 21);
        }
    }

    public function test_len_utf16_04() {
        var r = Rope.fromStr("🐸");
        for (t in makeTestData(r, "🐸")) {
            eq(t.lenUtf16(), 2);
        }
    }

    public function test_len_utf16_05() {
        var r = Rope.fromStr("");
        for (t in makeTestData(r, "")) {
            eq(t.lenUtf16(), 0);
        }
    }

    public function test_is_char_boundary_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            isTrue(t.isCharBoundary(0));
            isTrue(t.isCharBoundary(127));

            var s = t.slice(7, 103);
            var text = bsub(TEXT, 7, 103);
            for (i in 0...s.len()) {
                eq(isCharBoundary(text, i), s.isCharBoundary(i));
            }
        }
    }

    public function test_floor_char_boundary_01() {
        var r = Rope.fromStr(TEXT_EMOJI);
        for (t in makeTestData(r, TEXT_EMOJI, 3, 137)) {
            eq(0, t.floorCharBoundary(0));
            eq(1, t.floorCharBoundary(1));
            eq(2, t.floorCharBoundary(2));

            eq(9, t.floorCharBoundary(9));
            eq(9, t.floorCharBoundary(10));
            eq(9, t.floorCharBoundary(11));
            eq(9, t.floorCharBoundary(12));
            eq(13, t.floorCharBoundary(13));

            eq(104, t.floorCharBoundary(104));
            eq(104, t.floorCharBoundary(105));
            eq(104, t.floorCharBoundary(106));
            eq(107, t.floorCharBoundary(107));

            eq(134, t.floorCharBoundary(134));
        }
    }

    public function test_ceil_char_boundary_01() {
        var r = Rope.fromStr(TEXT_EMOJI);
        for (t in makeTestData(r, TEXT_EMOJI, 3, 137)) {
            eq(0, t.ceilCharBoundary(0));
            eq(1, t.floorCharBoundary(1));
            eq(2, t.floorCharBoundary(2));

            eq(9, t.ceilCharBoundary(9));
            eq(13, t.ceilCharBoundary(10));
            eq(13, t.ceilCharBoundary(11));
            eq(13, t.ceilCharBoundary(12));
            eq(13, t.ceilCharBoundary(13));

            eq(104, t.ceilCharBoundary(104));
            eq(107, t.ceilCharBoundary(105));
            eq(107, t.ceilCharBoundary(106));
            eq(107, t.ceilCharBoundary(107));

            eq(134, t.ceilCharBoundary(134));
        }
    }

    public function test_byte_to_char_idx_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 88, 124)) {
            eq("?  こんにちは、みんなさん", t);

            eq(0, t.byteToCharIdx(0));
            eq(1, t.byteToCharIdx(1));
            eq(2, t.byteToCharIdx(2));

            eq(3, t.byteToCharIdx(3));
            eq(3, t.byteToCharIdx(4));
            eq(3, t.byteToCharIdx(5));

            eq(4, t.byteToCharIdx(6));
            eq(4, t.byteToCharIdx(7));
            eq(4, t.byteToCharIdx(8));

            eq(13, t.byteToCharIdx(33));
            eq(13, t.byteToCharIdx(34));
            eq(13, t.byteToCharIdx(35));
            eq(14, t.byteToCharIdx(36));
        }
    }

    public function test_byte_to_utf16_idx_01() {
        var r = Rope.fromStr("");
        for (t in makeTestData(r, "")) {
            eq(0, t.byteToUtf16Idx(0));
        }
    }

    public function test_byte_to_utf16_idx_02a() {
        panics(() -> {
            var r = Rope.fromStr("");
            var s = r.sliceFrom(0);
            s.byteToUtf16Idx(1);
        });
    }

    public function test_byte_to_utf16_idx_02b() {
        panics(() -> {
            var s = RopeSlice.fromStr("");
            s.byteToUtf16Idx(1);
        });
    }

    public function test_byte_to_utf16_idx_03() {
        var r = Rope.fromStr("🐸");
        for (t in makeTestData(r, "🐸")) {
            eq(0, t.byteToUtf16Idx(0));
            eq(0, t.byteToUtf16Idx(1));
            eq(0, t.byteToUtf16Idx(2));
            eq(0, t.byteToUtf16Idx(3));
            eq(2, t.byteToUtf16Idx(4));
        }
    }

    public function test_byte_to_utf16_idx_04a() {
        panics(() -> {
            var r = Rope.fromStr("🐸");
            var s = r.sliceFrom(0);
            s.byteToUtf16Idx(5);
        });
    }

    public function test_byte_to_utf16_idx_04b() {
        panics(() -> {
            var s = RopeSlice.fromStr("🐸");
            s.byteToUtf16Idx(5);
        });
    }

    public function test_byte_to_utf16_idx_05() {
        var r = Rope.fromStr(TEXT_EMOJI);
        for (t in makeTestData(r, TEXT_EMOJI)) {
            eq(0, t.byteToUtf16Idx(0));

            eq(12, t.byteToUtf16Idx(12));
            eq(14, t.byteToUtf16Idx(16));

            eq(33, t.byteToUtf16Idx(35));
            eq(35, t.byteToUtf16Idx(39));

            eq(63, t.byteToUtf16Idx(67));
            eq(65, t.byteToUtf16Idx(71));

            eq(95, t.byteToUtf16Idx(101));
            eq(97, t.byteToUtf16Idx(105));

            eq(99, t.byteToUtf16Idx(107));
            eq(100, t.byteToUtf16Idx(110));

            eq(110, t.byteToUtf16Idx(140));
            eq(111, t.byteToUtf16Idx(143));
        }
    }

    public function test_byte_to_utf16_06a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT_EMOJI);
            var s = r.sliceFrom(0);
            s.byteToUtf16Idx(144);
        });
    }

    public function test_byte_to_utf16_06b() {
        panics(() -> {
            var s = RopeSlice.fromStr(TEXT_EMOJI);
            s.byteToUtf16Idx(144);
        });
    }

    public function test_byte_to_utf16_idx_07() {
        var r = Rope.fromStr(TEXT_EMOJI);
        for (t in makeTestData(r, TEXT_EMOJI, 1, 137)) {
            eq(0, t.byteToUtf16Idx(0));

            eq(11, t.byteToUtf16Idx(11));
            eq(13, t.byteToUtf16Idx(15));

            eq(32, t.byteToUtf16Idx(34));
            eq(34, t.byteToUtf16Idx(38));

            eq(62, t.byteToUtf16Idx(66));
            eq(64, t.byteToUtf16Idx(70));

            eq(94, t.byteToUtf16Idx(100));
            eq(96, t.byteToUtf16Idx(104));

            eq(98, t.byteToUtf16Idx(106));
            eq(99, t.byteToUtf16Idx(109));

            eq(107, t.byteToUtf16Idx(133));
            eq(108, t.byteToUtf16Idx(136));
        }
    }

    public function test_byte_to_utf16_idx_08a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT_EMOJI);
            var s = r.slice(1, 137);
            s.byteToUtf16Idx(137);
        });
    }

    public function test_byte_to_utf16_idx_08b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT_EMOJI, 1, 137));
            s.byteToUtf16Idx(137);
        });
    }

    public function test_byte_to_line_idx_01() {
        var r = Rope.fromStr(TEXT_LINES);
        for (t in makeTestData(r, TEXT_LINES, 34, 112)) {
            eq(
                "'s a fine day, isn't it?\nAren't you glad we're alive?\nこんにちは、みん",
                t
            );

            eq(0, t.byteToLineIdx(0, LineType.LF_CR));
            eq(0, t.byteToLineIdx(1, LineType.LF_CR));

            eq(0, t.byteToLineIdx(24, LineType.LF_CR));
            eq(1, t.byteToLineIdx(25, LineType.LF_CR));
            eq(1, t.byteToLineIdx(26, LineType.LF_CR));

            eq(1, t.byteToLineIdx(53, LineType.LF_CR));
            eq(2, t.byteToLineIdx(54, LineType.LF_CR));
            eq(2, t.byteToLineIdx(57, LineType.LF_CR));

            eq(2, t.byteToLineIdx(78, LineType.LF_CR));
        }
    }

    public function test_byte_to_line_idx_02() {
        var r = Rope.fromStr(TEXT_LINES);
        for (t in makeTestData(r, TEXT_LINES, 50, 50)) {
            eq(0, t.byteToLineIdx(0, LineType.LF_CR));
        }
    }

    public function test_byte_to_line_idx_03() {
        var r = Rope.fromStr("Hi there\nstranger!");
        for (t in makeTestData(r, "Hi there\nstranger!", 0, 9)) {
            eq(0, t.byteToLineIdx(0, LineType.LF_CR));
            eq(0, t.byteToLineIdx(8, LineType.LF_CR));
            eq(1, t.byteToLineIdx(9, LineType.LF_CR));
        }
    }

    public function test_byte_to_line_idx_04a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT_LINES);
            var s = r.slice(34, 112);
            s.byteToLineIdx(79, LineType.LF_CR);
        });
    }

    public function test_byte_to_line_idx_04b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT_LINES, 34, 112));
            s.byteToLineIdx(79, LineType.LF_CR);
        });
    }

    public function test_char_to_byte_idx_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 88, 124)) {
            eq("?  こんにちは、みんなさん", t);

            eq(0, t.charToByteIdx(0));
            eq(1, t.charToByteIdx(1));
            eq(2, t.charToByteIdx(2));

            eq(3, t.charToByteIdx(3));
            eq(6, t.charToByteIdx(4));
            eq(33, t.charToByteIdx(13));
            eq(36, t.charToByteIdx(14));
        }
    }

    public function test_line_to_byte_idx_01() {
        var r = Rope.fromStr(TEXT_LINES);
        for (t in makeTestData(r, TEXT_LINES, 34, 112)) {
            eq(
                "'s a fine day, isn't it?\nAren't you glad we're alive?\nこんにちは、みん",
                t
            );

            eq(0, t.lineToByteIdx(0, LineType.LF_CR));
            eq(25, t.lineToByteIdx(1, LineType.LF_CR));
            eq(54, t.lineToByteIdx(2, LineType.LF_CR));
            eq(78, t.lineToByteIdx(3, LineType.LF_CR));
        }
    }

    public function test_line_to_byte_idx_02() {
        var r = Rope.fromStr(TEXT_LINES);
        for (t in makeTestData(r, TEXT_LINES, 43, 43)) {
            eq(0, t.lineToByteIdx(0, LineType.LF_CR));
            eq(0, t.lineToByteIdx(1, LineType.LF_CR));
        }
    }

    public function test_line_to_byte_idx_03a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT_LINES);
            var s = r.slice(34, 96);
    
            s.lineToByteIdx(4, LineType.LF_CR);
        });
    }

    public function test_line_to_byte_idx_03b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT_LINES, 34, 96));
            s.lineToByteIdx(4, LineType.LF_CR);
        });
    }

    public function test_line_to_byte_idx_04a() {
        panics(() -> {
            var r = Rope.fromStr("\n\n\n\n");
            var s = r.slice(1, 3);
    
            s.lineToByteIdx(4, LineType.LF_CR);
        });
    }

    public function test_line_to_byte_idx_04b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub("\n\n\n\n", 1, 3));
            s.lineToByteIdx(4, LineType.LF_CR);
        });
    }

    public function test_utf16_to_byte_idx_01() {
        var r = Rope.fromStr("");
        for (t in makeTestData(r, "")) {
            eq(0, t.utf16ToByteIdx(0));
        }
    }

    public function test_utf16_to_byte_idx_02a() {
        panics(() -> {
            var r = Rope.fromStr("");
            var s = r.sliceFrom(0);
            s.utf16ToByteIdx(1);
        });
    }

    public function test_utf16_to_byte_idx_02b() {
        panics(() -> {
            var s = RopeSlice.fromStr("");
            s.utf16ToByteIdx(1);
        });
    }

    public function test_utf16_to_byte_idx_03() {
        var r = Rope.fromStr("🐸");
        for (t in makeTestData(r, "🐸")) {
            eq(0, t.utf16ToByteIdx(0));
            eq(0, t.utf16ToByteIdx(1));
            eq(4, t.utf16ToByteIdx(2));
        }
    }

    public function test_utf16_to_byte_idx_04a() {
        panics(() -> {
            var r = Rope.fromStr("🐸");
            var s = r.sliceFrom(0);
            s.utf16ToByteIdx(3);
        });
    }

    public function test_utf16_to_byte_idx_04b() {
        panics(() -> {
            var s = RopeSlice.fromStr("🐸");
            s.utf16ToByteIdx(3);
        });
    }

    public function test_utf16_to_byte_idx_05() {
        var r = Rope.fromStr(TEXT_EMOJI);
        for (t in makeTestData(r, TEXT_EMOJI)) {
            eq(0, t.utf16ToByteIdx(0));

            eq(12, t.utf16ToByteIdx(12));
            eq(16, t.utf16ToByteIdx(14));

            eq(35, t.utf16ToByteIdx(33));
            eq(39, t.utf16ToByteIdx(35));

            eq(67, t.utf16ToByteIdx(63));
            eq(71, t.utf16ToByteIdx(65));

            eq(101, t.utf16ToByteIdx(95));
            eq(105, t.utf16ToByteIdx(97));

            eq(107, t.utf16ToByteIdx(99));
            eq(110, t.utf16ToByteIdx(100));

            eq(140, t.utf16ToByteIdx(110));
            eq(143, t.utf16ToByteIdx(111));
        }
    }

    public function test_utf16_to_byte_idx_06a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT_EMOJI);
            var s = r.sliceFrom(0);
            s.utf16ToByteIdx(112);
        });
    }

    public function test_utf16_to_byte_idx_06b() {
        panics(() -> {
            var s = RopeSlice.fromStr(TEXT_EMOJI);
            s.utf16ToByteIdx(112);
        });
    }

    public function test_utf16_to_byte_idx_07() {
        var r = Rope.fromStr(TEXT_EMOJI);
        for (t in makeTestData(r, TEXT_EMOJI, 1, 137)) {
            eq(0, t.utf16ToByteIdx(0));

            eq(11, t.utf16ToByteIdx(11));
            eq(15, t.utf16ToByteIdx(13));

            eq(34, t.utf16ToByteIdx(32));
            eq(38, t.utf16ToByteIdx(34));

            eq(66, t.utf16ToByteIdx(62));
            eq(70, t.utf16ToByteIdx(64));

            eq(100, t.utf16ToByteIdx(94));
            eq(104, t.utf16ToByteIdx(96));

            eq(106, t.utf16ToByteIdx(98));
            eq(109, t.utf16ToByteIdx(99));

            eq(133, t.utf16ToByteIdx(107));
            eq(136, t.utf16ToByteIdx(108));
        }
    }

    public function test_utf16_to_byte_idx_08a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT_EMOJI);
            var s = r.slice(1, 137);
            s.utf16ToByteIdx(109);
        });
    }

    public function test_utf16_to_byte_idx_08b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT_EMOJI, 1, 137));
            s.utf16ToByteIdx(109);
        });
    }

    public function test_byte_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 34, 118)) {
            eq(t.byte(0), "t".code);
            eq(t.byte(10), " ".code);

            // UTF-8 encoding of "な".code.
            eq(t.byte(t.len() - 3), 0xE3);
            eq(t.byte(t.len() - 2), 0x81);
            eq(t.byte(t.len() - 1), 0xAA);
        }
    }

    public function test_byte_02a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT);
            var s = r.slice(34, 118);
            s.byte(s.len());
        });
    }

    public function test_byte_02b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT, 34, 118));
            s.byte(s.len());
        });
    }

    public function test_byte_03a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT);
            var s = r.slice(42, 42);
            s.byte(0);
        });
    }

    public function test_byte_03b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT, 42, 42));
            s.byte(0);
        });
    }

    public function test_char_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 34, 118)) {
            // t's // a fine day, isn't it?  Aren't you glad // we're alive?  こんにちは、みんな

            eq(t.char(0), "t".code);
            eq(t.char(10), " ".code);
            eq(t.char(18), "n".code);
            eq(t.char(81), "な".code);
        }
    }

    public function test_char_02a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT);
            var s = r.slice(34, 118);
            s.char(s.len());
        });
    }

    public function test_char_02b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT, 34, 118));
            s.char(s.len());
        });
    }

    public function test_char_03a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT);
            var s = r.slice(43, 43);
            s.char(0);
        });
    }

    public function test_char_03b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT, 43, 43));
            s.char(0);
        });
    }

    public function test_line_01() {
        var r = Rope.fromStr(TEXT_LINES);
        for (t in makeTestData(r, TEXT_LINES, 34, 112)) {
            // "'s a fine day, isn't it?\nAren't you glad //  we're alive?\nこんにちは、みん"

            var l0 = t.line(0, LineType.LF_CR);
            eq(l0, "'s a fine day, isn't it?\n");
            eq(l0.len(), 25);
            eq(l0.lenLines(LineType.LF_CR), 2);

            var l1 = t.line(1, LineType.LF_CR);
            eq(l1, "Aren't you glad we're alive?\n");
            eq(l1.len(), 29);
            eq(l1.lenLines(LineType.LF_CR), 2);

            var l2 = t.line(2, LineType.LF_CR);
            eq(l2, "こんにちは、みん");
            eq(l2.len(), 24);
            eq(l2.lenLines(LineType.LF_CR), 1);
        }
    }

    public function test_line_02() {
        var r = Rope.fromStr(TEXT_LINES);
        for (t in makeTestData(r, TEXT_LINES, 34, 59)) {
            // "'s a fine day, isn't it?\n"

            eq(t.line(0, LineType.LF_CR), "'s a fine day, isn't it?\n");
            eq(t.line(1, LineType.LF_CR), "");
        }
    }

    public function test_line_03() {
        var r = Rope.fromStr("Hi\nHi\nHi\nHi\nHi\nHi\n");
        for (t in makeTestData(r, "Hi\nHi\nHi\nHi\nHi\nHi\n", 1, 17)) {
            eq(t.line(0, LineType.LF_CR), "i\n");
            eq(t.line(1, LineType.LF_CR), "Hi\n");
            eq(t.line(2, LineType.LF_CR), "Hi\n");
            eq(t.line(3, LineType.LF_CR), "Hi\n");
            eq(t.line(4, LineType.LF_CR), "Hi\n");
            eq(t.line(5, LineType.LF_CR), "Hi");
        }
    }

    public function test_line_04() {
        var r = Rope.fromStr(TEXT_LINES);
        for (t in makeTestData(r, TEXT_LINES, 43, 43)) {
            eq(t.line(0, LineType.LF_CR), "");
        }
    }

    public function test_line_05a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT_LINES);
            var s = r.slice(34, 96);
            s.line(3, LineType.LF_CR);
        });
    }

    public function test_line_05b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT_LINES, 34, 96));
            s.line(3, LineType.LF_CR);
        });
    }

    public function test_line_06() {
        var text = "1\n2\n3\n4\n5\n6\n7\n8";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text, 1, 11)) {
            // "\n2\n3\n4\n5\n6"

            eq(t.line(0, LineType.LF_CR).lenLines(LineType.LF_CR), 2);
            eq(t.line(1, LineType.LF_CR).lenLines(LineType.LF_CR), 2);
            eq(t.line(2, LineType.LF_CR).lenLines(LineType.LF_CR), 2);
            eq(t.line(3, LineType.LF_CR).lenLines(LineType.LF_CR), 2);
            eq(t.line(4, LineType.LF_CR).lenLines(LineType.LF_CR), 2);
            eq(t.line(5, LineType.LF_CR).lenLines(LineType.LF_CR), 1);
        }
    }

    public function test_trailing_line_break_idx_lf_01() {
        var text = "Hello\u{2029}\u{2028}\u{85}\u{0C}\u{0B}\r\r\n\n";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            eq((18), t.slice(0, 19).trailingLineBreakIdx(LineType.LF));
            eq((16), t.slice(0, 18).trailingLineBreakIdx(LineType.LF));
            eq(null, t.slice(0, 16).trailingLineBreakIdx(LineType.LF));
        }
    }

    public function test_trailing_line_break_idx_lf_cr_01() {
        var text = "Hello\u{2029}\u{2028}\u{85}\u{0C}\u{0B}\r\r\n\n";
        var r = Rope.fromStr(text);
        for (t in makeTestData(r, text)) {
            eq((18), t.slice(0, 19).trailingLineBreakIdx(LineType.LF_CR));
            eq((16), t.slice(0, 18).trailingLineBreakIdx(LineType.LF_CR));
            eq((15), t.slice(0, 16).trailingLineBreakIdx(LineType.LF_CR));
            eq(null, t.slice(0, 15).trailingLineBreakIdx(LineType.LF_CR));
        }
    }

    // Not ported: `trailing_line_break_idx_unicode_01` needs the metric_lines_unicode feature (not enabled in gpui-kit).

    function checkChunk(s:RopeSlice, text:String) {
        for (t in [s, RopeSlice.fromStr(text)]) {
            var currentByte = 0;
            var seenBytes = 0;
            var prevByte = 0;
            for (i in 0...t.len()) {
                var c = t.chunk(i);
                var chunk = c.text();
                var startByte = c.byteIdx;

                if (startByte != prevByte || i == 0) {
                    currentByte = seenBytes;
                    seenBytes += c.len();

                    prevByte = startByte;
                }

                eq(startByte, currentByte);
                eq(chunk, bsub(text, currentByte, seenBytes));
            }

            eq(seenBytes, blen(text));
        }
    }

    public function test_chunk_01() {
        var r = Rope.fromStr(TEXT_LINES);
        var s = r.slice(34, 112);
        var text = bsub(TEXT_LINES, 34, 112);
        // "'s a fine day, isn't it?\nAren't you glad //  we're alive?\nこんにちは、みん"

        checkChunk(s, text);
    }

    public function test_chunk_02() {
        // Make sure splitting LF_CR pairs works properly.

        var chunks = [
            "\r\n\r\n\r\n",
            "\r\n\r\n\r",
            "\n\r\n\r\n\r",
            "\n\r\n\r\n\r\n",
            "\r\n\r\n\r\n",
        ];
        var r = makeRopeFromChunks(chunks);
        var text = makeTextFromChunks(chunks);

        for (si in 0...r.len() + 1) {
            checkChunk(r.sliceFrom(si), bfrom(text, si));
        }
    }

    public function test_slice_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.sliceFrom(0);

            eq(TEXT, s);
        }
    }

    public function test_slice_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 50, 118)) {
            var s = t.slice(3, 25);

            eq(bsub(TEXT, 53, 75), s);
        }
    }

    public function test_slice_03() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 50, 118)) {
            var s = t.slice(7, 65);

            eq(bsub(TEXT, 57, 115), s);
        }
    }

    public function test_slice_04() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 50, 118)) {
            var s = t.slice(21, 21);

            eq("", s);
        }
    }

    public function test_slice_05a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT);
            var s = r.slice(50, 118);
    
            s.slice(21, 20); // Wrong ordering on purpose.
        });
    }

    public function test_slice_05b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT, 50, 118));
    
            s.slice(21, 20); // Wrong ordering on purpose.
        });
    }

    public function test_slice_06a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT);
            var s = r.slice(50, 85);
    
            s.slice(35, 36);
        });
    }

    public function test_slice_06b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT, 50, 85));
    
            s.slice(35, 36);
        });
    }

    public function test_slice_07a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT);
            var s = r.slice(50, 118);
    
            // Not a char boundary.
            s.slice(0, 43);
        });
    }

    public function test_slice_07b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT, 50, 118));
    
            // Not a char boundary.
            s.slice(0, 43);
        });
    }

    public function test_slice_08a() {
        panics(() -> {
            var r = Rope.fromStr(TEXT);
            var s = r.slice(50, 118);
    
            // Not a char boundary.
            s.sliceFrom(43);
        });
    }

    public function test_slice_08b() {
        panics(() -> {
            var s = RopeSlice.fromStr(bsub(TEXT, 50, 118));
    
            // Not a char boundary.
            s.sliceFrom(43);
        });
    }

    public function test_eq_str_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            eq(t, TEXT);
            eq(TEXT, t);
        }
    }

    public function test_eq_str_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 0, 20)) {
            ne(t, TEXT);
            ne(TEXT, t);
        }
    }

    public function test_eq_str_03() {
        var r = Rope.fromStr(TEXT);
        r.remove(20, 21);
        r.insert(20, "z");
        var slice = r.sliceFrom(0);

        ne(slice, TEXT);
        ne(TEXT, slice);
    }

    public function test_eq_string_01() {
        var r = Rope.fromStr(TEXT);
        var s:String = TEXT;
        for (t in makeTestData(r, TEXT)) {
            eq(t, s);
            eq(s, t);
        }
    }

    public function test_eq_rope_slice_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT, 43, 43)) {
            eq(t, t);
        }
    }

    public function test_eq_rope_slice_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s1 = t.slice(43, 97);
            var s2 = t.slice(43, 97);

            eq(s1, s2);
        }
    }

    public function test_eq_rope_slice_03() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s1 = t.slice(43, 43);
            var s2 = t.slice(43, 45);

            ne(s1, s2);
        }
    }

    public function test_eq_rope_slice_04() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s1 = t.slice(43, 45);
            var s2 = t.slice(43, 43);

            ne(s1, s2);
        }
    }

    public function test_eq_rope_slice_05() {
        var r = Rope.fromStr("");
        for (t in makeTestData(r, "")) {
            var s = t.slice(0, 0);

            eq(s, s);
        }
    }

    public function test_cmp_rope_slice_01() {
        var text = "abcdefghijklmnopqrstuvwxyz";
        var r1 = Rope.fromStr(text);
        var r2 = Rope.fromStr(text);

        var ab = makeTestData(r1, text);
        var cd = makeTestData(r2, text);
        var a = ab[0], b = ab[1], c = cd[0], d = cd[1];
        var pairs = [
            [a, b],
            [a, c],
            [a, d],
            [b, a],
            [b, c],
            [b, d],
            [c, a],
            [c, b],
            [c, d],
            [d, a],
            [d, b],
            [d, c],
        ];

        for (pair in pairs) {
            var s1 = pair[0].sliceFrom(0);
            var s2 = pair[1].sliceFrom(0);

            eq(s1.compare(s2), 0);
            eq(s1.slice(0, 24).compare(s2), -1);
            eq(s1.compare(s2.slice(0, 24)), 1);
        }
    }

    public function test_cmp_rope_slice_02() {
        var text1 = "abcdefghijklmnzpqrstuvwxyz";
        var text2 = "abcdefghijklmnopqrstuvwxyz";
        var r1 = Rope.fromStr(text1);
        var r2 = Rope.fromStr(text2);

        var a = makeTestData(r1, text1);
        var b = makeTestData(r2, text2);
        var pairs = [[a[0], b[0]], [a[1], b[1]], [a[0], b[1]], [a[1], b[0]]];

        for (pair in pairs) {
            var s1 = pair[0].sliceFrom(0);
            var s2 = pair[1].sliceFrom(0);

            eq(s1.compare(s2), 1);
            eq(s2.compare(s1), -1);
        }
    }

    public function test_to_string_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s:String = t.toString();

            eq(r, s);
            eq(t, s);
        }
    }

    public function test_to_string_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var slc = t.slice(0, 24);
            var s:String = slc.toString();

            eq(slc, s);
        }
    }

    public function test_to_string_03() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var slc = t.slice(13, 89);
            var s:String = slc.toString();

            eq(slc, s);
        }
    }

    public function test_to_string_04() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var slc = t.slice(13, 41);
            var s:String = slc.toString();

            eq(slc, s);
        }
    }

    // `to_cow_01` and `to_cow_02` check Rust's `Cow` borrowing: `asStr()` is
    // the closest Haxe equivalent (a string when the slice is in one chunk).
    public function test_to_cow_01() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(13, 83);
            var cow:String = s.toString();

            eq(s, cow);
        }
    }

    public function test_to_cow_02() {
        var r = Rope.fromStr(TEXT);
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(13, 14);
            var cow = t.slice(13, 14).asStr();

            if (!s.isStr()) {
                isTrue(s.root.isLeaf);
            }

            // Make sure it's borrowed.
            isTrue(cow != null);

            eq(s, cow);
        }
    }

    public function test_hash_01() {
        var r = Rope.fromStr("Hello there!");
        var expectedH = r.hash();

        for (t in makeTestData(r, "Hello there!")) {
            eq(expectedH, t.hash());
        }
    }

    public function test_hash_02() {
        var r = Rope.fromStr(TEXT);
        var expectedH = r.hash();
        for (t in makeTestData(r, TEXT)) {
            eq(expectedH, t.hash());
        }
    }

    public function test_hash_03() {
        var r = Rope.fromStr(TEXT);
        var expectedH = r.slice(12, 89).hash();
        for (t in makeTestData(r, TEXT)) {
            var s = t.slice(12, 89);

            eq(expectedH, s.hash());
        }
    }

}
