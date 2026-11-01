// Ported from str_indices 0.4.4: src/lines_crlf.rs and src/lib.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe (scalar code path only). See README.md.

package ropey.str_indices;

import haxe.io.Bytes;

/**
 * Index by lines (carriage return and line feed).
 *
 * This module recognizes the following as line breaks:
 *
 * - `U+000A`: LF (Line Feed)
 * - `U+000D`: CR (Carriage Return)
 * - `U+000D` `U+000A`: CRLF (Carriage Return + Line Feed)
 *
 * (Note: if you only want to recognize LF and CRLF, without recognizing CR
 * individually, see the `LinesLf` module.)
 *
 * Every function works on the UTF-8 text `text[start...end]`, and every index
 * is relative to `start`.
 */
class LinesCrlf {

    static inline final LF = 0x0A;
    static inline final CR = 0x0D;

    /**
     * Counts the line breaks in a string slice.
     *
     * Runs in O(N) time.
     */
    public static function countBreaks(text:Bytes, start:Int, end:Int):Int {
        var count = 0;
        var lastWasCr = false;
        var i = start;
        while (i < end) {
            var byte = text.get(i);
            var isLf = byte == LF;
            var isCr = byte == CR;
            if (isCr || (isLf && !lastWasCr))
                count++;
            lastWasCr = isCr;
            i++;
        }
        return count;
    }

    /**
     * Converts from byte-index to line-index in a string slice.
     *
     * Line break characters are considered to be a part of the line they
     * end.  And a string that ends with a line break is considered to have an
     * additional empty line at the end.
     *
     * Any past-the-end index will return the last line index.
     *
     * Runs in O(N) time.
     */
    public static function fromByteIdx(text:Bytes, start:Int, end:Int, byteIdx:Int):Int {
        var len = end - start;
        var i = byteIdx < len ? byteIdx : len;
        var nlCount = countBreaks(text, start, start + i);
        if (isNotCrlfMiddle(i, text, start, end)) {
            return nlCount;
        }
        else {
            return nlCount - 1;
        }
    }

    /**
     * Converts from line-index to byte-index in a string slice.
     *
     * Returns the byte index of the start of the specified line.  Line 0 is
     * the start of the string, and subsequent lines start immediately
     * *after* each line break character.
     *
     * Any past-the-end index will return the one-past-the-end byte index.
     *
     * Runs in O(N) time.
     */
    public static function toByteIdx(text:Bytes, start:Int, end:Int, lineIdx:Int):Int {
        var byteCount = 0;
        var breakCount = 0;
        var lastWasCr = false;
        var i = start;
        while (i < end) {
            var byte = text.get(i);
            var isLf = byte == LF;
            var isCr = byte == CR;
            if (breakCount == lineIdx) {
                if (lastWasCr && isLf) {
                    byteCount++;
                }
                return byteCount;
            }
            if (isCr || (isLf && !lastWasCr)) {
                breakCount++;
            }
            lastWasCr = isCr;
            byteCount++;
            i++;
        }
        return byteCount;
    }

    /**
     * Returns whether the given byte index is not in the middle of a CRLF
     * pair (from str_indices' lib.rs).
     */
    static inline function isNotCrlfMiddle(byteIdx:Int, text:Bytes, start:Int, end:Int):Bool {
        return byteIdx == 0
            || byteIdx >= end - start
            || (text.get(start + byteIdx - 1) != 0x0D)
            || (text.get(start + byteIdx) != 0x0A);
    }

}
