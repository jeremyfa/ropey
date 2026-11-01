// Ported from ropey 2.0.0-beta.1: src/shared_impl.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

import haxe.io.Bytes as ByteArray;
import ropey.iter.Bytes;
import ropey.iter.CharIndices;
import ropey.iter.Chars;
import ropey.iter.Chunks;
import ropey.iter.Lines;
import ropey.str_indices.Chars as StrChars;
import ropey.str_indices.Utf16 as StrUtf16;
import ropey.tree.Node;
import ropey.tree.Text;
import ropey.tree.TextInfo;

/**
 * The methods shared between `Rope` and `RopeSlice` (Rust generates them on
 * both types with the macros of `shared_impl.rs`).
 *
 * A `RopeBase` is either backed by a tree (`root`, `rootInfo` and the byte
 * range `rangeStart...rangeEnd` of `root` it covers), or, for a `RopeSlice`
 * made from a string, by UTF-8 bytes (`str[strOffset...strOffset + len()]`).
 *
 * All indices are UTF-8 byte offsets (or char / UTF-16 / line indices for the
 * metric conversions), exactly like Rust. Methods that panic in Rust throw a
 * `RopeyException`.
 *
 * A `RopeSlice`, `ChunkCursor` or iterator borrows the tree of the rope it
 * comes from: like in Rust, it must not be used after that rope is modified
 * (clone the rope first to keep a snapshot, which is O(1)).
 */
class RopeBase {

    @:allow(ropey) var root:Node;

    @:allow(ropey) var rootInfo:TextInfo;

    @:allow(ropey) var rangeStart:Int;

    @:allow(ropey) var rangeEnd:Int;

    /**
     * Text of a slice made from a string (`SliceInner::Str`), else null.
     */
    @:allow(ropey) var str:ByteArray;

    @:allow(ropey) var strOffset:Int;

    // Results of `locateChunk()`.
    var chunkBuf:ByteArray;
    var chunkStartPos:Int;
    var chunkEndPos:Int;
    var chunkOffset:Int;

    function new() {}

    //-----------------------------------------------------
    // Queries.

    /**
     * Total number of bytes in the text.
     *
     * Runs in O(1) time.
     */
    public inline function len():Int {
        return rangeEnd - rangeStart;
    }

    /**
     * Total number of chars in the text.
     *
     * Runs in best case O(1) time, worst-case O(log N).
     */
    public function lenChars():Int {
        if (str != null) {
            return StrChars.count(str, strOffset, strOffset + len());
        }

        if (isFullInfo()) {
            return rootInfo.chars;
        }
        else {
            var charStartIdx = _byteToCharIdx(rangeStart);
            var charEndIdx = _byteToCharIdx(rangeEnd);
            return charEndIdx - charStartIdx;
        }
    }

    /**
     * Total number of UTF-16 code units that would be in the text if it were
     * encoded as UTF-16.
     *
     * Runs in best case O(1) time, worst-case O(log N).
     */
    public function lenUtf16():Int {
        if (str != null) {
            return StrUtf16.count(str, strOffset, strOffset + len());
        }

        if (isFullInfo()) {
            return rootInfo.utf16;
        }
        else {
            var utf16StartIdx = _byteToUtf16Idx(rangeStart);
            var utf16EndIdx = _byteToUtf16Idx(rangeEnd);
            return utf16EndIdx - utf16StartIdx;
        }
    }

    /**
     * Total number of lines in the text, according to the passed line type.
     *
     * Runs in best case O(1) time, worst-case O(log N).
     */
    public function lenLines(lineType:LineType):Int {
        if (str != null) {
            return StrUtils.linesCountBreaks(str, strOffset, strOffset + len(), lineType) + 1;
        }

        if (isFullInfo()) {
            return rootInfo.lineBreaks(lineType) + 1;
        }
        else {
            var lineStartIdx = _byteToLineIdx(rangeStart, lineType);
            var lineEndIdx = _byteToLineIdx(rangeEnd, lineType);
            var endsWithCrlfSplit = _isRelevantCrlfSplit(rangeEnd, lineType);

            return lineEndIdx - lineStartIdx + 1 + (endsWithCrlfSplit ? 1 : 0);
        }
    }

    /**
     * Returns whether `byteIdx` is a char boundary.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     */
    public function isCharBoundary(byteIdx:Int):Bool {
        assertByteIdx(byteIdx);

        if (str != null) {
            return StrUtils.isCharBoundary(byteIdx, str, strOffset, strOffset + len());
        }

        locateChunk(byteIdx);
        return StrUtils.isCharBoundary(byteIdx - chunkOffset, chunkBuf, chunkStartPos, chunkEndPos);
    }

    /**
     * Returns the byte index of the closest char boundary less than or equal
     * to `byteIdx`.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     */
    public function floorCharBoundary(byteIdx:Int):Int {
        assertByteIdx(byteIdx);

        if (str != null) {
            return StrUtils.floorCharBoundary(byteIdx, str, strOffset, strOffset + len());
        }

        locateChunk(byteIdx);
        return chunkOffset + StrUtils.floorCharBoundary(byteIdx - chunkOffset, chunkBuf, chunkStartPos, chunkEndPos);
    }

    /**
     * Returns the byte index of the closest char boundary greater than or
     * equal to `byteIdx`.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     */
    public function ceilCharBoundary(byteIdx:Int):Int {
        assertByteIdx(byteIdx);

        if (str != null) {
            return StrUtils.ceilCharBoundary(byteIdx, str, strOffset, strOffset + len());
        }

        locateChunk(byteIdx);
        return chunkOffset + StrUtils.ceilCharBoundary(byteIdx - chunkOffset, chunkBuf, chunkStartPos, chunkEndPos);
    }

    /**
     * Returns the byte index of the trailing line break of the text, if any
     * (else null).
     *
     * Note: a CRLF pair is always treated as a single unit, and thus this
     * returns the index of the CR in such cases, even with `LineType.LF`.
     *
     * Runs in O(log N) time.
     */
    public function trailingLineBreakIdx(lineType:LineType):Null<Int> {
        if (len() == 0) {
            return null;
        }

        if (str != null) {
            var idx = StrUtils.trailingLineBreakIdx(str, strOffset, strOffset + len(), lineType);
            return idx != -1 ? idx : null;
        }

        locateChunk(len() - 1);
        var idx = StrUtils.trailingLineBreakIdx(chunkBuf, chunkStartPos, chunkEndPos, lineType);
        return idx != -1 ? chunkOffset + idx : null;
    }

    //-----------------------------------------------------
    // Fetching.

    /**
     * Returns the byte at `byteIdx`.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx >= len()`).
     */
    public function byte(byteIdx:Int):Int {
        var byte = byteImpl(byteIdx);
        if (byte == -1)
            throw new RopeyException(OutOfBounds);
        return byte;
    }

    /**
     * Returns the char (code point) starting at the given byte index.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx >= len()`) or is
     * not a char boundary.
     */
    public function char(byteIdx:Int):Int {
        var c = charImpl(byteIdx);
        if (c < 0)
            throw new RopeyException(c == -1 ? OutOfBounds : NonCharBoundary);
        return c;
    }

    /**
     * Returns the line at `lineIdx`, according to the given line type.
     *
     * Note: lines are zero-indexed.
     *
     * Runs in O(log N) time.
     *
     * Throws if `lineIdx` is out of bounds (i.e. `lineIdx >= lenLines()`).
     */
    public function line(lineIdx:Int, lineType:LineType):RopeSlice {
        var line = getLine(lineIdx, lineType);
        if (line == null)
            throw new RopeyException(OutOfBounds);
        return line;
    }

    /**
     * Returns the chunk containing the given byte index, and the byte index
     * of its start (see `Chunk`).
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     */
    public function chunk(byteIdx:Int):Chunk {
        var chunk = getChunk(byteIdx);
        if (chunk == null)
            throw new RopeyException(OutOfBounds);
        return chunk;
    }

    //-----------------------------------------------------
    // Metric conversions.

    /**
     * Returns the char index of the given byte.
     *
     * Notes:
     *
     * - If the byte is in the middle of a multi-byte char, returns the
     *   index of the char that the byte belongs to.
     * - `byteIdx` can be one-past-the-end, which will return
     *   one-past-the-end char index.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     */
    public function byteToCharIdx(byteIdx:Int):Int {
        assertByteIdx(byteIdx);

        if (str != null) {
            return StrChars.fromByteIdx(str, strOffset, strOffset + len(), byteIdx);
        }

        if (isFullInfo()) {
            return _byteToCharIdx(byteIdx);
        }
        else {
            return _byteToCharIdx(rangeStart + byteIdx) - _byteToCharIdx(rangeStart);
        }
    }

    /**
     * Returns the byte index of the given char.
     *
     * Notes:
     *
     * - `charIdx` can be one-past-the-end, which will return one-past-the-end
     *   byte index.
     *
     * Runs in O(log N) time.
     *
     * Throws if `charIdx` is out of bounds (i.e. `charIdx > lenChars()`).
     */
    public function charToByteIdx(charIdx:Int):Int {
        if (charIdx < 0 || charIdx > lenChars())
            throw new RopeyException(OutOfBounds);

        if (str != null) {
            return StrChars.toByteIdx(str, strOffset, strOffset + len(), charIdx);
        }

        if (isFullInfo()) {
            return _charToByteIdx(charIdx);
        }
        else {
            var charStartIdx = _byteToCharIdx(rangeStart);
            return _charToByteIdx(charStartIdx + charIdx) - rangeStart;
        }
    }

    /**
     * Returns the UTF-16 code unit index of the given byte.
     *
     * Notes:
     *
     * - If the byte is in the middle of a multi-byte char, returns the
     *   UTF-16 index of the char that the byte belongs to.
     * - `byteIdx` can be one-past-the-end, which will return one-past-the-end
     *   UTF-16 index.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     */
    public function byteToUtf16Idx(byteIdx:Int):Int {
        assertByteIdx(byteIdx);

        if (str != null) {
            return StrUtf16.fromByteIdx(str, strOffset, strOffset + len(), byteIdx);
        }

        if (isFullInfo()) {
            return _byteToUtf16Idx(byteIdx);
        }
        else {
            return _byteToUtf16Idx(rangeStart + byteIdx) - _byteToUtf16Idx(rangeStart);
        }
    }

    /**
     * Returns the byte index of the given UTF-16 code unit.
     *
     * Notes:
     *
     * - If the UTF-16 code unit is in the middle of a char, returns the byte
     *   index of the char that it belongs to.
     * - `utf16Idx` can be one-past-the-end, which will return one-past-the-end
     *   byte index.
     *
     * Runs in O(log N) time.
     *
     * Throws if `utf16Idx` is out of bounds (i.e. `utf16Idx > lenUtf16()`).
     */
    public function utf16ToByteIdx(utf16Idx:Int):Int {
        if (utf16Idx < 0 || utf16Idx > lenUtf16())
            throw new RopeyException(OutOfBounds);

        if (str != null) {
            return StrUtf16.toByteIdx(str, strOffset, strOffset + len(), utf16Idx);
        }

        if (isFullInfo()) {
            return _utf16ToByteIdx(utf16Idx);
        }
        else {
            var utf16StartIdx = _byteToUtf16Idx(rangeStart);
            return _utf16ToByteIdx(utf16StartIdx + utf16Idx) - rangeStart;
        }
    }

    /**
     * Returns the line index of the line that the given byte belongs to.
     *
     * Notes:
     *
     * - Counts lines according to the passed line type.
     * - Lines are zero-indexed.  This is functionally equivalent to counting
     *   the line breaks before the specified byte.
     * - `byteIdx` can be one-past-the-end, which will return the last line
     *   index.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     */
    public function byteToLineIdx(byteIdx:Int, lineType:LineType):Int {
        assertByteIdx(byteIdx);

        if (str != null) {
            return StrUtils.linesFromByteIdx(str, strOffset, strOffset + len(), byteIdx, lineType);
        }

        if (isFullInfo()) {
            return _byteToLineIdx(byteIdx, lineType);
        }
        else {
            // Like ropey, this compares the relative `byteIdx` with the
            // absolute end of the range.
            var crlfSplit = if (byteIdx == rangeEnd) {
                _isRelevantCrlfSplit(rangeEnd, lineType);
            }
            else {
                false;
            }

            return _byteToLineIdx(rangeStart + byteIdx, lineType) - _byteToLineIdx(rangeStart, lineType) + (crlfSplit ? 1 : 0);
        }
    }

    /**
     * Returns the byte index of the start of the given line.
     *
     * Notes:
     *
     * - Counts lines according to the passed line type.
     * - Lines are zero-indexed.
     * - `lineIdx` can be one-past-the-end, which will return one-past-the-end
     *   byte index.
     *
     * Runs in O(log N) time.
     *
     * Throws if `lineIdx` is out of bounds (i.e. `lineIdx > lenLines()`).
     */
    public function lineToByteIdx(lineIdx:Int, lineType:LineType):Int {
        if (lineIdx < 0 || lineIdx > lenLines(lineType))
            throw new RopeyException(OutOfBounds);

        if (str != null) {
            return StrUtils.linesToByteIdx(str, strOffset, strOffset + len(), lineIdx, lineType);
        }

        if (isFullInfo()) {
            return _lineToByteIdx(lineIdx, lineType);
        }
        else {
            var lineStartIdx = _byteToLineIdx(rangeStart, lineType);
            var result = _lineToByteIdx(lineStartIdx + lineIdx, lineType) - rangeStart;
            if (result < 0)
                result = 0;
            return result < len() ? result : len();
        }
    }

    //-----------------------------------------------------
    // Iterators.

    /**
     * Creates an iterator over the bytes of the text.
     *
     * Runs in O(log N) time.
     */
    public function bytes():Bytes {
        if (str != null) {
            return Bytes.fromStr(str, strOffset, strOffset + len(), 0);
        }

        return Bytes.create(root, rootInfo, rangeStart, rangeEnd, rangeStart);
    }

    /**
     * Creates an iterator over the bytes of the text, starting at byte
     * `byteIdx`.
     *
     * If `byteIdx == len()` then an iterator at the end of the text is
     * created (i.e. `next()` will return null).
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     */
    public function bytesAt(byteIdx:Int):Bytes {
        assertByteIdx(byteIdx);
        if (str != null) {
            return Bytes.fromStr(str, strOffset, strOffset + len(), byteIdx);
        }
        return Bytes.create(root, rootInfo, rangeStart, rangeEnd, rangeStart + byteIdx);
    }

    /**
     * Creates an iterator over the chars of the text.
     *
     * Runs in O(log N) time.
     */
    public function chars():Chars {
        if (str != null) {
            return Chars.fromStr(str, strOffset, strOffset + len(), 0);
        }

        return Chars.create(root, rootInfo, rangeStart, rangeEnd, rangeStart);
    }

    /**
     * Creates an iterator over the chars of the text, starting at the char
     * that begins at byte `byteIdx`.
     *
     * If `byteIdx == len()` then an iterator at the end of the text is
     * created (i.e. `next()` will return -1).
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`) or is
     * not a char boundary.
     */
    public function charsAt(byteIdx:Int):Chars {
        assertByteIdx(byteIdx);
        if (str != null) {
            return Chars.fromStr(str, strOffset, strOffset + len(), byteIdx);
        }
        return Chars.create(root, rootInfo, rangeStart, rangeEnd, rangeStart + byteIdx);
    }

    /**
     * Creates an iterator over the chars of the text and their byte
     * positions.
     *
     * Runs in O(log N) time.
     */
    public function charIndices():CharIndices {
        return new CharIndices(chars());
    }

    /**
     * Creates an iterator over the chars of the text and their byte
     * positions, starting at the char that begins at byte `byteIdx`.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`) or is
     * not a char boundary.
     */
    public function charIndicesAt(byteIdx:Int):CharIndices {
        return new CharIndices(charsAt(byteIdx));
    }

    /**
     * Creates an iterator over the lines of the text, according to the given
     * line type.
     *
     * Runs in O(log N) time.
     */
    public function lines(lineType:LineType):Lines {
        if (str != null) {
            return Lines.fromStr(str, strOffset, strOffset + len(), 0, lineType);
        }

        return Lines.create(root, rootInfo, rangeStart, rangeEnd, 0, lineType);
    }

    /**
     * Creates an iterator over the lines of the text, starting at line
     * `lineIdx`.
     *
     * If `lineIdx == lenLines()` then an iterator at the end of the text is
     * created (i.e. `next()` will return null).
     *
     * Runs in O(log N) time.
     *
     * Throws if `lineIdx` is out of bounds (i.e. `lineIdx > lenLines()`).
     */
    public function linesAt(lineIdx:Int, lineType:LineType):Lines {
        if (str != null) {
            return Lines.fromStr(str, strOffset, strOffset + len(), lineIdx, lineType);
        }
        return Lines.create(root, rootInfo, rangeStart, rangeEnd, lineIdx, lineType);
    }

    /**
     * Creates an iterator over the chunks of the text.
     *
     * Runs in O(log N) time.
     */
    public function chunks():Chunks {
        if (str != null) {
            return Chunks.fromStr(str, strOffset, strOffset + len(), 0);
        }

        return Chunks.create(root, rootInfo, rangeStart, rangeEnd, rangeStart);
    }

    /**
     * Creates an iterator over the chunks of the text, with the iterator
     * starting at the chunk containing `byteIdx`.
     *
     * Also returns the byte index of the beginning of the first chunk to be
     * yielded, in the `startByteIdx` field of the iterator (Rust returns a
     * tuple).
     *
     * If `byteIdx == len()` an iterator at the end of the text (yielding
     * nothing) is created.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     */
    public function chunksAt(byteIdx:Int):Chunks {
        assertByteIdx(byteIdx);
        var result = if (str != null) {
            Chunks.fromStr(str, strOffset, strOffset + len(), byteIdx);
        }
        else {
            Chunks.create(root, rootInfo, rangeStart, rangeEnd, rangeStart + byteIdx);
        }
        var startIdx = result.startByteIdx - rangeStart;
        result.startByteIdx = startIdx < 0 ? 0 : startIdx;
        return result;
    }

    /**
     * Creates a cursor for navigating the chunks of the text.
     *
     * The cursor starts on the first chunk.
     *
     * Runs in O(log N) time.
     */
    public function chunkCursor():ChunkCursor {
        if (str != null) {
            return ChunkCursor.fromStr(str, strOffset, strOffset + len());
        }

        return ChunkCursor.create(root, rootInfo, rangeStart, rangeEnd, rangeStart);
    }

    /**
     * Creates a cursor for navigating the chunks of the text, starting on the
     * chunk containing `byteIdx`.
     *
     * Runs in O(log N) time.
     *
     * Throws if `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     */
    public function chunkCursorAt(byteIdx:Int):ChunkCursor {
        if (str != null) {
            return ChunkCursor.fromStr(str, strOffset, strOffset + len());
        }
        if (byteIdx < 0)
            throw new RopeyException(OutOfBounds);
        return ChunkCursor.create(root, rootInfo, rangeStart, rangeEnd, rangeStart + byteIdx);
    }

    /**
     * Returns the entire text as a string if it is contiguous in memory (a
     * single chunk), else null.
     *
     * Runs in O(1) time.
     */
    public function asStr():Null<String> {
        if (str != null) {
            return Utf8.decode(str, strOffset, strOffset + len());
        }

        if (root.isLeaf) {
            var text:Text = cast root;
            return Utf8.decode(text.buf, rangeStart, rangeEnd);
        }
        else {
            return null;
        }
    }

    //-----------------------------------------------------
    // Non-panicking.

    /**
     * Non-panicking version of `byte()`: returns null if `byteIdx` is out of
     * bounds.
     */
    public function getByte(byteIdx:Int):Null<Int> {
        var byte = byteImpl(byteIdx);
        return byte != -1 ? byte : null;
    }

    /**
     * Non-panicking version of `char()`: returns null if `byteIdx` is out of
     * bounds or not a char boundary (use `tryChar()` to know which).
     */
    public function getChar(byteIdx:Int):Null<Int> {
        var c = charImpl(byteIdx);
        return c >= 0 ? c : null;
    }

    /**
     * Rust's `get_char()` result: returns the error (`OutOfBounds` or
     * `NonCharBoundary`) or null when there is a char at `byteIdx`.
     */
    public function tryChar(byteIdx:Int):Null<Error> {
        var c = charImpl(byteIdx);
        return c >= 0 ? null : c == -1 ? OutOfBounds : NonCharBoundary;
    }

    /**
     * Non-panicking version of `line()`: returns null if `lineIdx` is out of
     * bounds.
     */
    public function getLine(lineIdx:Int, lineType:LineType):Null<RopeSlice> {
        if (lineIdx < 0 || lineIdx >= lenLines(lineType)) {
            return null;
        }

        if (str != null) {
            var end = strOffset + len();
            var startByte = StrUtils.linesToByteIdx(str, strOffset, end, lineIdx, lineType);
            var endByte = StrUtils.linesToByteIdx(str, strOffset, end, lineIdx + 1, lineType);
            return RopeSlice.fromStrBytes(str, strOffset + startByte, strOffset + endByte);
        }

        var startByte = lineToByteIdx(lineIdx, lineType);
        var endByte = lineToByteIdx(lineIdx + 1, lineType);

        return slice(startByte, endByte);
    }

    /**
     * Non-panicking version of `chunk()`: returns null if `byteIdx` is out of
     * bounds.
     */
    public function getChunk(byteIdx:Int):Null<Chunk> {
        if (byteIdx < 0 || byteIdx > len()) {
            return null;
        }
        locateChunk(byteIdx);
        return new Chunk(chunkBuf, chunkStartPos, chunkEndPos, chunkOffset);
    }

    //-----------------------------------------------------
    // Slicing.

    /**
     * Gets an immutable slice of the text, in the byte range `start...end`
     * (Rust's `slice(start..end)`; use `sliceFrom(start)` for `start..`).
     *
     * Runs in O(log N) time.
     *
     * Throws:
     *
     * - If the start of the range is greater than the end.
     * - If the end of the range is out of bounds (i.e. `end > len()`).
     * - If the range ends are not on char boundaries.
     */
    public function slice(start:Int, end:Int):RopeSlice {
        var result = trySliceImpl(start, end);
        if (sliceError != null)
            throw new RopeyException(sliceError);
        return result;
    }

    /**
     * Rust's `slice(start..)`.
     */
    public inline function sliceFrom(start:Int):RopeSlice {
        return slice(start, len());
    }

    /**
     * Non-panicking version of `slice()`: returns null on failure (use
     * `trySliceError()` to know why).
     *
     * Note: like ropey, this still throws if one of the range ends is
     * greater than `len()` (the char boundary check comes first).
     */
    public function trySlice(start:Int, end:Int):Null<RopeSlice> {
        var result = trySliceImpl(start, end);
        return sliceError != null ? null : result;
    }

    /**
     * The error of the last failed `trySlice()`, or null.
     */
    public inline function trySliceError():Null<Error> {
        return sliceError;
    }

    var sliceError:Null<Error> = null;

    function trySliceImpl(startIdx:Int, endIdx:Int):RopeSlice {
        sliceError = null;
        if (!isCharBoundary(startIdx) || !isCharBoundary(endIdx)) {
            sliceError = NonCharBoundary;
            return null;
        }
        if (startIdx > endIdx) {
            sliceError = InvalidRange;
            return null;
        }
        if (endIdx > len()) {
            sliceError = OutOfBounds;
            return null;
        }

        var startIdxReal = rangeStart + startIdx;
        var endIdxReal = rangeStart + endIdx;

        if (str != null) {
            return RopeSlice.fromStrBytes(str, strOffset + startIdx, strOffset + endIdx);
        }
        return RopeSlice.create(root, rootInfo, startIdxReal, endIdxReal);
    }

    //-----------------------------------------------------
    // Comparisons and conversions (`shared_std_impls!`).

    /**
     * Content equality with another rope or slice (`PartialEq`).
     */
    public function equals(other:RopeBase):Bool {
        if (len() != other.len()) {
            return false;
        }
        return compareImpl(other, true) == 0;
    }

    /**
     * Content equality with a string (`PartialEq<&str>`).
     */
    public function equalsStr(other:String):Bool {
        var bytes = Utf8.encode(other);
        if (len() != bytes.length) {
            return false;
        }

        var idx = 0;
        var chunks = chunks();
        while (chunks.nextRaw()) {
            var b = chunks.rawBytes;
            for (i in chunks.rawStart...chunks.rawEnd) {
                if (b.get(i) != bytes.get(idx))
                    return false;
                idx++;
            }
        }

        return true;
    }

    /**
     * Lexicographic byte comparison (`Ord`): negative, zero or positive.
     */
    public function compare(other:RopeBase):Int {
        var result = compareImpl(other, false);
        if (result != 0)
            return result;
        var l1 = len();
        var l2 = other.len();
        return l1 < l2 ? -1 : l1 > l2 ? 1 : 0;
    }

    function compareImpl(other:RopeBase, eqOnly:Bool):Int {
        var chunkItr1 = chunks();
        var chunkItr2 = other.chunks();
        var b1:ByteArray = null;
        var s1 = 0;
        var e1 = 0;
        var b2:ByteArray = null;
        var s2 = 0;
        var e2 = 0;
        if (chunkItr1.nextRaw()) {
            b1 = chunkItr1.rawBytes;
            s1 = chunkItr1.rawStart;
            e1 = chunkItr1.rawEnd;
        }
        if (chunkItr2.nextRaw()) {
            b2 = chunkItr2.rawBytes;
            s2 = chunkItr2.rawStart;
            e2 = chunkItr2.rawEnd;
        }

        while (true) {
            var n = (e1 - s1) < (e2 - s2) ? (e1 - s1) : (e2 - s2);
            for (i in 0...n) {
                var c1 = b1.get(s1 + i);
                var c2 = b2.get(s2 + i);
                if (c1 != c2)
                    return c1 < c2 ? -1 : 1;
            }
            s1 += n;
            s2 += n;

            if (s1 == e1) {
                if (chunkItr1.nextRaw()) {
                    b1 = chunkItr1.rawBytes;
                    s1 = chunkItr1.rawStart;
                    e1 = chunkItr1.rawEnd;
                }
                else {
                    break;
                }
            }

            if (s2 == e2) {
                if (chunkItr2.nextRaw()) {
                    b2 = chunkItr2.rawBytes;
                    s2 = chunkItr2.rawStart;
                    e2 = chunkItr2.rawEnd;
                }
                else {
                    break;
                }
            }
        }

        return 0;
    }

    /**
     * A hash of the text content (Rust's `Hash`), independent of how the
     * text is split into chunks.
     *
     * Rust feeds the bytes to a `Hasher` then writes a 0xff terminator byte.
     * Here the hasher is a 32 bit FNV-1a: `state` is the hash to continue
     * from (to hash several values in a row, like Rust's `Hasher`), the
     * default is the FNV offset basis.
     */
    public function hash(state:Int = 0x811c9dc5):Int {
        var h = state;
        var chunks = chunks();
        while (chunks.nextRaw()) {
            var b = chunks.rawBytes;
            for (i in chunks.rawStart...chunks.rawEnd) {
                h = fnvStep(h, b.get(i));
            }
        }
        return fnvStep(h, 0xff);
    }

    static inline function fnvStep(h:Int, byte:Int):Int {
        h = h ^ byte;
        // h * 16777619 (the FNV prime) modulo 2^32, without a 32 bit
        // multiplication that would lose precision on JS.
        return (h + (h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24)) | 0;
    }

    /**
     * The whole text as a Haxe string (Rust's `to_string()` / `String::from`).
     */
    public function toString():String {
        if (str != null) {
            return Utf8.decode(str, strOffset, strOffset + len());
        }
        var total = len();
        if (total == 0)
            return '';
        var out = ByteArray.alloc(total);
        var pos = 0;
        var chunks = chunks();
        while (chunks.nextRaw()) {
            var n = chunks.rawEnd - chunks.rawStart;
            out.blit(pos, chunks.rawBytes, chunks.rawStart, n);
            pos += n;
        }
        return out.getString(0, total, UTF8);
    }

    /**
     * The whole text as UTF-8 bytes.
     */
    public function toBytes():ByteArray {
        var total = len();
        var out = ByteArray.alloc(total);
        var pos = 0;
        var chunks = chunks();
        while (chunks.nextRaw()) {
            var n = chunks.rawEnd - chunks.rawStart;
            out.blit(pos, chunks.rawBytes, chunks.rawStart, n);
            pos += n;
        }
        return out;
    }

    //-----------------------------------------------------
    // Internal utility methods.

    inline function assertByteIdx(byteIdx:Int):Void {
        if (byteIdx < 0 || byteIdx > len())
            throw new RopeyException(OutOfBounds);
    }

    inline function isFullInfo():Bool {
        return str == null && rangeStart == 0 && rangeEnd == rootInfo.bytes;
    }

    /**
     * `get_chunk()`: sets `chunkBuf[chunkStartPos...chunkEndPos]` to the
     * (trimmed) chunk containing `byteIdx` and `chunkOffset` to its start
     * byte index. Assumes `byteIdx <= len()`.
     */
    function locateChunk(byteIdx:Int):Void {
        if (str != null) {
            chunkBuf = str;
            chunkStartPos = strOffset;
            chunkEndPos = strOffset + len();
            chunkOffset = 0;
            return;
        }

        var chunk = root.getTextAtByteFast(rangeStart + byteIdx);
        var startByte = Node.textStartBytes;

        if (isFullInfo()) {
            // Simple case: we have a full rope, so no adjustments are
            // needed.
            chunkBuf = chunk.buf;
            chunkStartPos = 0;
            chunkEndPos = chunk.len;
            chunkOffset = startByte;
        }
        else {
            // Trim chunk.
            var frontTrimIdx = rangeStart - startByte;
            if (frontTrimIdx < 0)
                frontTrimIdx = 0;
            var backTrimIdx = rangeEnd - startByte;
            if (backTrimIdx > chunk.len)
                backTrimIdx = chunk.len;
            chunkBuf = chunk.buf;
            chunkStartPos = frontTrimIdx;
            chunkEndPos = backTrimIdx;

            // Compute left-side text info.
            var localStartByte = startByte - rangeStart;
            chunkOffset = localStartByte < 0 ? 0 : localStartByte;
        }
    }

    function byteImpl(byteIdx:Int):Int {
        if (byteIdx < 0 || byteIdx >= len()) {
            return -1;
        }

        locateChunk(byteIdx);
        return chunkBuf.get(chunkStartPos + byteIdx - chunkOffset);
    }

    /**
     * Returns the char at `byteIdx`, or -1 (`OutOfBounds`), or -2
     * (`NonCharBoundary`).
     */
    function charImpl(byteIdx:Int):Int {
        if (byteIdx < 0 || byteIdx >= len()) {
            return -1;
        }

        locateChunk(byteIdx);
        var localIdx = byteIdx - chunkOffset;

        if (!StrUtils.isCharBoundary(localIdx, chunkBuf, chunkStartPos, chunkEndPos)) {
            return -2;
        }

        return Utf8.codePointAt(chunkBuf, chunkStartPos + localIdx);
    }

    inline function _byteToCharIdx(byteIdx:Int):Int {
        return root.treeByteToCharIdx(byteIdx);
    }

    inline function _charToByteIdx(charIdx:Int):Int {
        return root.treeCharToByteIdx(charIdx);
    }

    inline function _byteToUtf16Idx(byteIdx:Int):Int {
        return root.treeByteToUtf16Idx(byteIdx);
    }

    inline function _utf16ToByteIdx(utf16Idx:Int):Int {
        return root.treeUtf16ToByteIdx(utf16Idx);
    }

    inline function _byteToLineIdx(byteIdx:Int, lineType:LineType):Int {
        return root.treeByteToLineIdx(byteIdx, lineType);
    }

    inline function _lineToByteIdx(lineIdx:Int, lineType:LineType):Int {
        return root.treeLineToByteIdx(lineIdx, lineType);
    }

    @:allow(ropey) inline function _isRelevantCrlfSplit(byteIdx:Int, lineType:LineType):Bool {
        return root.isRelevantCrlfSplit(byteIdx, lineType);
    }

}
