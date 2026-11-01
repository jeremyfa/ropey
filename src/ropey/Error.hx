// Ported from ropey 2.0.0-beta.1: src/lib.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

/**
 * Ropey's error type.
 *
 * Indicates the cause of a failed operation. Panicking methods throw a
 * `RopeyException` carrying one of these values, `try*()` methods return it
 * (or `null` on success).
 */
enum abstract Error(Int) {

    /**
     * The byte index(s) given were not on a char boundary, but needed to be
     * for the given operation.
     */
    var NonCharBoundary = 1;

    /**
     * The index(s) given exceeded the size of the text.
     */
    var OutOfBounds = 2;

    /**
     * The range given was intrinsically invalid (e.g. inverted).
     */
    var InvalidRange = 3;

    public function message():String {
        return switch (cast this : Error) {
            case NonCharBoundary: 'byte index is not on a char boundary';
            case OutOfBounds: 'index is out of bounds';
            case InvalidRange: 'index range is invalid: end < start';
        }
    }

}
