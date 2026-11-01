// Ported from ropey 2.0.0-beta.1: src/iter.rs (`Bytes`)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey.iter;

import ropey.tree.Node;
import ropey.tree.TextInfo;

/**
 * An iterator over the bytes of a text.
 *
 * `next()` and `prev()` return -1 (Rust's `None`) at the end.
 *
 * Like in Rust, the iterator must not be used after the rope it comes from is
 * modified.
 */
class Bytes {

    var cursor:ChunkCursor;
    var currentChunk:haxe.io.Bytes;
    var currentChunkStart:Int;
    var currentChunkLen:Int;
    var chunkByteIdx:Int; // Byte index of the start of the current chunk.
    var byteIdxInChunk:Int;
    var atEnd:Bool;
    var isReversed:Bool;

    function new() {}

    /**
     * Advances the iterator forward and returns the next byte, or -1.
     *
     * Note: this is effectively the same as `next()` from Haxe and Rust
     * iterators, except that it goes backwards when the iterator is reversed.
     */
    public inline function next():Int {
        return isReversed ? prevImpl() : nextImpl();
    }

    /**
     * Advances the iterator backwards and returns the previous byte, or -1.
     */
    public inline function prev():Int {
        return isReversed ? nextImpl() : prevImpl();
    }

    /**
     * Reverses the direction of iteration (in place, and returns this
     * iterator).
     */
    public function reversed():Bytes {
        isReversed = !isReversed;
        return this;
    }

    /**
     * The number of bytes left (Rust's exact `size_hint()`).
     */
    public function sizeHint():Int {
        return isReversed ? cursor.byteOffset() + byteIdxInChunk : cursor.byteOffsetFromEnd() - byteIdxInChunk;
    }

    /**
     * A copy of this iterator (Rust's `Clone`).
     */
    public function clone():Bytes {
        var result = new Bytes();
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
    public inline function iterator():BytesIterator {
        return new BytesIterator(this);
    }

    //---------------------------------------------------------

    @:allow(ropey)
    static function create(node:Node, nodeInfo:TextInfo, rangeStart:Int, rangeEnd:Int, atByteIdx:Int):Bytes {
        var cursor = ChunkCursor.create(node, nodeInfo, rangeStart, rangeEnd, atByteIdx);
        var byteOffset = cursor.byteOffset();

        var result = new Bytes();
        result.cursor = cursor;
        result.currentChunk = cursor.chunkBytes();
        result.currentChunkStart = cursor.chunkStart();
        result.currentChunkLen = cursor.chunkLen();
        result.chunkByteIdx = byteOffset;
        result.byteIdxInChunk = atByteIdx - rangeStart - byteOffset;
        result.atEnd = atByteIdx == rangeEnd;
        result.isReversed = false;
        return result;
    }

    @:allow(ropey)
    static function fromStr(text:haxe.io.Bytes, start:Int, end:Int, atByteIdx:Int):Bytes {
        var result = new Bytes();
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

        var byte = currentChunk.get(currentChunkStart + byteIdxInChunk);

        byteIdxInChunk += 1;
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

        return byte;
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
        byteIdxInChunk -= 1;
        return currentChunk.get(currentChunkStart + byteIdxInChunk);
    }

}

/**
 * Adapter for `Bytes.iterator()`.
 */
class BytesIterator {

    var iter:Bytes;
    var nextValue:Int;

    public inline function new(iter:Bytes) {
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
