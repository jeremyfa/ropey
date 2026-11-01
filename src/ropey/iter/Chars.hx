// Ported from ropey 2.0.0-beta.1: src/iter.rs (`Chars`)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey.iter;

import haxe.io.Bytes;
import ropey.StrUtils;
import ropey.tree.Node;
import ropey.tree.TextInfo;

/**
 * An iterator over the chars (code points) of a text.
 *
 * `next()` and `prev()` return -1 (Rust's `None`) at the end.
 *
 * Like in Rust, the iterator must not be used after the rope it comes from is
 * modified.
 */
class Chars {

    var cursor:ChunkCursor;
    var currentChunk:Bytes;
    var currentChunkStart:Int;
    var currentChunkLen:Int;
    @:allow(ropey.iter.CharIndices) var chunkByteIdx:Int; // Byte index of the start of the current chunk.
    @:allow(ropey.iter.CharIndices) var byteIdxInChunk:Int;
    var atEnd:Bool;
    @:allow(ropey.iter.CharIndices) var isReversed:Bool;

    function new() {}

    /**
     * Advances the iterator forward and returns the next char, or -1.
     *
     * Note: this is effectively the same as `next()` from Haxe and Rust
     * iterators, except that it goes backwards when the iterator is reversed.
     */
    public inline function next():Int {
        return isReversed ? prevImpl() : nextImpl();
    }

    /**
     * Advances the iterator backwards and returns the previous char, or -1.
     */
    public inline function prev():Int {
        return isReversed ? nextImpl() : prevImpl();
    }

    /**
     * Reverses the direction of iteration (in place, and returns this
     * iterator).
     */
    public function reversed():Chars {
        isReversed = !isReversed;
        return this;
    }

    /**
     * The lower bound of Rust's `size_hint()`: the minimum number of chars
     * left (1 to 4 bytes per char).
     */
    public function sizeHint():Int {
        return (remainingBytes() + 3) >> 2;
    }

    /**
     * The upper bound of Rust's `size_hint()`: the maximum number of chars
     * left.
     */
    public function sizeHintMax():Int {
        return remainingBytes();
    }

    inline function remainingBytes():Int {
        return isReversed ? cursor.byteOffset() + byteIdxInChunk : cursor.byteOffsetFromEnd() - byteIdxInChunk;
    }

    /**
     * A copy of this iterator (Rust's `Clone`).
     */
    public function clone():Chars {
        var result = new Chars();
        result.cursor = cursor.clone();
        result.currentChunk = currentChunk;
        result.currentChunkStart = currentChunkStart;
        result.currentChunkLen = currentChunkLen;
        result.chunkByteIdx = chunkByteIdx;
        result.byteIdxInChunk = byteIdxInChunk;
        result.atEnd = atEnd;
        result.isReversed = isReversed;
        return result;
    }

    /**
     * Haxe iteration (`for (x in iter)`), going in the current direction
     * (like Rust's `Iterator` impl). Consumes this iterator.
     */
    public inline function iterator():CharsIterator {
        return new CharsIterator(this);
    }

    //---------------------------------------------------------

    @:allow(ropey)
    static function create(node:Node, nodeInfo:TextInfo, rangeStart:Int, rangeEnd:Int, atByteIdx:Int):Chars {
        var cursor = ChunkCursor.create(node, nodeInfo, rangeStart, rangeEnd, atByteIdx);
        var byteOffset = cursor.byteOffset();
        var chunk = cursor.chunkBytes();
        var chunkStart = cursor.chunkStart();
        var chunkEnd = cursor.chunkEnd();

        if (!StrUtils.isCharBoundary(atByteIdx - rangeStart - byteOffset, chunk, chunkStart, chunkEnd)) {
            throw new RopeyException(NonCharBoundary);
        }

        var result = new Chars();
        result.cursor = cursor;
        result.currentChunk = chunk;
        result.currentChunkStart = chunkStart;
        result.currentChunkLen = chunkEnd - chunkStart;
        result.chunkByteIdx = byteOffset;
        result.byteIdxInChunk = atByteIdx - rangeStart - byteOffset;
        result.atEnd = atByteIdx == rangeEnd;
        result.isReversed = false;
        return result;
    }

    @:allow(ropey)
    static function fromStr(text:Bytes, start:Int, end:Int, atByteIdx:Int):Chars {
        if (!StrUtils.isCharBoundary(atByteIdx, text, start, end)) {
            throw new RopeyException(NonCharBoundary);
        }

        var result = new Chars();
        result.cursor = ChunkCursor.fromStr(text, start, end);
        result.currentChunk = text;
        result.currentChunkStart = start;
        result.currentChunkLen = end - start;
        result.chunkByteIdx = 0;
        result.byteIdxInChunk = atByteIdx;
        result.atEnd = atByteIdx == end - start;
        result.isReversed = false;
        return result;
    }

    function nextImpl():Int {
        if (atEnd) {
            return -1;
        }

        var char = Utf8.codePointAt(currentChunk, currentChunkStart + byteIdxInChunk);

        byteIdxInChunk = StrUtils.ceilCharBoundary(byteIdxInChunk + 1, currentChunk, currentChunkStart, currentChunkStart + currentChunkLen);

        while (byteIdxInChunk >= currentChunkLen) {
            if (cursor.next()) {
                chunkByteIdx += currentChunkLen;
                byteIdxInChunk -= currentChunkLen;
                currentChunk = cursor.chunkBytes();
                currentChunkStart = cursor.chunkStart();
                currentChunkLen = cursor.chunkLen();
            }
            else {
                atEnd = true;
                break;
            }
        }

        return char;
    }

    function prevImpl():Int {
        while (byteIdxInChunk == 0) {
            if (cursor.prev()) {
                currentChunk = cursor.chunkBytes();
                currentChunkStart = cursor.chunkStart();
                currentChunkLen = cursor.chunkLen();
                chunkByteIdx -= currentChunkLen;
                byteIdxInChunk += currentChunkLen;
            }
            else {
                return -1;
            }
        }

        atEnd = false;
        byteIdxInChunk = StrUtils.floorCharBoundary(byteIdxInChunk - 1, currentChunk, currentChunkStart, currentChunkStart + currentChunkLen);
        return Utf8.codePointAt(currentChunk, currentChunkStart + byteIdxInChunk);
    }

}

/**
 * Adapter for `Chars.iterator()`.
 */
class CharsIterator {

    var iter:Chars;
    var nextValue:Int;

    public inline function new(iter:Chars) {
        this.iter = iter;
        nextValue = iter.next();
    }

    public inline function hasNext():Bool {
        return nextValue != -1;
    }

    public inline function next():Int {
        var value = nextValue;
        nextValue = iter.next();
        return value;
    }

}
