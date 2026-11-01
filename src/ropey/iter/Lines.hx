// Ported from ropey 2.0.0-beta.1: src/iter.rs (`Lines`)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey.iter;

import haxe.io.Bytes;
import ropey.StrUtils;
import ropey.tree.Node;
import ropey.tree.TextInfo;

/**
 * An iterator over the lines of a text, according to a line type.
 *
 * `next()` and `prev()` return null at the end.
 *
 * Like in Rust, the iterator must not be used after the rope it comes from is
 * modified.
 */
class Lines {

    var cursor:ChunkCursor;
    var lineType:LineType;

    // The total line count in the iterator.
    var totalLines:Int;

    // Byte index we're at within the current leaf chunk.
    var leafByteIdx:Int;

    // The current line index.
    var currentLineIdx:Int;

    var isReversed:Bool;

    function new() {}

    /**
     * Advances the iterator forward and returns the next line, or null.
     *
     * Note: this is effectively the same as `next()` from Haxe and Rust
     * iterators, except that it goes backwards when the iterator is reversed.
     */
    public inline function next():Null<RopeSlice> {
        return isReversed ? prevImpl() : nextImpl();
    }

    /**
     * Advances the iterator backwards and returns the previous line, or null.
     */
    public inline function prev():Null<RopeSlice> {
        return isReversed ? nextImpl() : prevImpl();
    }

    /**
     * Reverses the direction of iteration (in place, and returns this
     * iterator).
     */
    public function reversed():Lines {
        isReversed = !isReversed;
        return this;
    }

    /**
     * Number of lines left (Rust's exact `size_hint()`).
     */
    public function remaining():Int {
        return isReversed ? currentLineIdx : totalLines - currentLineIdx;
    }

    /**
     * Rust's exact `size_hint()` (same as `remaining()`).
     */
    public inline function sizeHint():Int {
        return remaining();
    }

    /**
     * A copy of this iterator (Rust's `Clone`).
     */
    public function clone():Lines {
        var result = new Lines();
        result.cursor = cursor.clone();
        result.lineType = lineType;
        result.totalLines = totalLines;
        result.leafByteIdx = leafByteIdx;
        result.currentLineIdx = currentLineIdx;
        result.isReversed = isReversed;
        return result;
    }

    /**
     * Haxe iteration (`for (x in iter)`), going in the current direction
     * (like Rust's `Iterator` impl). Consumes this iterator.
     */
    public inline function iterator():LinesIterator {
        return new LinesIterator(this);
    }

    //-----------------------------------------------------

    @:allow(ropey)
    static function create(node:Node, nodeInfo:TextInfo, rangeStart:Int, rangeEnd:Int, atLineIdx:Int, lineType:LineType):Lines {
        var slice = RopeSlice.create(node, nodeInfo, rangeStart, rangeEnd);
        var totalLines = slice.lenLines(lineType);
        if (atLineIdx < 0 || atLineIdx > totalLines) {
            throw new RopeyException(OutOfBounds);
        }
        var atByteIdx = slice.lineToByteIdx(atLineIdx, lineType);

        var cursor = ChunkCursor.create(node, nodeInfo, rangeStart, rangeEnd, rangeStart + atByteIdx);
        var leafByteIdx = atByteIdx - cursor.byteOffset();

        var lines = new Lines();
        lines.cursor = cursor;
        lines.lineType = lineType;
        lines.totalLines = totalLines;
        lines.leafByteIdx = leafByteIdx;
        lines.currentLineIdx = atLineIdx;
        lines.isReversed = false;
        return lines;
    }

    @:allow(ropey)
    static function fromStr(text:Bytes, start:Int, end:Int, atLineIdx:Int, lineType:LineType):Lines {
        var totalLines = StrUtils.linesCountBreaks(text, start, end, lineType) + 1;
        var atByteIdx = StrUtils.linesToByteIdx(text, start, end, atLineIdx, lineType);

        var lines = new Lines();
        lines.cursor = ChunkCursor.fromStr(text, start, end);
        lines.lineType = lineType;
        lines.totalLines = totalLines;
        lines.leafByteIdx = atByteIdx;
        lines.currentLineIdx = atLineIdx;
        lines.isReversed = false;
        return lines;
    }

    function nextImpl():Null<RopeSlice> {
        if (currentLineIdx >= totalLines) {
            return null;
        }

        // Try to advance within the current chunk.
        var chunk = cursor.chunkBytes();
        var chunkStart = cursor.chunkStart();
        var chunkEnd = cursor.chunkEnd();
        var chunkLen = chunkEnd - chunkStart;
        if (leafByteIdx < chunkLen) {
            var nextIdx = leafByteIdx + StrUtils.linesToByteIdx(chunk, chunkStart + leafByteIdx, chunkEnd, 1, lineType);
            if (nextIdx < chunkLen
                || StrUtils.endsWithLineBreak(chunk, chunkStart, chunkEnd, lineType)
                || cursor.atLast()) {
                var line = cursor.chunkSlice().slice(leafByteIdx, nextIdx);
                leafByteIdx = nextIdx;
                currentLineIdx += 1;
                return line;
            }
        }

        // Need to advance to another chunk.
        var startIdx = cursor.byteOffset() + leafByteIdx;
        var node = cursor.nextWithLineBoundary(lineType);
        if (node != null) {
            var info = cursor.boundaryInfo;
            var offset = cursor.boundaryOffset;
            leafByteIdx = StrUtils.linesToByteIdx(cursor.chunkBytes(), cursor.chunkStart(), cursor.chunkEnd(), 1, lineType);
            var endIdx = cursor.byteOffset() + leafByteIdx;
            currentLineIdx += 1;
            var start = startIdx - offset;
            var end = endIdx - offset;
            return RopeSlice.create(node, info, start, end);
        }
        else {
            // Can't advance, which means we're already at the end.  But
            // since we're not at the last line (that's caught at the start
            // of this function) that means there's a final empty line to
            // return.
            currentLineIdx += 1;
            return cursor.chunkSlice().slice(0, 0);
        }
    }

    function prevImpl():Null<RopeSlice> {
        if (currentLineIdx == 0) {
            return null;
        }

        var chunkSlice = cursor.chunkSlice();
        var chunk = cursor.chunkBytes();
        var chunkStart = cursor.chunkStart();
        var chunkEnd = cursor.chunkEnd();

        // Special case to handle ending line break properly.
        if (currentLineIdx == totalLines
            && (chunkEnd == chunkStart || StrUtils.endsWithLineBreak(chunk, chunkStart, chunkEnd, lineType))) {
            currentLineIdx -= 1;
            return chunkSlice.slice(0, 0);
        }

        // Try to backtrack within the current chunk.
        if (leafByteIdx > 0) {
            var trimmedEnd = StrUtils.trimTrailingLineBreak(chunk, chunkStart, chunkStart + leafByteIdx, lineType);
            var prevIdx = StrUtils.lastLineStartByteIdx(chunk, chunkStart, chunkStart + trimmedEnd, lineType);
            if (prevIdx > 0 || cursor.atFirst()) {
                var line = chunkSlice.slice(prevIdx, leafByteIdx);
                leafByteIdx = prevIdx;
                currentLineIdx -= 1;
                return line;
            }
        }

        // Need to backtrack to another chunk.
        var endIdx = cursor.byteOffset() + leafByteIdx;
        var node = cursor.prevWithLineBoundary(lineType);
        if (node != null) {
            var info = cursor.boundaryInfo;
            var offset = cursor.boundaryOffset;
            leafByteIdx = StrUtils.lastLineStartByteIdx(cursor.chunkBytes(), cursor.chunkStart(), cursor.chunkEnd(), lineType);
            var startIdx = cursor.byteOffset() + leafByteIdx;
            currentLineIdx -= 1;
            var start = startIdx - offset;
            var end = endIdx - offset;
            return RopeSlice.create(node, info, start, end);
        }
        else {
            // Can't advance, which means we're already at the start.  But
            // that shouldn't be possible because that's caught at the start
            // of this function.
            throw 'internal error: entered unreachable code';
        }
    }

}

/**
 * Adapter for `Lines.iterator()`.
 */
class LinesIterator {

    var iter:Lines;
    var nextValue:Null<RopeSlice>;

    public inline function new(iter:Lines) {
        this.iter = iter;
        nextValue = iter.next();
    }

    public inline function hasNext():Bool {
        return nextValue != null;
    }

    public inline function next():Null<RopeSlice> {
        var value = nextValue;
        nextValue = iter.next();
        return value;
    }

}
