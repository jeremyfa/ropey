// Ported from ropey 2.0.0-beta.1: src/str_utils.rs (tests)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

import TestUtil.*;
import ropey.StrUtils;

class StrUtilsTests {

    public function new() {}

    static function startsWithLf(s:String):Bool {
        var b = bytesOf(s);
        return StrUtils.startsWithLf(b, 0, b.length);
    }

    static function endsWithCr(s:String):Bool {
        var b = bytesOf(s);
        return StrUtils.endsWithCr(b, 0, b.length);
    }

    public function test_starts_with_lf_01() {
        eq(false, startsWithLf(""));
        eq(false, startsWithLf("Hello!"));
        eq(true, startsWithLf("\n"));
        eq(true, startsWithLf("\nHello!"));
    }

    public function test_ends_with_cr_01() {
        eq(false, endsWithCr(""));
        eq(false, endsWithCr("Hello!"));
        eq(true, endsWithCr("\r"));
        eq(true, endsWithCr("Hello!\r"));
    }

}
