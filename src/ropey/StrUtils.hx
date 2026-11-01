// Ported from ropey 2.0.0-beta.1: src/str_utils.rs and the utilities of src/lib.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

import haxe.io.Bytes;
import ropey.str_indices.LinesCrlf;
import ropey.str_indices.LinesLf;

/**
 * Helpers working on UTF-8 text slices, given as `text[start...end]`.
 * Every index is relative to `start`.
 */
class StrUtils {

    //=============================================================
    // From lib.rs.

    public static inline function isCharBoundary(byteIdx:Int, text:Bytes, start:Int, end:Int):Bool {
        // Trick from rust stdlib.  Equivalent to:
        // `text[byte_idx] < 128 || text[byte_idx] >= 192`
        return byteIdx == end - start || isCharBoundaryByte(text.get(start + byteIdx));
    }

    public static inline function isCharBoundaryByte(byte:Int):Bool {
        return byte < 128 || byte >= 192;
    }

    /**
     * Returns the closest byte index <= `byteIdx` that is a char boundary.
     *
     * Note for convenience, if `byteIdx > len`, this simply returns `len`.
     */
    public static function floorCharBoundary(byteIdx:Int, text:Bytes, start:Int, end:Int):Int {
        var len = end - start;
        if (byteIdx >= len)
            return len;
        while (byteIdx > 0 && byteIdx < len && !isCharBoundaryByte(text.get(start + byteIdx))) {
            byteIdx--;
        }
        return byteIdx;
    }

    /**
     * Returns the closest byte index >= `byteIdx` that is a char boundary.
     *
     * Note for convenience, if `byteIdx > len`, this simply returns `len`.
     */
    public static function ceilCharBoundary(byteIdx:Int, text:Bytes, start:Int, end:Int):Int {
        var len = end - start;
        if (byteIdx >= len)
            return len;
        while (byteIdx < len && !isCharBoundaryByte(text.get(start + byteIdx))) {
            byteIdx++;
        }
        return byteIdx;
    }

    /**
     * Returns the closest byte index <= `byteIdx` that is a char boundary and
     * doesn't split a CRLF pair.
     *
     * Mainly used for finding an appropriate place to split text.
     */
    public static function findAppropriateSplitFloor(byteIdx:Int, text:Bytes, start:Int, end:Int):Int {
        byteIdx = floorCharBoundary(byteIdx, text, start, end);
        if (byteIdx > 0
            && byteIdx < end - start
            && byteIsLf(text, start, end, byteIdx)
            && byteIsCr(text, start, end, byteIdx - 1)) {
            byteIdx--;
        }
        return byteIdx;
    }

    /**
     * Returns the closest byte index >= `byteIdx` that is a char boundary and
     * doesn't split a CRLF pair.
     *
     * Mainly used for finding an appropriate place to split text.
     */
    public static function findAppropriateSplitCeil(byteIdx:Int, text:Bytes, start:Int, end:Int):Int {
        byteIdx = ceilCharBoundary(byteIdx, text, start, end);
        if (byteIdx > 0
            && byteIdx < end - start
            && byteIsLf(text, start, end, byteIdx)
            && byteIsCr(text, start, end, byteIdx - 1)) {
            byteIdx++;
        }
        return byteIdx;
    }

    //=============================================================
    // From str_utils.rs.

    public static inline function startsWithLf(text:Bytes, start:Int, end:Int):Bool {
        return end > start && text.get(start) == 0x0A;
    }

    public static inline function endsWithCr(text:Bytes, start:Int, end:Int):Bool {
        return end > start && text.get(end - 1) == 0x0D;
    }

    public static inline function byteIsLf(text:Bytes, start:Int, end:Int, byteIdx:Int):Bool {
        return byteIdx >= 0 && byteIdx < end - start && text.get(start + byteIdx) == 0x0A;
    }

    public static inline function byteIsCr(text:Bytes, start:Int, end:Int, byteIdx:Int):Bool {
        return byteIdx >= 0 && byteIdx < end - start && text.get(start + byteIdx) == 0x0D;
    }

    // `str_utils::lines`

    public static inline function linesFromByteIdx(text:Bytes, start:Int, end:Int, byteIdx:Int, lineType:LineType):Int {
        return switch lineType {
            case LF: LinesLf.fromByteIdx(text, start, end, byteIdx);
            case LF_CR: LinesCrlf.fromByteIdx(text, start, end, byteIdx);
        }
    }

    public static inline function linesToByteIdx(text:Bytes, start:Int, end:Int, lineIdx:Int, lineType:LineType):Int {
        return switch lineType {
            case LF: LinesLf.toByteIdx(text, start, end, lineIdx);
            case LF_CR: LinesCrlf.toByteIdx(text, start, end, lineIdx);
        }
    }

    public static inline function linesCountBreaks(text:Bytes, start:Int, end:Int, lineType:LineType):Int {
        return switch lineType {
            case LF: LinesLf.countBreaks(text, start, end);
            case LF_CR: LinesCrlf.countBreaks(text, start, end);
        }
    }

    /**
     * Returns the byte index of the start of the last line of the passed text.
     *
     * Note: if the text ends in a line break, that means the last line is
     * an empty line that starts at the end of the text.
     */
    public static function lastLineStartByteIdx(text:Bytes, start:Int, end:Int, lineType:LineType):Int {
        var idx = end - start - 1;
        while (idx >= 0) {
            var byte = text.get(start + idx);
            if (byte == 0x0A) {
                return idx + 1;
            }

            // That was the only case for `LineType::LF`, so early out if that's
            // the line type.
            if (lineType == LF) {
                idx--;
                continue;
            }

            if (byte == 0x0D) {
                return idx + 1;
            }

            // That was the last case for `LineType::LF_CR` (the only other line
            // type enabled in this port).
            idx--;
        }
        return 0;
    }

    /**
     * If there is a trailing line break, returns its byte index.
     * Otherwise returns -1 (`None` in Rust).
     *
     * Note: a CRLF pair is always treated as a single unit, and thus
     * this function will return the index of the CR in such cases, even
     * with `LineType.LF` where CR is not on its own recognized as a line
     * break.
     */
    public static function trailingLineBreakIdx(text:Bytes, start:Int, end:Int, lineType:LineType):Int {
        var len = end - start;
        if (len == 0) {
            return -1;
        }

        var lastByte = text.get(end - 1);

        // First handle LF and CRLF since that's the most typical case, and
        // also because it's the same for all line types.
        if (lastByte == 0x0A) {
            if (len > 1) {
                var secondToLastByte = text.get(end - 2);
                if (secondToLastByte == 0x0D) {
                    return len - 2;
                }
            }
            return len - 1;
        }

        // That was the only case for `LineType::LF`, so early out if that's
        // the line type.
        if (lineType == LF) {
            return -1;
        }

        // Next we handle CR on its own.
        if (lastByte == 0x0D) {
            return len - 1;
        }

        // That was the last case for `LineType::LF_CR`.
        return -1;
    }

    public static inline function endsWithLineBreak(text:Bytes, start:Int, end:Int, lineType:LineType):Bool {
        return trailingLineBreakIdx(text, start, end, lineType) != -1;
    }

    /**
     * Returns the new end (relative to `start`) of the text once its trailing
     * line break is removed.
     */
    public static function trimTrailingLineBreak(text:Bytes, start:Int, end:Int, lineType:LineType):Int {
        var idx = trailingLineBreakIdx(text, start, end, lineType);
        return idx != -1 ? idx : end - start;
    }

}
