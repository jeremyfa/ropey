// Ported from str_indices 0.4.4: src/utf16.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe (scalar code path only). See README.md.

package ropey.str_indices;

import haxe.io.Bytes;

/**
 * Index by UTF-16 code units.
 *
 * Every function works on the UTF-8 text `text[start...end]`, and every index
 * is relative to `start`.
 */
class Utf16 {

    /**
     * Counts the UTF-16 code units that would be in a string slice if it were
     * encoded as UTF-16.
     *
     * Runs in O(N) time.
     */
    public static function count(text:Bytes, start:Int, end:Int):Int {
        return Chars.countImpl(text, start, end) + countSurrogatesImpl(text, start, end);
    }

    /**
     * Counts the UTF-16 surrogate pairs that would be in a string slice if it
     * were encoded as UTF-16.
     *
     * Runs in O(N) time.
     */
    public static function countSurrogates(text:Bytes, start:Int, end:Int):Int {
        return countSurrogatesImpl(text, start, end);
    }

    /**
     * Converts from byte-index to UTF-16-code-unit-index in a string slice.
     *
     * If the byte is in the middle of a multi-byte char, returns the UTF-16
     * index of the char that the byte belongs to.
     *
     * Any past-the-end index will return the one-past-the-end UTF-16 index.
     *
     * Runs in O(N) time.
     */
    public static function fromByteIdx(text:Bytes, start:Int, end:Int, byteIdx:Int):Int {
        var len = end - start;
        var i = byteIdx < len ? byteIdx : len;
        while (i < len && (text.get(start + i) & 0xC0) == 0x80) {
            i--;
        }
        return Chars.countImpl(text, start, start + i) + countSurrogatesImpl(text, start, start + i);
    }

    /**
     * Converts from UTF-16-code-unit-index to byte-index in a string slice.
     *
     * If the UTF-16 index is in the middle of a char, returns the byte index
     * of the char that UTF-16 code unit belongs to.
     *
     * Any past-the-end index will return the one-past-the-end byte index.
     *
     * Runs in O(N) time.
     */
    public static function toByteIdx(text:Bytes, start:Int, end:Int, utf16Idx:Int):Int {
        var utf16Count = 0;
        var i = start;
        while (i < end) {
            var byte = text.get(i);
            utf16Count += ((byte & 0xC0) != 0x80 ? 1 : 0) + ((byte & 0xF0) == 0xF0 ? 1 : 0);
            if (utf16Count > utf16Idx)
                break;
            i++;
        }
        return i - start;
    }

    static function countSurrogatesImpl(text:Bytes, start:Int, end:Int):Int {
        // We chop off the last three bytes, because all surrogate pairs are
        // four bytes in utf8, and so it prevents counting partial
        // characters.
        if (end - start <= 3)
            return 0;
        var stop = end - 3;
        var count = 0;
        var i = start;
        while (i < stop) {
            if ((text.get(i) & 0xF0) == 0xF0)
                count++;
            i++;
        }
        return count;
    }

}
