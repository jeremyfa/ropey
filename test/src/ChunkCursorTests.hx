// Ported from ropey 2.0.0-beta.1: src/chunk_cursor.rs (tests)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

import TestUtil.*;
import ropey.LineType;
import ropey.Rope;
import ropey.RopeBuilder;
import ropey.RopeSlice;

@:access(ropey.ChunkCursor)
class ChunkCursorTests {

    public function new() {}

    function helloWorldRepeatRope():Rope {
        var rb = new RopeBuilder();
        for (_ in 0...4) {
            rb._appendChunkAsLeaf("Hello ");
            rb._appendChunkAsLeaf("world!");
        }
        return rb.finish();
    }

    function linesText():String {
        var text = new StringBuf();
        text.add("\r\n");
        for (_ in 0...16) {
            text.add("Hello there!  How're you doing?  It's a fine day, "
                + "isn't it?  Aren't you glad we're alive?\r\n"
                + "こんにちは！元気ですか？日はいいですね。"
                + "私たちが生きだって嬉しいではないか？\r\n");
        }
        return text.toString();
    }

    public function test_chunk_cursor_01() {
        var r = Rope.fromStr(TEXT);

        var text = TEXT;
        var cursor = r.chunkCursor();
        var stack = [];

        // Forward.
        var byteOffset = 0;
        while (true) {
            var chunk = cursor.chunk();
            eq(bto(text, blen(chunk)), chunk);
            eq(cursor.byteOffset(), byteOffset);
            stack.push(chunk);
            byteOffset += blen(chunk);
            text = bfrom(text, blen(chunk));

            if (!cursor.next()) {
                break;
            }
        }
        eq("", text);
        eq(cursor.byteOffset(), blen(TEXT) - blen(cursor.chunk()));

        // Backward.
        while (true) {
            var chunk = cursor.chunk();
            eq(stack.pop(), chunk);

            if (!cursor.prev()) {
                break;
            }
        }
        eq(0, stack.length);
    }

    public function test_chunk_cursor_02() {
        var r = Rope.fromStr(TEXT);

        var textSlice = bsub(TEXT, 3, 45);
        var text = textSlice;
        var s = r.slice(3, 45);
        var cursor = s.chunkCursor();
        var stack = [];

        // Forward.
        var byteOffset = 0;
        while (true) {
            var chunk = cursor.chunk();
            eq(bto(text, blen(chunk)), chunk);
            eq(cursor.byteOffset(), byteOffset);
            stack.push(chunk);
            byteOffset += blen(chunk);
            text = bfrom(text, blen(chunk));

            if (!cursor.next()) {
                break;
            }
        }
        eq("", text);
        eq(
            cursor.byteOffset(),
            blen(textSlice) - blen(cursor.chunk())
        );

        // Backward.
        while (true) {
            var chunk = cursor.chunk();
            eq(stack.pop(), chunk);

            if (!cursor.prev()) {
                break;
            }
        }
        eq(0, stack.length);
    }

    public function test_chunk_cursor_03() {
        var r = helloWorldRepeatRope();

        var cursor = r.chunkCursor();

        eq("Hello ", cursor.chunk());
        eq(true, cursor.next());
        eq("world!", cursor.chunk());
        eq(true, cursor.next());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.next());
        eq("world!", cursor.chunk());
        eq(true, cursor.next());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.next());
        eq("world!", cursor.chunk());
        eq(true, cursor.next());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.next());
        eq("world!", cursor.chunk());

        eq(false, cursor.next());
        eq("world!", cursor.chunk());
        eq(false, cursor.next());
        eq("world!", cursor.chunk());

        eq("world!", cursor.chunk());
        eq(true, cursor.prev());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.prev());
        eq("world!", cursor.chunk());
        eq(true, cursor.prev());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.prev());
        eq("world!", cursor.chunk());
        eq(true, cursor.prev());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.prev());
        eq("world!", cursor.chunk());
        eq(true, cursor.prev());
        eq("Hello ", cursor.chunk());

        eq(false, cursor.prev());
        eq("Hello ", cursor.chunk());
        eq(false, cursor.prev());
        eq("Hello ", cursor.chunk());
    }

    public function test_chunk_cursor_04() {
        var r = helloWorldRepeatRope();
        var s = r.slice(3, 45);

        var cursor = s.chunkCursor();

        eq("lo ", cursor.chunk());
        eq(true, cursor.next());
        eq("world!", cursor.chunk());
        eq(true, cursor.next());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.next());
        eq("world!", cursor.chunk());
        eq(true, cursor.next());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.next());
        eq("world!", cursor.chunk());
        eq(true, cursor.next());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.next());
        eq("wor", cursor.chunk());

        eq(false, cursor.next());
        eq("wor", cursor.chunk());
        eq(false, cursor.next());
        eq("wor", cursor.chunk());

        eq("wor", cursor.chunk());
        eq(true, cursor.prev());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.prev());
        eq("world!", cursor.chunk());
        eq(true, cursor.prev());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.prev());
        eq("world!", cursor.chunk());
        eq(true, cursor.prev());
        eq("Hello ", cursor.chunk());
        eq(true, cursor.prev());
        eq("world!", cursor.chunk());
        eq(true, cursor.prev());
        eq("lo ", cursor.chunk());

        eq(false, cursor.prev());
        eq("lo ", cursor.chunk());
        eq(false, cursor.prev());
        eq("lo ", cursor.chunk());
    }

    public function test_chunk_cursor_05() {
        var r = Rope.fromStr("");

        var cursor = r.chunkCursor();

        eq(cursor.byteOffset(), 0);
        eq("", cursor.chunk());

        eq(false, cursor.next());
        eq(cursor.byteOffset(), 0);
        eq("", cursor.chunk());

        eq(false, cursor.prev());
        eq(cursor.byteOffset(), 0);
        eq("", cursor.chunk());
    }

    public function test_chunk_cursor_06() {
        var r = helloWorldRepeatRope();
        var s = r.slice(14, 14);

        var cursor = s.chunkCursor();

        eq(cursor.byteOffset(), 0);
        eq("", cursor.chunk());

        eq(false, cursor.next());
        eq(cursor.byteOffset(), 0);
        eq("", cursor.chunk());

        eq(false, cursor.prev());
        eq(cursor.byteOffset(), 0);
        eq("", cursor.chunk());
    }

    public function test_chunk_cursor_07() {
        var texts = [TEXT, ""];
        for (text in texts) {
            var t = RopeSlice.fromStr(text);

            var cursor = t.chunkCursor();

            isTrue(cursor.atFirst());
            isTrue(cursor.atLast());
            eq(cursor.byteOffset(), 0);
            eq(cursor.chunk(), text);

            eq(false, cursor.next());
            isTrue(cursor.atFirst());
            isTrue(cursor.atLast());
            eq(cursor.byteOffset(), 0);
            eq(cursor.chunk(), text);

            eq(false, cursor.prev());
            isTrue(cursor.atFirst());
            isTrue(cursor.atLast());
            eq(cursor.byteOffset(), 0);
            eq(cursor.chunk(), text);
        }
    }

    public function test_chunk_cursor_at_01() {
        var r = Rope.fromStr(TEXT);

        for (i in 0...blen(TEXT) + 1) {
            var cursor = r.chunkCursorAt(i);
            var chunk = cursor.chunk();
            var byteOffset = cursor.byteOffset();

            isTrue(i >= byteOffset && i <= (byteOffset + blen(chunk)));
            eq(bsub(TEXT, byteOffset, (byteOffset + blen(chunk))), chunk);
        }

        var cursor1 = r.chunkCursorAt(blen(TEXT) - 1);
        var cursor2 = r.chunkCursorAt(blen(TEXT));
        eq(cursor1.byteOffset(), cursor2.byteOffset());
        eq(cursor1.chunk(), cursor2.chunk());
    }

    public function test_chunk_cursor_at_02() {
        var r = Rope.fromStr(TEXT);
        var s = r.slice(5, 124);
        var text = bsub(TEXT, 5, 124);

        for (i in 0...blen(text) + 1) {
            var cursor = s.chunkCursorAt(i);
            var chunk = cursor.chunk();
            var byteOffset = cursor.byteOffset();

            isTrue(i >= byteOffset && i <= (byteOffset + blen(chunk)));
            eq(bsub(text, byteOffset, (byteOffset + blen(chunk))), chunk);
        }

        var cursor1 = s.chunkCursorAt(blen(text) - 1);
        var cursor2 = s.chunkCursorAt(blen(text));
        eq(cursor1.byteOffset(), cursor2.byteOffset());
        eq(cursor1.chunk(), cursor2.chunk());
    }

    public function test_chunk_cursor_at_03() {
        // This tests a subtle corner case where the slice end aligns with
        // an internal chunk boundary, which would erronerously cause the
        // chunk cursor to be created on an empty chunk just *after* the slice
        // contents.  It requires a lot of nodes to trigger, because it needs
        // the tree to have enough depth.
        var r = {
            var rb = new RopeBuilder();
            for (_ in 0...100) {
                rb._appendChunkAsLeaf("A");
            }
            rb.finish();
        };

        for (i in 1...100 + 1) {
            var s = r.slice(0, i);
            var cursor = s.chunkCursorAt(i);
            eq("A", cursor.chunk());
        }
    }

    public function test_chunk_cursor_at_04() {
        panics(() -> {
            var r = Rope.fromStr("foo");
            r.chunkCursorAt(4);
        });
    }

    public function test_chunk_cursor_at_05() {
        panics(() -> {
            var r = Rope.fromStr("foo");
            var s = r.slice(1, 2);
            s.chunkCursorAt(2);
        });
    }

    public function test_chunk_cursor_at_06() {
        var texts = [TEXT, ""];
        for (text in texts) {
            var t = RopeSlice.fromStr(text);

            for (i in 0...blen(text) + 1) {
                var cursor = t.chunkCursorAt(i);

                isTrue(cursor.atFirst());
                isTrue(cursor.atLast());
                eq(cursor.byteOffset(), 0);
                eq(cursor.chunk(), text);
            }
        }
    }

    public function test_chunk_cursor_line_boundary_01() {
        var r = {
            var rb = new RopeBuilder();
            rb._appendChunkAsLeaf("AAA");
            rb._appendChunkAsLeaf("B\nB");
            rb._appendChunkAsLeaf("C\nC");
            rb._appendChunkAsLeaf("DDD");
            rb._appendChunkAsLeaf("EEE");
            rb._appendChunkAsLeaf("F\nF");
            rb._appendChunkAsLeaf("GGG");
            rb._appendChunkAsLeaf("HHH");
            rb._appendChunkAsLeaf("III");
            rb._appendChunkAsLeaf("J\nJ");
            rb._appendChunkAsLeaf("KKK");
            rb.finish();
        };

        var cursor = r.chunkCursor();

        // Forward.
        eq(0, cursor.byteOffset());
        eq("AAA", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq(3, cursor.byteOffset());
        eq("B\nB", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq(6, cursor.byteOffset());
        eq("C\nC", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq(15, cursor.byteOffset());
        eq("F\nF", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq(27, cursor.byteOffset());
        eq("J\nJ", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq(30, cursor.byteOffset());
        eq("KKK", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) == null);
        eq(30, cursor.byteOffset());
        eq("KKK", cursor.chunk());

        // Backward.
        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq(27, cursor.byteOffset());
        eq("J\nJ", cursor.chunk());

        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq(15, cursor.byteOffset());
        eq("F\nF", cursor.chunk());

        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq(6, cursor.byteOffset());
        eq("C\nC", cursor.chunk());

        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq(3, cursor.byteOffset());
        eq("B\nB", cursor.chunk());

        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq(0, cursor.byteOffset());
        eq("AAA", cursor.chunk());

        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) == null);
        eq(0, cursor.byteOffset());
        eq("AAA", cursor.chunk());
    }

    public function test_chunk_cursor_line_boundary_02() {
        var r = {
            var rb = new RopeBuilder();
            rb._appendChunkAsLeaf("AAA");
            rb._appendChunkAsLeaf("B\nB");
            rb._appendChunkAsLeaf("C\nC");
            rb._appendChunkAsLeaf("DDD");
            rb._appendChunkAsLeaf("EEE");
            rb._appendChunkAsLeaf("F\nF");
            rb._appendChunkAsLeaf("GGG");
            rb._appendChunkAsLeaf("HHH");
            rb._appendChunkAsLeaf("III");
            rb._appendChunkAsLeaf("J\nJ");
            rb._appendChunkAsLeaf("KKK");
            rb.finish();
        };
        var s = r.slice(4, 29);

        var cursor = s.chunkCursor();

        // Forward.
        eq(0, cursor.byteOffset());
        eq("\nB", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq(2, cursor.byteOffset());
        eq("C\nC", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq(11, cursor.byteOffset());
        eq("F\nF", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq(23, cursor.byteOffset());
        eq("J\n", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) == null);
        eq(23, cursor.byteOffset());
        eq("J\n", cursor.chunk());

        // Backward.
        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq(11, cursor.byteOffset());
        eq("F\nF", cursor.chunk());

        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq(2, cursor.byteOffset());
        eq("C\nC", cursor.chunk());

        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq(0, cursor.byteOffset());
        eq("\nB", cursor.chunk());

        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) == null);
        eq(0, cursor.byteOffset());
        eq("\nB", cursor.chunk());
    }

    public function test_chunk_cursor_line_boundary_03() {
        var r = {
            var rb = new RopeBuilder();
            rb._appendChunkAsLeaf("AAA");
            rb._appendChunkAsLeaf("B\nB");
            rb._appendChunkAsLeaf("C\nC");
            rb._appendChunkAsLeaf("DDD");
            rb._appendChunkAsLeaf("EEE");
            rb._appendChunkAsLeaf("F\nF");
            rb._appendChunkAsLeaf("GGG");
            rb._appendChunkAsLeaf("HHH");
            rb._appendChunkAsLeaf("III");
            rb._appendChunkAsLeaf("J\nJ");
            rb._appendChunkAsLeaf("KKK");
            rb.finish();
        };
        var s = r.slice(4, 29);

        var cursor = s.chunkCursor();

        eq("\nB", cursor.chunk());
        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq("C\nC", cursor.chunk());
        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq("\nB", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq("C\nC", cursor.chunk());
        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq("F\nF", cursor.chunk());
        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq("C\nC", cursor.chunk());

        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq("F\nF", cursor.chunk());
        isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) != null);
        eq("J\n", cursor.chunk());
        isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) != null);
        eq("F\nF", cursor.chunk());
    }

    public function test_chunk_cursor_line_boundary_04() {
        var text = linesText();
        var r = Rope.fromStr(text);

        var s = r.sliceFrom(0);
        var cursor = s.chunkCursor();

        // Forward.
        while (cursor.nextWithLineBoundary(LineType.LF_CR) != null) {}
        isTrue(cursor.atLast());
        eq(blen(text), cursor.byteOffset() + blen(cursor.chunk()));

        // Backward.
        while (cursor.prevWithLineBoundary(LineType.LF_CR) != null) {}
        isTrue(cursor.atFirst());
        eq(0, cursor.byteOffset());
    }

    public function test_chunk_cursor_line_boundary_05() {
        var lText = linesText();
        var texts = [lText, ""];
        for (text in texts) {
            var t = RopeSlice.fromStr(text);
            var cursor = t.chunkCursor();

            isTrue(cursor.atFirst());
            isTrue(cursor.atLast());
            eq(cursor.byteOffset(), 0);
            eq(cursor.chunk(), text);

            // Forward.
            isTrue(cursor.nextWithLineBoundary(LineType.LF_CR) == null);
            isTrue(cursor.atFirst());
            isTrue(cursor.atLast());
            eq(cursor.byteOffset(), 0);
            eq(cursor.chunk(), text);

            // Backward.
            isTrue(cursor.prevWithLineBoundary(LineType.LF_CR) == null);
            isTrue(cursor.atFirst());
            isTrue(cursor.atLast());
            eq(cursor.byteOffset(), 0);
            eq(cursor.chunk(), text);
        }
    }

}
