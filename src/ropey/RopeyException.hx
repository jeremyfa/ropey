// Ported from ropey 2.0.0-beta.1: src/lib.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

/**
 * Thrown where ropey panics: invalid indices, ranges or char boundaries.
 */
class RopeyException extends haxe.Exception {

    public final error:Error;

    public function new(error:Error, ?message:String) {
        super(message != null ? message : error.message());
        this.error = error;
    }

}
