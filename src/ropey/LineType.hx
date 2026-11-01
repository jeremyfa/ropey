// Ported from ropey 2.0.0-beta.1: src/lib.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

/**
 * Specifies a set of line breaks to be recognized in Ropey's line-based APIs.
 *
 * Ropey can track more than one line break convention simultaneously, and
 * `LineType` is used to specify which convention to use for a given function
 * call.
 *
 * This port tracks the two conventions enabled in gpui-kit's build of ropey
 * (features `metric_lines_lf` and the default `metric_lines_lf_cr`).
 */
enum abstract LineType(Int) {

    /**
     * - LF (Line Feed)
     * - CRLF (Carriage Return + Line Feed): implicitly recognized, due to
     *   CR being ignored.
     */
    var LF = 0;

    /**
     * - LF (Line Feed)
     * - CR (Carriage Return)
     * - CRLF (Carriage Return + Line Feed)
     */
    var LF_CR = 1;

}
