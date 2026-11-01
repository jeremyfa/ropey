// Ported from ropey 2.0.0-beta.1: src/iter.rs (`Chunks`)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey.iter;

import haxe.io.Bytes;
import ropey.tree.Constants.MAX_TEXT_SIZE;
import ropey.tree.Node;
import ropey.tree.TextInfo;

/**
 * An iterator over the chunks of a text.
 *
 * `next()` and `prev()` return the chunk decoded to a Haxe string, or null at
 * the end. `nextRaw()` and `prevRaw()` give access to the UTF-8 bytes of the
 * chunk instead (`rawBytes[rawStart...rawEnd]`) without allocating.
 *
 * Like in Rust, the iterator must not be used after the rope it comes from is
 * modified.
 */
class Chunks {

    var cursor:ChunkCursor;
    var atEnd:Bool;
    var isReversed:Bool;

    /**
     * For `chunksAt()`: the byte index of the beginning of the first chunk to
     * be yielded (second element of Rust's returned tuple).
     */
    public var startByteIdx:Int = 0;

    /**
     * The chunk found by the last successful `nextRaw()` / `prevRaw()`.
     */
    public var rawBytes(default, null):Bytes;

    public var rawStart(default, null):Int;

    public var rawEnd(default, null):Int;

    function new() {}

    /**
     * Advances the iterator forward and returns the next chunk, or null.
     *
     * Note: this is effectively the same as `next()` from Haxe and Rust
     * iterators, except that it goes backwards when the iterator is reversed.
     */
    public function next():Null<String> {
        return nextRaw() ? Utf8.decode(rawBytes, rawStart, rawEnd) : null;
    }

    /**
     * Advances the iterator backwards and returns the previous chunk, or
     * null.
     */
    public function prev():Null<String> {
        return prevRaw() ? Utf8.decode(rawBytes, rawStart, rawEnd) : null;
    }

    /**
     * Like `next()`, but stores the chunk bytes in `rawBytes`, `rawStart`
     * and `rawEnd` instead of decoding it. Returns false at the end.
     */
    public inline function nextRaw():Bool {
        return isReversed ? prevImpl() : nextImpl();
    }

    /**
     * Like `prev()`, see `nextRaw()`.
     */
    public inline function prevRaw():Bool {
        return isReversed ? nextImpl() : prevImpl();
    }

    /**
     * Reverses the direction of iteration (in place, and returns this
     * iterator).
     */
    public function reversed():Chunks {
        isReversed = !isReversed;
        return this;
    }

    /**
     * The lower bound of Rust's `size_hint()`: a conservative minimum of the
     * number of chunks left (Rust gives no upper bound, except 1 for a slice
     * made from a string).
     */
    public function sizeHint():Int {
        if (cursor.isFromStrSlice()) {
            return 0;
        }

        var byteLen = if (isReversed) {
            atEnd ? cursor.byteOffset() + cursor.chunkLen() : cursor.byteOffset();
        }
        else {
            atEnd ? 0 : cursor.byteOffsetFromEnd();
        }

        return Std.int((byteLen + MAX_TEXT_SIZE - 1) / MAX_TEXT_SIZE);
    }

    /**
     * A copy of this iterator (Rust's `Clone`).
     */
    public function clone():Chunks {
        var result = new Chunks();
        result.cursor = cursor.clone();
        result.atEnd = atEnd;
        result.isReversed = isReversed;
        result.startByteIdx = startByteIdx;
        result.rawBytes = rawBytes;
        result.rawStart = rawStart;
        result.rawEnd = rawEnd;
        return result;
    }

    /**
     * Haxe iteration (`for (x in iter)`), going in the current direction
     * (like Rust's `Iterator` impl). Consumes this iterator.
     */
    public inline function iterator():ChunksIterator {
        return new ChunksIterator(this);
    }

    //---------------------------------------------------------

    @:allow(ropey)
    static function create(node:Node, nodeInfo:TextInfo, rangeStart:Int, rangeEnd:Int, atByteIdx:Int):Chunks {
        var cursor = ChunkCursor.create(node, nodeInfo, rangeStart, rangeEnd, atByteIdx);
        var byteOffset = rangeStart + cursor.byteOffset();
        var atEnd = atByteIdx == rangeEnd;

        var chunks = new Chunks();
        chunks.cursor = cursor;
        chunks.atEnd = atEnd;
        chunks.isReversed = false;
        chunks.startByteIdx = atEnd ? atByteIdx : byteOffset;
        return chunks;
    }

    @:allow(ropey)
    static function fromStr(text:Bytes, start:Int, end:Int, atByteIdx:Int):Chunks {
        var cursor = ChunkCursor.fromStr(text, start, end);
        var atEnd = atByteIdx == end - start;

        var chunks = new Chunks();
        chunks.cursor = cursor;
        chunks.atEnd = atEnd;
        chunks.isReversed = false;
        chunks.startByteIdx = atEnd ? atByteIdx : 0;
        return chunks;
    }

    function nextImpl():Bool {
        while (true) {
            if (atEnd) {
                return false;
            }
            else {
                var b = cursor.chunkBytes();
                var s = cursor.chunkStart();
                var e = cursor.chunkEnd();
                atEnd = !cursor.next();

                if (e > s) {
                    rawBytes = b;
                    rawStart = s;
                    rawEnd = e;
                    return true;
                }
            }
        }
    }

    function prevImpl():Bool {
        while (true) {
            if (atEnd) {
                atEnd = false;
            }
            else if (!cursor.prev()) {
                return false;
            }

            var s = cursor.chunkStart();
            var e = cursor.chunkEnd();
            if (e > s) {
                rawBytes = cursor.chunkBytes();
                rawStart = s;
                rawEnd = e;
                return true;
            }
        }
    }

}

/**
 * Adapter for `Chunks.iterator()`.
 */
class ChunksIterator {

    var iter:Chunks;
    var nextValue:Null<String>;

    public inline function new(iter:Chunks) {
        this.iter = iter;
        nextValue = iter.next();
    }

    public inline function hasNext():Bool {
        return nextValue != null;
    }

    public inline function next():Null<String> {
        var value = nextValue;
        nextValue = iter.next();
        return value;
    }

}
