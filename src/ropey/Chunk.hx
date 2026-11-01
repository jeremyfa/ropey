// Ported from ropey 2.0.0-beta.1: src/shared_impl.rs (`chunk()` return value)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

import haxe.io.Bytes;

/**
 * A chunk returned by `chunk()` / `getChunk()`: Rust returns
 * `(&str, usize)`, the chunk text and the byte index of its start.
 *
 * The chunk text is `bytes[start...end]` (UTF-8, valid until the rope is
 * modified), `text()` decodes it to a Haxe string.
 */
class Chunk {

    public final bytes:Bytes;

    public final start:Int;

    public final end:Int;

    /**
     * Byte index of the start of the chunk within the rope or slice.
     */
    public final byteIdx:Int;

    public function new(bytes:Bytes, start:Int, end:Int, byteIdx:Int) {
        this.bytes = bytes;
        this.start = start;
        this.end = end;
        this.byteIdx = byteIdx;
    }

    /**
     * Length of the chunk in bytes.
     */
    public inline function len():Int {
        return end - start;
    }

    /**
     * Byte at the given index of the chunk.
     */
    public inline function byte(idx:Int):Int {
        return bytes.get(start + idx);
    }

    /**
     * The chunk text, decoded to a Haxe string.
     */
    public inline function text():String {
        return Utf8.decode(bytes, start, end);
    }

    public function toString():String {
        return text();
    }

}
