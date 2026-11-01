// Ported from ropey 2.0.0-beta.1: src/extra.rs (`extra::esoterica`)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

/**
 * Esoteric functionality.
 *
 * **Warning:** these functions expose you to esoterica of Ropey's internal
 * data model, and take you off the beaten path of Ropey's intended API
 * semantics.
 */
class Esoterica {

    /**
     * Returns whether two ropes are instances of the same underlying data:
     * clones of each other with no edits since, and the same byte range.
     *
     * Runs in O(1) time.
     */
    public static function ropesAreInstances(a:Rope, b:Rope):Bool {
        if (a.rangeStart != b.rangeStart || a.rangeEnd != b.rangeEnd) {
            return false;
        }

        return a.root == b.root;
    }

    /**
     * Creates a "disconnected slice": a `Rope` sharing the data of a slice,
     * which is trimmed to a normal rope on its first edit. Returns null for a
     * slice made from a string.
     *
     * Runs in O(1) time.
     */
    public static function disconnectSlice(slice:RopeSlice):Null<Rope> {
        if (slice.str != null) {
            return null;
        }
        slice.root.rc++;
        var rope = new Rope(slice.root, slice.rootInfo);
        rope.rangeStart = slice.rangeStart;
        rope.rangeEnd = slice.rangeEnd;
        return rope;
    }

}
