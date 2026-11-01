// Ported from ropey 2.0.0-beta.1: src/tree/text_info.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey.tree;

import haxe.io.Bytes;
import ropey.StrUtils.*;
import ropey.str_indices.Chars;
import ropey.str_indices.LinesCrlf;
import ropey.str_indices.LinesLf;
import ropey.str_indices.Utf16;

/**
 * Metrics of a piece of text, for the metrics enabled in gpui-kit's build of
 * ropey: bytes, chars, UTF-16 code units, LF and LF_CR line breaks.
 *
 * Rust's `TextInfo` is a `Copy` value. Here instances are immutable, so they
 * can be shared freely: every operation returns a new instance.
 */
class TextInfo {

    public static final EMPTY:TextInfo = new TextInfo(0, 0, 0, 0, 0);

    public final bytes:Int;

    public final chars:Int;

    public final utf16:Int;

    public final lineBreaksLf:Int;

    public final lineBreaksCrLf:Int;

    public inline function new(bytes:Int, chars:Int, utf16:Int, lineBreaksLf:Int, lineBreaksCrLf:Int) {
        this.bytes = bytes;
        this.chars = chars;
        this.utf16 = utf16;
        this.lineBreaksLf = lineBreaksLf;
        this.lineBreaksCrLf = lineBreaksCrLf;
    }

    /**
     * Creates a new empty `TextInfo`.
     */
    public static inline function empty():TextInfo {
        return EMPTY;
    }

    public static function fromStr(text:Bytes, start:Int, end:Int):TextInfo {
        var charCount = Chars.count(text, start, end);
        return new TextInfo(
            end - start,
            charCount,
            Utf16.countSurrogates(text, start, end) + charCount,
            LinesLf.countBreaks(text, start, end),
            LinesCrlf.countBreaks(text, start, end)
        );
    }

    public inline function lineBreaks(lineType:LineType):Int {
        return switch lineType {
            case LF: lineBreaksLf;
            case LF_CR: lineBreaksCrLf;
        }
    }

    /**
     * Updates info for a leaf node that has text inserted into it.  This
     * should be called with the pre-insertion `text`.
     */
    public function strInsert(text:Bytes, textStart:Int, textEnd:Int, byteIdx:Int, insertionInfo:TextInfo, insText:Bytes, insStart:Int, insEnd:Int):TextInfo {
        var seamCr = byteIdx > 0 && byteIsCr(text, textStart, textEnd, byteIdx - 1);
        var seamLf = byteIsLf(text, textStart, textEnd, byteIdx);

        var crlfSplitCompensation = (seamCr && seamLf) ? 1 : 0;
        var crlfMergeCompensation1 = (seamCr && startsWithLf(insText, insStart, insEnd)) ? 1 : 0;
        var crlfMergeCompensation2 = (endsWithCr(insText, insStart, insEnd) && seamLf) ? 1 : 0;

        return new TextInfo(
            bytes + insertionInfo.bytes,
            chars + insertionInfo.chars,
            utf16 + insertionInfo.utf16,
            lineBreaksLf + insertionInfo.lineBreaksLf,
            lineBreaksCrLf + insertionInfo.lineBreaksCrLf + crlfSplitCompensation - crlfMergeCompensation1 - crlfMergeCompensation2
        );
    }

    /**
     * Updates info for a leaf node that has text removed from it.  This
     * should be called with the pre-removal `text`.
     */
    public function strRemove(text:Bytes, textStart:Int, textEnd:Int, start:Int, end:Int):TextInfo {
        var textLen = textEnd - textStart;

        if (start == end) {
            return this;
        }
        if (start == 0 && end == textLen) {
            return EMPTY;
        }

        // Easier case: the removal range is larger than the text that will
        // remain, so we just scan the text that will be left over.
        if ((end - start) >= Std.int(textLen / 2)) {
            var leftInfo = fromStr(text, textStart, textStart + start);
            var rightInfo = fromStr(text, textStart + end, textEnd);

            var newInfo = leftInfo.add(rightInfo);

            if (endsWithCr(text, textStart, textStart + start) && startsWithLf(text, textStart + end, textEnd)) {
                newInfo = new TextInfo(newInfo.bytes, newInfo.chars, newInfo.utf16, newInfo.lineBreaksLf, newInfo.lineBreaksCrLf - 1);
            }

            return newInfo;
        }

        var newInfo = sub(fromStr(text, textStart + start, textStart + end));

        var startLf = byteIsLf(text, textStart, textEnd, start);
        var startCr = start > 0 && byteIsCr(text, textStart, textEnd, start - 1);
        var endLf = end < textLen && byteIsLf(text, textStart, textEnd, end);
        var endCr = byteIsCr(text, textStart, textEnd, end - 1);

        var crlfSplitCompensation1 = (startCr && startLf) ? 1 : 0;
        var crlfSplitCompensation2 = (endCr && endLf) ? 1 : 0;
        var crlfMergeCompensation = (startCr && endLf) ? 1 : 0;

        return new TextInfo(
            newInfo.bytes,
            newInfo.chars,
            newInfo.utf16,
            newInfo.lineBreaksLf,
            newInfo.lineBreaksCrLf + crlfSplitCompensation1 + crlfSplitCompensation2 - crlfMergeCompensation
        );
    }

    /**
     * Note: this does *not* handle anything related to CRLF line breaks.  It
     * just does a simple sum of the metrics.
     */
    public inline function add(rhs:TextInfo):TextInfo {
        return new TextInfo(
            bytes + rhs.bytes,
            chars + rhs.chars,
            utf16 + rhs.utf16,
            lineBreaksLf + rhs.lineBreaksLf,
            lineBreaksCrLf + rhs.lineBreaksCrLf
        );
    }

    /**
     * IMPORTANT: this does *not* handle anything related to CRLF line breaks.
     * It just does a simple subtraction of the metrics.
     */
    public inline function sub(rhs:TextInfo):TextInfo {
        return new TextInfo(
            bytes - rhs.bytes,
            chars - rhs.chars,
            utf16 - rhs.utf16,
            lineBreaksLf - rhs.lineBreaksLf,
            lineBreaksCrLf - rhs.lineBreaksCrLf
        );
    }

    public function equals(other:TextInfo):Bool {
        return bytes == other.bytes
            && chars == other.chars
            && utf16 == other.utf16
            && lineBreaksLf == other.lineBreaksLf
            && lineBreaksCrLf == other.lineBreaksCrLf;
    }

    public function toString():String {
        return 'TextInfo { bytes: $bytes, chars: $chars, utf16: $utf16, line_breaks_lf: $lineBreaksLf, line_breaks_cr_lf: $lineBreaksCrLf }';
    }

}
