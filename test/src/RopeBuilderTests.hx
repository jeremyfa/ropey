// Ported from ropey 2.0.0-beta.1: src/rope_builder.rs (tests)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

import TestUtil.*;
import ropey.RopeBuilder;

class RopeBuilderTests {

    // 127 bytes, 103 chars, 4 lines
    static inline final TEXT = "Hello there!  How're you doing?\r\nIt's "
        + "a fine day, isn't it?\r\nAren't you glad "
        + "we're alive?\r\nこんにちは、みんなさん！";

    public function new() {}

    public function test_rope_builder_01() {
        var b = new RopeBuilder();

        b.append("Hello there!  How're you doing?\r");
        b.append("\nIt's a fine ");
        b.append("d");
        b.append("a");
        b.append("y,");
        b.append(" ");
        b.append("isn't it?");
        b.append("\r");
        b.append("\nAren't you ");
        b.append("glad we're alive?\r");
        b.append("\n");
        b.append("こんにち");
        b.append("は、みんなさ");
        b.append("ん！");

        var r = b.finish();

        eq(r, TEXT);
        r.assertInvariants();
    }

    public function test_rope_builder_default_01() {
        var b = new RopeBuilder();

        b.append("Hello there!  How're you doing?\r");
        b.append("\nIt's a fine day, isn't it?\r\nAren't you ");
        b.append("glad we're alive?\r\nこんにちは、みんなさん！");

        var r = b.finish();

        eq(r, TEXT);
        r.assertInvariants();
    }

}
