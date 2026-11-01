// Original code, part of the Haxe port of ropey.
// Copyright (c) 2026 Jeremy Faivre, licensed under MIT OR Apache-2.0 like ropey. See README.md.

package ropey;

import haxe.io.Bytes;

/**
 * UTF-8 helpers used at the boundary between Haxe strings (UTF-16 on JS,
 * UTF-8 or UTF-16 on hxcpp) and ropey's UTF-8 storage.
 */
class Utf8 {

    /**
     * Encodes a Haxe string to UTF-8 bytes.
     */
    public static inline function encode(s:String):Bytes {
        return Bytes.ofString(s, UTF8);
    }

    /**
     * Decodes the UTF-8 text `bytes[start...end]` to a Haxe string.
     */
    public static inline function decode(bytes:Bytes, start:Int, end:Int):String {
        return end > start ? bytes.getString(start, end - start, UTF8) : '';
    }

    /**
     * Number of UTF-8 bytes of the given Haxe string.
     */
    public static function byteLength(s:String):Int {
        #if js
        var n = 0;
        var i = 0;
        var len = s.length;
        while (i < len) {
            var c:Int = StringTools.fastCodeAt(s, i++);
            if (c < 0x80) {
                n += 1;
            }
            else if (c < 0x800) {
                n += 2;
            }
            else if (c >= 0xD800 && c <= 0xDBFF && i < len) {
                var d:Int = StringTools.fastCodeAt(s, i);
                if (d >= 0xDC00 && d <= 0xDFFF) {
                    i++;
                    n += 4;
                }
                else {
                    n += 3;
                }
            }
            else {
                n += 3;
            }
        }
        return n;
        #else
        return Bytes.ofString(s, UTF8).length;
        #end
    }

    /**
     * Number of bytes of the UTF-8 sequence starting with `lead`.
     */
    public static inline function seqLen(lead:Int):Int {
        return lead < 0x80 ? 1 : lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : 4;
    }

    /**
     * Decodes the code point whose UTF-8 sequence starts at `pos`.
     */
    public static inline function codePointAt(bytes:Bytes, pos:Int):Int {
        var b0 = bytes.get(pos);
        return if (b0 < 0x80) {
            b0;
        }
        else if (b0 < 0xE0) {
            ((b0 & 0x1F) << 6) | (bytes.get(pos + 1) & 0x3F);
        }
        else if (b0 < 0xF0) {
            ((b0 & 0x0F) << 12) | ((bytes.get(pos + 1) & 0x3F) << 6) | (bytes.get(pos + 2) & 0x3F);
        }
        else {
            ((b0 & 0x07) << 18) | ((bytes.get(pos + 1) & 0x3F) << 12) | ((bytes.get(pos + 2) & 0x3F) << 6) | (bytes.get(pos + 3) & 0x3F);
        }
    }

    /**
     * Number of UTF-8 bytes needed to encode the code point `c`.
     */
    public static inline function lenUtf8(c:Int):Int {
        return c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4;
    }

    /**
     * Encodes the code point `c` in UTF-8 bytes.
     */
    public static function encodeChar(c:Int):Bytes {
        var out = Bytes.alloc(lenUtf8(c));
        if (c < 0x80) {
            out.set(0, c);
        }
        else if (c < 0x800) {
            out.set(0, 0xC0 | (c >> 6));
            out.set(1, 0x80 | (c & 0x3F));
        }
        else if (c < 0x10000) {
            out.set(0, 0xE0 | (c >> 12));
            out.set(1, 0x80 | ((c >> 6) & 0x3F));
            out.set(2, 0x80 | (c & 0x3F));
        }
        else {
            out.set(0, 0xF0 | (c >> 18));
            out.set(1, 0x80 | ((c >> 12) & 0x3F));
            out.set(2, 0x80 | ((c >> 6) & 0x3F));
            out.set(3, 0x80 | (c & 0x3F));
        }
        return out;
    }

}
