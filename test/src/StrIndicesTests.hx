// Ported from str_indices 0.4.4: src/chars.rs, src/utf16.rs, src/lines_lf.rs,
// src/lines_crlf.rs (tests)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

import TestUtil.*;
import ropey.str_indices.Chars as StrChars;
import ropey.str_indices.LinesCrlf as StrLinesCrlf;
import ropey.str_indices.LinesLf as StrLinesLf;
import ropey.str_indices.Utf16 as StrUtf16;

class StrIndicesTests {

    // 45 bytes, 27 utf16 code units.
    static inline final UTF16_TEXT = "Hel🐸lo world! こん🐸にち🐸🐸は!";

    public function new() {}

    static function charsCount(s:String):Int { var b = bytesOf(s); return StrChars.count(b, 0, b.length); }
    static function charsFromByteIdx(s:String, i:Int):Int { var b = bytesOf(s); return StrChars.fromByteIdx(b, 0, b.length, i); }
    static function charsToByteIdx(s:String, i:Int):Int { var b = bytesOf(s); return StrChars.toByteIdx(b, 0, b.length, i); }
    static function utf16Count(s:String):Int { var b = bytesOf(s); return StrUtf16.count(b, 0, b.length); }
    static function utf16CountSurrogates(s:String):Int { var b = bytesOf(s); return StrUtf16.countSurrogates(b, 0, b.length); }
    static function utf16FromByteIdx(s:String, i:Int):Int { var b = bytesOf(s); return StrUtf16.fromByteIdx(b, 0, b.length, i); }
    static function utf16ToByteIdx(s:String, i:Int):Int { var b = bytesOf(s); return StrUtf16.toByteIdx(b, 0, b.length, i); }
    static function linesLfCountBreaks(s:String):Int { var b = bytesOf(s); return StrLinesLf.countBreaks(b, 0, b.length); }
    static function linesLfFromByteIdx(s:String, i:Int):Int { var b = bytesOf(s); return StrLinesLf.fromByteIdx(b, 0, b.length, i); }
    static function linesLfToByteIdx(s:String, i:Int):Int { var b = bytesOf(s); return StrLinesLf.toByteIdx(b, 0, b.length, i); }
    static function linesCrlfCountBreaks(s:String):Int { var b = bytesOf(s); return StrLinesCrlf.countBreaks(b, 0, b.length); }
    static function linesCrlfFromByteIdx(s:String, i:Int):Int { var b = bytesOf(s); return StrLinesCrlf.fromByteIdx(b, 0, b.length, i); }
    static function linesCrlfToByteIdx(s:String, i:Int):Int { var b = bytesOf(s); return StrLinesCrlf.toByteIdx(b, 0, b.length, i); }

    //=========================================================
    // chars.rs

    public function test_chars_count_01() {
        var text = "Hello せかい! Hello せかい! Hello せかい! Hello せかい! Hello せかい!";

        eq(54, charsCount(text));
    }

    public function test_chars_count_02() {
        eq(100, charsCount(TEXT_LINES));
    }

    public function test_chars_from_byte_idx_01() {
        var text = "Hello せかい!";
        eq(0, charsFromByteIdx(text, 0));
        eq(1, charsFromByteIdx(text, 1));
        eq(6, charsFromByteIdx(text, 6));
        eq(6, charsFromByteIdx(text, 7));
        eq(6, charsFromByteIdx(text, 8));
        eq(7, charsFromByteIdx(text, 9));
        eq(7, charsFromByteIdx(text, 10));
        eq(7, charsFromByteIdx(text, 11));
        eq(8, charsFromByteIdx(text, 12));
        eq(8, charsFromByteIdx(text, 13));
        eq(8, charsFromByteIdx(text, 14));
        eq(9, charsFromByteIdx(text, 15));
        eq(10, charsFromByteIdx(text, 16));
        eq(10, charsFromByteIdx(text, 17));
        eq(10, charsFromByteIdx(text, 18));
        eq(10, charsFromByteIdx(text, 19));
    }

    public function test_chars_from_byte_idx_02() {
        var text = "";
        eq(0, charsFromByteIdx(text, 0));
        eq(0, charsFromByteIdx(text, 1));

        var text = "h";
        eq(0, charsFromByteIdx(text, 0));
        eq(1, charsFromByteIdx(text, 1));
        eq(1, charsFromByteIdx(text, 2));

        var text = "hi";
        eq(0, charsFromByteIdx(text, 0));
        eq(1, charsFromByteIdx(text, 1));
        eq(2, charsFromByteIdx(text, 2));
        eq(2, charsFromByteIdx(text, 3));
    }

    public function test_chars_from_byte_idx_03() {
        var text = "せかい";
        eq(0, charsFromByteIdx(text, 0));
        eq(0, charsFromByteIdx(text, 1));
        eq(0, charsFromByteIdx(text, 2));
        eq(1, charsFromByteIdx(text, 3));
        eq(1, charsFromByteIdx(text, 4));
        eq(1, charsFromByteIdx(text, 5));
        eq(2, charsFromByteIdx(text, 6));
        eq(2, charsFromByteIdx(text, 7));
        eq(2, charsFromByteIdx(text, 8));
        eq(3, charsFromByteIdx(text, 9));
        eq(3, charsFromByteIdx(text, 10));
        eq(3, charsFromByteIdx(text, 11));
        eq(3, charsFromByteIdx(text, 12));
    }

    public function test_chars_from_byte_idx_04() {
        // Ascii range
        for (i in 0...88) {
            eq(i, charsFromByteIdx(TEXT_LINES, i));
        }

        // Hiragana characters
        for (i in 88...125) {
            eq(88 + Std.int((i - 88) / 3), charsFromByteIdx(TEXT_LINES, i));
        }

        // Past the end
        for (i in 125...130) {
            eq(100, charsFromByteIdx(TEXT_LINES, i));
        }
    }

    public function test_chars_to_byte_idx_01() {
        var text = "Hello せかい!";
        eq(0, charsToByteIdx(text, 0));
        eq(1, charsToByteIdx(text, 1));
        eq(2, charsToByteIdx(text, 2));
        eq(5, charsToByteIdx(text, 5));
        eq(6, charsToByteIdx(text, 6));
        eq(12, charsToByteIdx(text, 8));
        eq(15, charsToByteIdx(text, 9));
        eq(16, charsToByteIdx(text, 10));
    }

    public function test_chars_to_byte_idx_02() {
        var text = "せかい";
        eq(0, charsToByteIdx(text, 0));
        eq(3, charsToByteIdx(text, 1));
        eq(6, charsToByteIdx(text, 2));
        eq(9, charsToByteIdx(text, 3));
    }

    public function test_chars_to_byte_idx_03() {
        var text = "Hello world!";
        eq(0, charsToByteIdx(text, 0));
        eq(1, charsToByteIdx(text, 1));
        eq(8, charsToByteIdx(text, 8));
        eq(11, charsToByteIdx(text, 11));
        eq(12, charsToByteIdx(text, 12));
    }

    public function test_chars_to_byte_idx_04() {
        var text = "Hello world! Hello せかい! Hello world! Hello せかい! Hello world! Hello せかい! Hello world! Hello せかい! Hello world! Hello せかい! Hello world! Hello せかい! Hello world! Hello せかい! Hello world! Hello せかい!";
        eq(0, charsToByteIdx(text, 0));
        eq(30, charsToByteIdx(text, 24));
        eq(60, charsToByteIdx(text, 48));
        eq(90, charsToByteIdx(text, 72));
        eq(115, charsToByteIdx(text, 93));
        eq(120, charsToByteIdx(text, 96));
        eq(150, charsToByteIdx(text, 120));
        eq(180, charsToByteIdx(text, 144));
        eq(210, charsToByteIdx(text, 168));
        eq(239, charsToByteIdx(text, 191));
    }

    public function test_chars_to_byte_idx_05() {
        // Ascii range
        for (i in 0...88) {
            eq(i, charsToByteIdx(TEXT_LINES, i));
        }

        // Hiragana characters
        for (i in 88...100) {
            eq(88 + ((i - 88) * 3), charsToByteIdx(TEXT_LINES, i));
        }

        // Past the end
        for (i in 100...110) {
            eq(124, charsToByteIdx(TEXT_LINES, i));
        }
    }

    //=========================================================
    // utf16.rs

    public function test_utf16_count_01() {
        eq(27, utf16Count(UTF16_TEXT));
    }

    public function test_utf16_count_surrogates_01() {
        eq(4, utf16CountSurrogates(UTF16_TEXT));
    }

    public function test_utf16_from_byte_idx_01() {
        eq(0, utf16FromByteIdx(UTF16_TEXT, 0));

        eq(3, utf16FromByteIdx(UTF16_TEXT, 3));
        eq(3, utf16FromByteIdx(UTF16_TEXT, 4));
        eq(3, utf16FromByteIdx(UTF16_TEXT, 5));
        eq(3, utf16FromByteIdx(UTF16_TEXT, 6));
        eq(5, utf16FromByteIdx(UTF16_TEXT, 7));

        eq(7, utf16FromByteIdx(UTF16_TEXT, 9));

        eq(17, utf16FromByteIdx(UTF16_TEXT, 23));
        eq(17, utf16FromByteIdx(UTF16_TEXT, 24));
        eq(17, utf16FromByteIdx(UTF16_TEXT, 25));
        eq(17, utf16FromByteIdx(UTF16_TEXT, 26));
        eq(19, utf16FromByteIdx(UTF16_TEXT, 27));

        eq(21, utf16FromByteIdx(UTF16_TEXT, 33));
        eq(21, utf16FromByteIdx(UTF16_TEXT, 34));
        eq(21, utf16FromByteIdx(UTF16_TEXT, 35));
        eq(21, utf16FromByteIdx(UTF16_TEXT, 36));
        eq(23, utf16FromByteIdx(UTF16_TEXT, 37));
        eq(23, utf16FromByteIdx(UTF16_TEXT, 38));
        eq(23, utf16FromByteIdx(UTF16_TEXT, 39));
        eq(23, utf16FromByteIdx(UTF16_TEXT, 40));
        eq(25, utf16FromByteIdx(UTF16_TEXT, 41));

        eq(27, utf16FromByteIdx(UTF16_TEXT, 45));
        eq(27, utf16FromByteIdx(UTF16_TEXT, 46)); // Index 1 past the end.
    }

    public function test_utf16_to_byte_idx_01() {
        eq(utf16ToByteIdx(UTF16_TEXT, 0), 0);

        eq(3, utf16ToByteIdx(UTF16_TEXT, 3));
        eq(3, utf16ToByteIdx(UTF16_TEXT, 4));
        eq(7, utf16ToByteIdx(UTF16_TEXT, 5));

        eq(9, utf16ToByteIdx(UTF16_TEXT, 7));

        eq(23, utf16ToByteIdx(UTF16_TEXT, 17));
        eq(23, utf16ToByteIdx(UTF16_TEXT, 18));
        eq(27, utf16ToByteIdx(UTF16_TEXT, 19));

        eq(33, utf16ToByteIdx(UTF16_TEXT, 21));
        eq(33, utf16ToByteIdx(UTF16_TEXT, 22));
        eq(37, utf16ToByteIdx(UTF16_TEXT, 23));
        eq(37, utf16ToByteIdx(UTF16_TEXT, 24));
        eq(41, utf16ToByteIdx(UTF16_TEXT, 25));

        eq(45, utf16ToByteIdx(UTF16_TEXT, 27));
        eq(45, utf16ToByteIdx(UTF16_TEXT, 27)); // Index 1 past the end.
    }

    //=========================================================
    // lines_lf.rs

    public function test_lines_lf_count_breaks_01() {
        var text = "\nHello\u{000D}\nせ\u{000B}か\u{000C}い\u{0085}. There\nis something.\u{2029}";
        eq(45, blen(text));
        eq(3, linesLfCountBreaks(text));
    }

    public function test_lines_lf_from_byte_idx_01() {
        var text = "Here\nare\nsome\nwords";
        eq(0, linesLfFromByteIdx(text, 0));
        eq(0, linesLfFromByteIdx(text, 4));
        eq(1, linesLfFromByteIdx(text, 5));
        eq(1, linesLfFromByteIdx(text, 8));
        eq(2, linesLfFromByteIdx(text, 9));
        eq(2, linesLfFromByteIdx(text, 13));
        eq(3, linesLfFromByteIdx(text, 14));
        eq(3, linesLfFromByteIdx(text, 19));
    }

    public function test_lines_lf_from_byte_idx_02() {
        var text = "\nHere\nare\nsome\nwords\n";
        eq(0, linesLfFromByteIdx(text, 0));
        eq(1, linesLfFromByteIdx(text, 1));
        eq(1, linesLfFromByteIdx(text, 5));
        eq(2, linesLfFromByteIdx(text, 6));
        eq(2, linesLfFromByteIdx(text, 9));
        eq(3, linesLfFromByteIdx(text, 10));
        eq(3, linesLfFromByteIdx(text, 14));
        eq(4, linesLfFromByteIdx(text, 15));
        eq(4, linesLfFromByteIdx(text, 20));
        eq(5, linesLfFromByteIdx(text, 21));
    }

    public function test_lines_lf_from_byte_idx_03() {
        var text = "Here\r\nare\r\nsome\r\nwords";
        eq(0, linesLfFromByteIdx(text, 0));
        eq(0, linesLfFromByteIdx(text, 4));
        eq(0, linesLfFromByteIdx(text, 5));
        eq(1, linesLfFromByteIdx(text, 6));
        eq(1, linesLfFromByteIdx(text, 9));
        eq(1, linesLfFromByteIdx(text, 10));
        eq(2, linesLfFromByteIdx(text, 11));
        eq(2, linesLfFromByteIdx(text, 15));
        eq(2, linesLfFromByteIdx(text, 16));
        eq(3, linesLfFromByteIdx(text, 17));
    }

    public function test_lines_lf_from_byte_idx_04() {
        // Line 0
        for (i in 0...32) {
            eq(0, linesLfFromByteIdx(TEXT_LINES, i));
        }

        // Line 1
        for (i in 32...59) {
            eq(1, linesLfFromByteIdx(TEXT_LINES, i));
        }

        // Line 2
        for (i in 59...88) {
            eq(2, linesLfFromByteIdx(TEXT_LINES, i));
        }

        // Line 3
        for (i in 88...125) {
            eq(3, linesLfFromByteIdx(TEXT_LINES, i));
        }

        // Past the end
        for (i in 125...130) {
            eq(3, linesLfFromByteIdx(TEXT_LINES, i));
        }
    }

    public function test_lines_lf_to_byte_idx_01() {
        var text = "Here\r\nare\r\nsome\r\nwords";
        eq(0, linesLfToByteIdx(text, 0));
        eq(6, linesLfToByteIdx(text, 1));
        eq(11, linesLfToByteIdx(text, 2));
        eq(17, linesLfToByteIdx(text, 3));
    }

    public function test_lines_lf_to_byte_idx_02() {
        var text = "\nHere\nare\nsome\nwords\n";
        eq(0, linesLfToByteIdx(text, 0));
        eq(1, linesLfToByteIdx(text, 1));
        eq(6, linesLfToByteIdx(text, 2));
        eq(10, linesLfToByteIdx(text, 3));
        eq(15, linesLfToByteIdx(text, 4));
        eq(21, linesLfToByteIdx(text, 5));
    }

    public function test_lines_lf_to_byte_idx_03() {
        eq(0, linesLfToByteIdx(TEXT_LINES, 0));
        eq(32, linesLfToByteIdx(TEXT_LINES, 1));
        eq(59, linesLfToByteIdx(TEXT_LINES, 2));
        eq(88, linesLfToByteIdx(TEXT_LINES, 3));

        // Past end
        eq(124, linesLfToByteIdx(TEXT_LINES, 4));
        eq(124, linesLfToByteIdx(TEXT_LINES, 5));
        eq(124, linesLfToByteIdx(TEXT_LINES, 6));
    }

    public function test_lines_lf_line_byte_round_trip() {
        var text = "\nHere\nare\nsome\nwords\n";
        eq(6, linesLfToByteIdx(text, linesLfFromByteIdx(text, 6)));
        eq(2, linesLfFromByteIdx(text, linesLfToByteIdx(text, 2)));

        eq(0, linesLfToByteIdx(text, linesLfFromByteIdx(text, 0)));
        eq(0, linesLfFromByteIdx(text, linesLfToByteIdx(text, 0)));

        eq(21, linesLfToByteIdx(text, linesLfFromByteIdx(text, 21)));
        eq(5, linesLfFromByteIdx(text, linesLfToByteIdx(text, 5)));
    }

    //=========================================================
    // lines_crlf.rs

    public function test_lines_crlf_count_breaks_01() {
        var text = "\u{000A}Hello\u{000D}\u{000A}せ\u{000B}か\u{000C}い\u{0085}. There\u{000A}is something.\u{2029}";
        eq(45, blen(text));
        eq(3, linesCrlfCountBreaks(text));
    }

    public function test_lines_crlf_from_byte_idx_01() {
        var text = "Here\nare\nsome\nwords";
        eq(0, linesCrlfFromByteIdx(text, 0));
        eq(0, linesCrlfFromByteIdx(text, 4));
        eq(1, linesCrlfFromByteIdx(text, 5));
        eq(1, linesCrlfFromByteIdx(text, 8));
        eq(2, linesCrlfFromByteIdx(text, 9));
        eq(2, linesCrlfFromByteIdx(text, 13));
        eq(3, linesCrlfFromByteIdx(text, 14));
        eq(3, linesCrlfFromByteIdx(text, 19));
    }

    public function test_lines_crlf_from_byte_idx_02() {
        var text = "\nHere\nare\nsome\nwords\n";
        eq(0, linesCrlfFromByteIdx(text, 0));
        eq(1, linesCrlfFromByteIdx(text, 1));
        eq(1, linesCrlfFromByteIdx(text, 5));
        eq(2, linesCrlfFromByteIdx(text, 6));
        eq(2, linesCrlfFromByteIdx(text, 9));
        eq(3, linesCrlfFromByteIdx(text, 10));
        eq(3, linesCrlfFromByteIdx(text, 14));
        eq(4, linesCrlfFromByteIdx(text, 15));
        eq(4, linesCrlfFromByteIdx(text, 20));
        eq(5, linesCrlfFromByteIdx(text, 21));
    }

    public function test_lines_crlf_from_byte_idx_03() {
        var text = "Here\r\nare\r\nsome\r\nwords";
        eq(0, linesCrlfFromByteIdx(text, 0));
        eq(0, linesCrlfFromByteIdx(text, 4));
        eq(0, linesCrlfFromByteIdx(text, 5));
        eq(1, linesCrlfFromByteIdx(text, 6));
        eq(1, linesCrlfFromByteIdx(text, 9));
        eq(1, linesCrlfFromByteIdx(text, 10));
        eq(2, linesCrlfFromByteIdx(text, 11));
        eq(2, linesCrlfFromByteIdx(text, 15));
        eq(2, linesCrlfFromByteIdx(text, 16));
        eq(3, linesCrlfFromByteIdx(text, 17));
    }

    public function test_lines_crlf_from_byte_idx_04() {
        // Line 0
        for (i in 0...32) {
            eq(0, linesCrlfFromByteIdx(TEXT_LINES, i));
        }

        // Line 1
        for (i in 32...59) {
            eq(1, linesCrlfFromByteIdx(TEXT_LINES, i));
        }

        // Line 2
        for (i in 59...88) {
            eq(2, linesCrlfFromByteIdx(TEXT_LINES, i));
        }

        // Line 3
        for (i in 88...125) {
            eq(3, linesCrlfFromByteIdx(TEXT_LINES, i));
        }

        // Past the end
        for (i in 125...130) {
            eq(3, linesCrlfFromByteIdx(TEXT_LINES, i));
        }
    }

    public function test_lines_crlf_to_byte_idx_01() {
        var text = "Here\r\nare\r\nsome\r\nwords";
        eq(0, linesCrlfToByteIdx(text, 0));
        eq(6, linesCrlfToByteIdx(text, 1));
        eq(11, linesCrlfToByteIdx(text, 2));
        eq(17, linesCrlfToByteIdx(text, 3));
    }

    public function test_lines_crlf_to_byte_idx_02() {
        var text = "\nHere\nare\nsome\nwords\n";
        eq(0, linesCrlfToByteIdx(text, 0));
        eq(1, linesCrlfToByteIdx(text, 1));
        eq(6, linesCrlfToByteIdx(text, 2));
        eq(10, linesCrlfToByteIdx(text, 3));
        eq(15, linesCrlfToByteIdx(text, 4));
        eq(21, linesCrlfToByteIdx(text, 5));
    }

    public function test_lines_crlf_to_byte_idx_03() {
        eq(0, linesCrlfToByteIdx(TEXT_LINES, 0));
        eq(32, linesCrlfToByteIdx(TEXT_LINES, 1));
        eq(59, linesCrlfToByteIdx(TEXT_LINES, 2));
        eq(88, linesCrlfToByteIdx(TEXT_LINES, 3));

        // Past end
        eq(124, linesCrlfToByteIdx(TEXT_LINES, 4));
        eq(124, linesCrlfToByteIdx(TEXT_LINES, 5));
        eq(124, linesCrlfToByteIdx(TEXT_LINES, 6));
    }

    public function test_lines_crlf_line_byte_round_trip() {
        var text = "\nHere\nare\nsome\nwords\n";
        eq(6, linesCrlfToByteIdx(text, linesCrlfFromByteIdx(text, 6)));
        eq(2, linesCrlfFromByteIdx(text, linesCrlfToByteIdx(text, 2)));

        eq(0, linesCrlfToByteIdx(text, linesCrlfFromByteIdx(text, 0)));
        eq(0, linesCrlfFromByteIdx(text, linesCrlfToByteIdx(text, 0)));

        eq(21, linesCrlfToByteIdx(text, linesCrlfFromByteIdx(text, 21)));
        eq(5, linesCrlfFromByteIdx(text, linesCrlfToByteIdx(text, 5)));
    }

}
