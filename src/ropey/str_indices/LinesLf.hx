// Ported from str_indices 0.4.4: src/lines_lf.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe (scalar code path only). See README.md.

package ropey.str_indices;

import haxe.io.Bytes;

/**
 * Index by lines (line feed only).
 *
 * This module recognizes the following as line breaks:
 *
 * - `U+000A`: LF (Line Feed)
 * - `U+000D` `U+000A`: CRLF (Carriage Return + Line Feed), by coincidence
 *   due to ignoring CR.
 *
 * Every function works on the UTF-8 text `text[start...end]`, and every index
 * is relative to `start`.
 */
class LinesLf {

    /**
     * Counts the line breaks in a string slice.
     *
     * Runs in O(N) time.
     */
    public static function countBreaks(text:Bytes, start:Int, end:Int):Int {
        var count = 0;
        var i = start;
        while (i < end) {
            if (text.get(i) == 0x0A)
                count++;
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
        return countBreaks(text, start, start + i);
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
        var lfCount = 0;
        var i = start;
        while (i < end) {
            if (lfCount == lineIdx)
                break;
            if (text.get(i) == 0x0A)
                lfCount++;
            i++;
        }
        return i - start;
    }

}
