// Ported from ropey 2.0.0-beta.1: src/tree/mod.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey.tree;

/**
 * Tree size constants.
 *
 * Define `ropey_small_chunks` to get the small sizes ropey uses in its own
 * unit tests (`cfg(test)` or the `__dev__small_chunks` feature).
 */
class Constants {

    #if ropey_small_chunks
    public static inline final MAX_CHILDREN:Int = 5;
    public static inline final MIN_CHILDREN:Int = 2;
    public static inline final MAX_TEXT_SIZE:Int = 15;
    public static inline final MIN_TEXT_SIZE:Int = 7;
    #else
    public static inline final MAX_CHILDREN:Int = 16;
    public static inline final MIN_CHILDREN:Int = 7;
    public static inline final MAX_TEXT_SIZE:Int = 1024;
    public static inline final MIN_TEXT_SIZE:Int = 480; // (MAX_TEXT_SIZE / 2) - (MAX_TEXT_SIZE / 32)
    #end

}
