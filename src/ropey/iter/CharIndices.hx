// Ported from ropey 2.0.0-beta.1: src/iter.rs (`CharIndices`)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey.iter;

/**
 * An iterator over the chars of a text and their byte positions.
 *
 * Rust yields `(usize, char)` tuples: here `next()` and `prev()` return the
 * char (or -1 at the end) and store its byte position in `index`.
 */
class CharIndices {

    var chars:Chars;

    /**
     * Byte index of the char returned by the last `next()` / `prev()`.
     */
    public var index(default, null):Int = -1;

    @:allow(ropey)
    function new(iter:Chars) {
        chars = iter;
    }

    /**
     * Advances the iterator forward and returns the next char (or -1), its
     * byte index going to `index`.
     */
    public function next():Int {
        if (chars.isReversed) {
            var ch = chars.next();
            if (ch != -1)
                index = offset();
            return ch;
        }
        else {
            var off = offset();
            var ch = chars.next();
            if (ch != -1)
                index = off;
            return ch;
        }
    }

    /**
     * Advances the iterator backwards and returns the previous char (or -1),
     * its byte index going to `index`.
     */
    public function prev():Int {
        if (chars.isReversed) {
            var off = offset();
            var ch = chars.prev();
            if (ch != -1)
                index = off;
            return ch;
        }
        else {
            var ch = chars.prev();
            if (ch != -1)
                index = offset();
            return ch;
        }
    }

    /**
     * Reverses the direction of iteration (in place, and returns this
     * iterator).
     */
    public function reversed():CharIndices {
        chars.reversed();
        return this;
    }

    /**
     * Rust's `size_hint()` lower bound (see `Chars.sizeHint()`).
     */
    public inline function sizeHint():Int {
        return chars.sizeHint();
    }

    /**
     * Rust's `size_hint()` upper bound (see `Chars.sizeHintMax()`).
     */
    public inline function sizeHintMax():Int {
        return chars.sizeHintMax();
    }

    /**
     * A copy of this iterator (Rust's `Clone`).
     */
    public function clone():CharIndices {
        var result = new CharIndices(chars.clone());
        result.index = index;
        return result;
    }

    /**
     * Haxe iteration (`for (byteIdx => char in iter)`), going in the current
     * direction. Consumes this iterator.
     */
    public inline function keyValueIterator():CharIndicesIterator {
        return new CharIndicesIterator(this);
    }

    inline function offset():Int {
        return chars.chunkByteIdx + chars.byteIdxInChunk;
    }

}

/**
 * Adapter for `CharIndices.keyValueIterator()`.
 */
class CharIndicesIterator {

    var iter:CharIndices;
    var nextChar:Int;
    var nextIndex:Int;

    public inline function new(iter:CharIndices) {
        this.iter = iter;
        nextChar = iter.next();
        nextIndex = iter.index;
    }

    public inline function hasNext():Bool {
        return nextChar != -1;
    }

    public inline function next():{key:Int, value:Int} {
        var result = {key: nextIndex, value: nextChar};
        nextChar = iter.next();
        nextIndex = iter.index;
        return result;
    }

}
