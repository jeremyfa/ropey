// Ported from str_indices 0.4.4: src/chars.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe (scalar code path only). See README.md.

package ropey.str_indices;

import haxe.io.Bytes;

/**
 * Index by chars (Unicode scalar values).
 *
 * Every function works on the UTF-8 text `text[start...end]`, and every index
 * is relative to `start`.
 */
class Chars {

    /**
     * Counts the chars in a string slice.
     *
     * Runs in O(N) time.
     */
    public static function count(text:Bytes, start:Int, end:Int):Int {
        return countImpl(text, start, end);
    }

    /**
     * Converts from byte-index to char-index in a string slice.
     *
     * If the byte is in the middle of a multi-byte char, returns the index of
     * the char that the byte belongs to.
     *
     * Any past-the-end index will return the one-past-the-end char index.
     *
     * Runs in O(N) time.
     */
    public static function fromByteIdx(text:Bytes, start:Int, end:Int, byteIdx:Int):Int {
        var len = end - start;
        var i = byteIdx;
        while (i < len && isTrailingByte(text.get(start + i))) {
            i--;
        }
        return countImpl(text, start, start + (i < len ? i : len));
    }

    /**
     * Converts from char-index to byte-index in a string slice.
     *
     * Any past-the-end index will return the one-past-the-end byte index.
     *
     * Runs in O(N) time.
     */
    public static function toByteIdx(text:Bytes, start:Int, end:Int, charIdx:Int):Int {
        var charCount = 0;
        var i = start;
        while (i < end) {
            if (isLeadingByte(text.get(i))) {
                charCount++;
                if (charCount > charIdx)
                    return i - start;
            }
            i++;
        }
        return end - start;
    }

    public static function countImpl(text:Bytes, start:Int, end:Int):Int {
        var count = 0;
        var i = start;
        while (i < end) {
            if ((text.get(i) & 0xC0) != 0x80)
                count++;
            i++;
        }
        return count;
    }

    static inline function isLeadingByte(byte:Int):Bool {
        return (byte & 0xC0) != 0x80;
    }

    static inline function isTrailingByte(byte:Int):Bool {
        return (byte & 0xC0) == 0x80;
    }

}
