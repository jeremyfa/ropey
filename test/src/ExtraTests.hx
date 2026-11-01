// Ported from ropey 2.0.0-beta.1: src/extra.rs (tests)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

import TestUtil.*;
import ropey.Esoterica.*;
import ropey.Rope;

class ExtraTests {

    public function new() {}

    public function test_ropes_are_instances_01() {
        var r1 = Rope.fromStr("Hello there!");
        var r2 = r1.clone();

        isTrue(ropesAreInstances(r1, r2));
    }

    public function test_ropes_are_instances_02() {
        var r1 = Rope.fromStr("Hello there!");
        var r2 = {
            var r2 = r1.clone();
            r2.insert(0, "a");
            r2;
        };
        var r3 = {
            var s = r1.sliceFrom(1);
            disconnectSlice(s);
        };

        isTrue(!ropesAreInstances(r1, r2));
        isTrue(!ropesAreInstances(r1, r3));
    }

    public function test_disconnect_slice_01() {
        var r = Rope.fromStr("Hello there!");

        var s1 = r.sliceFrom(0);
        var s2 = r.sliceFrom(1);
        var s3 = r.slice(0, 8);
        var s4 = r.slice(1, 8);
        eq(s1, "Hello there!");
        eq(s2, "ello there!");
        eq(s3, "Hello th");
        eq(s4, "ello th");

        var r1 = disconnectSlice(s1);
        var r2 = disconnectSlice(s2);
        var r3 = disconnectSlice(s3);
        var r4 = disconnectSlice(s4);
        eq(r1, "Hello there!");
        eq(r2, "ello there!");
        eq(r3, "Hello th");
        eq(r4, "ello th");
    }

    public function test_disconnect_slice_02() {
        var r = Rope.fromStr("Hello there!");
        var s = r.slice(1, 8);

        var r1 = disconnectSlice(s);
        eq(r1, "ello th");

        r1.insert(0, "F");
        r1.insert(5, "w");
        r1.insert(9, "ing!");
        eq(r1, "Fellow thing!");

        // The original rope is untouched (copy on write of the shared tree).
        eq(r, "Hello there!");
    }

}
