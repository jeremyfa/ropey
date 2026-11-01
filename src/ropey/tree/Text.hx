// Ported from ropey 2.0.0-beta.1: src/tree/text.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey.tree;

import haxe.io.Bytes;
import ropey.StrUtils.*;
import ropey.str_indices.Chars;
import ropey.str_indices.Utf16;
import ropey.tree.Constants.MAX_TEXT_SIZE;

/**
 * A leaf node of the Rope, containing text.
 *
 * In Rust a leaf is a `Node::Leaf(Arc<Text>)`. Here `Text` itself is the
 * shared node object (see `Node` for the reference counting).
 *
 * The text is stored as UTF-8 in a fixed size buffer of `MAX_TEXT_SIZE`
 * bytes (`buf[0...len]`), like Rust's `inner::Buffer`.
 */
class Text extends Node {

    public final buf:Bytes;

    public var len(default, null):Int;

    //---------------------------------------------------------
    // Create.

    /**
     * Creates a new empty `Text`.
     */
    public function new() {
        super(true);
        buf = Bytes.alloc(MAX_TEXT_SIZE);
        len = 0;
    }

    /**
     * Creates a new `Text` with the same contents as `text[start...end]`.
     */
    public static function fromStr(text:Bytes, start:Int, end:Int):Text {
        var result = new Text();
        if (end - start > MAX_TEXT_SIZE)
            throw new RopeyException(OutOfBounds, 'assertion failed: text.len() <= MAX_TEXT_SIZE');
        result.buf.blit(0, text, start, end - start);
        result.len = end - start;
        return result;
    }

    override function cloneData():Node {
        var result = new Text();
        result.buf.blit(0, buf, 0, len);
        result.len = len;
        return result;
    }

    //---------------------------------------------------------
    // Query.

    /**
     * Returns the amount of free space in this text buffer, in bytes.
     */
    public inline function freeCapacity():Int {
        return MAX_TEXT_SIZE - len;
    }

    /**
     * Returns the contained text as a Haxe string (allocates).
     */
    public inline function text():String {
        return Utf8.decode(buf, 0, len);
    }

    public function isCharBoundary(byteIdx:Int):Bool {
        if (byteIdx > len)
            throw new RopeyException(OutOfBounds, 'assertion failed: byte_idx <= self.len()');
        return bufIsCharBoundary(byteIdx);
    }

    //---------------------------------------------------------
    // Metric conversions.

    public inline function byteToCharIdx(byteIdx:Int):Int {
        return Chars.fromByteIdx(buf, 0, len, byteIdx);
    }

    public inline function charToByteIdx(charIdx:Int):Int {
        return Chars.toByteIdx(buf, 0, len, charIdx);
    }

    public inline function byteToUtf16Idx(byteIdx:Int):Int {
        return Utf16.fromByteIdx(buf, 0, len, byteIdx);
    }

    public inline function utf16ToByteIdx(utf16Idx:Int):Int {
        return Utf16.toByteIdx(buf, 0, len, utf16Idx);
    }

    public inline function byteToLineIdx(byteIdx:Int, lineType:LineType):Int {
        return linesFromByteIdx(buf, 0, len, byteIdx, lineType);
    }

    public inline function lineToByteIdx(lineIdx:Int, lineType:LineType):Int {
        return linesToByteIdx(buf, 0, len, lineIdx, lineType);
    }

    //---------------------------------------------------------
    // Modify.

    /**
     * Inserts the given text at the given byte index, and computes an
     * updated TextInfo for the text at the same time.
     *
     * Throws if there isn't enough free space or if the byte index
     * isn't on a valid char boundary.
     */
    public function insertStrAndUpdateInfo(byteIdx:Int, text:Bytes, start:Int, end:Int, currentInfo:TextInfo):TextInfo {
        if (end == start) {
            return currentInfo;
        }

        // Update text info based on the upcoming insertion.
        var newInfo = currentInfo.strInsert(buf, 0, len, byteIdx, TextInfo.fromStr(text, start, end), text, start, end);

        bufInsert(byteIdx, text, start, end);

        return newInfo;
    }

    /**
     * Inserts `text` and splits the resulting text into two roughly equal
     * pieces, returning the right half.
     *
     * This can handle insertions even when already full, as long as the
     * resulting text can fit in two `Text`'s.
     */
    public function insertSplit(byteIdx:Int, text:Bytes, start:Int, end:Int):Text {
        var rightText = split(byteIdx);
        var textSplitIdx = findAppropriateSplitFloor(freeCapacity(), text, start, end);
        appendStr(text, start, start + textSplitIdx);
        rightText.prependStr(text, start + textSplitIdx, end);
        distribute(rightText);
        return rightText;
    }

    /**
     * Removes the text in the given right-exclusive byte range, and computes
     * an updated TextInfo for the resulting text at the same time.
     *
     * Throws if the range isn't valid or doesn't lie on valid char
     * boundaries.
     */
    public function removeRangeAndUpdateInfo(rangeStart:Int, rangeEnd:Int, currentInfo:TextInfo):TextInfo {
        // Update text info based on the upcoming removal.
        var newInfo = currentInfo.strRemove(buf, 0, len, rangeStart, rangeEnd);

        bufRemove(rangeStart, rangeEnd);

        return newInfo;
    }

    /**
     * Appends `text[start...end]` to the end.
     *
     * Throws if there isn't enough free space.
     */
    public inline function appendStr(text:Bytes, start:Int, end:Int):Void {
        bufInsert(len, text, start, end);
    }

    /**
     * Prepends `text[start...end]` to the start.
     *
     * Throws if there isn't enough free space.
     */
    public inline function prependStr(text:Bytes, start:Int, end:Int):Void {
        bufInsert(0, text, start, end);
    }

    /**
     * Splits the leaf into two leaves, at the given byte offset.
     *
     * This leaf will contain the left half of the text, and the
     * returned leaf will contain the right half.
     */
    public function split(byteIdx:Int):Text {
        if (byteIdx > len)
            throw new RopeyException(OutOfBounds);
        var right = fromStr(buf, byteIdx, len);
        bufRemove(byteIdx, len);
        return right;
    }

    /**
     * Equidistributes text data between `this` and `other`.  This behaves
     * as if the text of `other` is appended to the end of `this`, and the
     * result is then split between the two, with `other` being the right
     * half of the text.
     */
    public function distribute(other:Text):Void {
        // Fix any pre-existing CRLF splits.
        if (endsWithCr(buf, 0, len) && startsWithLf(other.buf, 0, other.len)) {
            if (len > other.len) {
                bufRemove(len - 1, len);
                other.bufInsert(0, CR_BYTES, 0, 1);
            }
            else {
                bufInsert(len, LF_BYTES, 0, 1);
                other.bufRemove(0, 1);
            }
        }

        // Distribute.
        var totalLen = len + other.len;
        var splitIdx = Std.int((totalLen + 1) / 2);
        if (splitIdx < len) {
            splitIdx = findAppropriateSplitCeil(splitIdx, buf, 0, len);
            other.bufInsert(0, buf, splitIdx, len);
            bufRemove(splitIdx, len);
        }
        else if (splitIdx > len) {
            splitIdx -= len;
            splitIdx = findAppropriateSplitFloor(splitIdx, other.buf, 0, other.len);
            bufInsert(len, other.buf, 0, splitIdx);
            other.bufRemove(0, splitIdx);
        }
        else {
            // Already equidistributed, so do nothing.
        }
    }

    /**
     * Content equality with another leaf (`PartialEq<Text>`).
     */
    public function equals(other:Text):Bool {
        if (len != other.len)
            return false;
        for (i in 0...len) {
            if (buf.get(i) != other.buf.get(i))
                return false;
        }
        return true;
    }

    /**
     * Content equality with a string (`PartialEq<&str>`).
     */
    public function equalsStr(s:String):Bool {
        return text() == s;
    }

    public function toString():String {
        return 'Text { "' + text() + '" }';
    }

    //=============================================================
    // The guts of `Text` (Rust's `inner::Buffer`).

    static final CR_BYTES:Bytes = Bytes.ofString('\r');
    static final LF_BYTES:Bytes = Bytes.ofString('\n');

    /**
     * Returns whether the given byte index is a valid char
     * boundary or not.
     *
     * Note: always returns true for out-of-bounds indices.  This is
     * because bounds checking will happen elsewhere anyway.
     */
    inline function bufIsCharBoundary(byteIdx:Int):Bool {
        if (byteIdx >= len) {
            return true;
        }
        return isCharBoundaryByte(buf.get(byteIdx));
    }

    function bufInsert(byteIdx:Int, text:Bytes, start:Int, end:Int):Void {
        if (!bufIsCharBoundary(byteIdx))
            throw new RopeyException(NonCharBoundary, 'assertion failed: self.is_char_boundary(byte_idx)');
        if (byteIdx > len)
            throw new RopeyException(OutOfBounds, 'assertion failed: byte_idx <= self.len()');
        var textLen = end - start;
        if (len + textLen > MAX_TEXT_SIZE)
            throw new RopeyException(OutOfBounds, 'assertion failed: self.len() + text.len() <= self.buffer.len()');

        if (len > byteIdx)
            buf.blit(byteIdx + textLen, buf, byteIdx, len - byteIdx);
        if (textLen > 0)
            buf.blit(byteIdx, text, start, textLen);

        len += textLen;
    }

    function bufRemove(start:Int, end:Int):Void {
        if (!bufIsCharBoundary(start))
            throw new RopeyException(NonCharBoundary, 'assertion failed: self.is_char_boundary(byte_idx_range[0])');
        if (!bufIsCharBoundary(end))
            throw new RopeyException(NonCharBoundary, 'assertion failed: self.is_char_boundary(byte_idx_range[1])');
        if (start > end)
            throw new RopeyException(InvalidRange, 'assertion failed: byte_idx_range[0] <= byte_idx_range[1]');
        if (end > len)
            throw new RopeyException(OutOfBounds, 'assertion failed: byte_idx_range[1] <= self.len()');

        if (len > end)
            buf.blit(start, buf, end, len - end);

        len -= end - start;
    }

}
