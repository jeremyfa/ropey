// Ported from ropey 2.0.0-beta.1: src/tree/text.rs, src/tree/children.rs,
// src/tree/text_info.rs (tests)
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

import TestUtil.*;
import ropey.LineType;
import ropey.tree.Children;
import ropey.tree.Constants.MAX_CHILDREN;
import ropey.tree.Constants.MAX_TEXT_SIZE;
import ropey.tree.Node;
import ropey.tree.Text;
import ropey.tree.TextInfo;

@:access(ropey.tree)
class TreeTests {

    public function new() {}

    static function textOf(s:String):Text {
        var b = bytesOf(s);
        return Text.fromStr(b, 0, b.length);
    }

    static function infoOf(s:String):TextInfo {
        var b = bytesOf(s);
        return TextInfo.fromStr(b, 0, b.length);
    }

    static function eqInfo(a:TextInfo, b:TextInfo, ?pos:haxe.PosInfos) {
        isTrue(a.equals(b), pos);
    }

    static function eqText(leaf:Text, s:String, ?pos:haxe.PosInfos) {
        eq(leaf.text(), s, pos);
    }

    //=========================================================
    // text.rs: `inner::Buffer` tests.

    static function bufferFromStr(text:String):Text {
        var buffer = new Text();
        var b = bytesOf(text);
        buffer.bufInsert(0, b, 0, b.length);
        return buffer;
    }

    static function bufInsert(buf:Text, idx:Int, s:String) {
        var b = bytesOf(s);
        buf.bufInsert(idx, b, 0, b.length);
    }

    public function test_buffer_new_01() {
        var leaf = new Text();
        eq(leaf.text(), "");
    }

    public function test_buffer_is_char_boundary_01() {
        var text = "Hello world!";
        var buf = bufferFromStr(text);
        for (i in 0...blen(text) + 1) {
            eq(isCharBoundary(text, i), buf.isCharBoundary(i));
        }
    }

    public function test_buffer_is_char_boundary_02() {
        var text = "こんにちは";
        var buf = bufferFromStr(text);
        for (i in 0...blen(text) + 1) {
            eq(isCharBoundary(text, i), buf.isCharBoundary(i));
        }
    }

    public function test_buffer_insert_01() {
        var buf = bufferFromStr("Hello!");
        bufInsert(buf, 0, "foo");
        eq(buf.text(), "fooHello!");
    }

    public function test_buffer_insert_02() {
        var buf = bufferFromStr("Hello!");
        bufInsert(buf, 3, "foo");
        eq(buf.text(), "Helfoolo!");
    }

    public function test_buffer_insert_03() {
        var buf = bufferFromStr("Hello!");
        bufInsert(buf, 6, "foo");
        eq(buf.text(), "Hello!foo");
    }

    public function test_buffer_insert_04() {
        var buf = bufferFromStr("Hello!");
        panics(() -> bufInsert(buf, 7, "foo"));
    }

    public function test_buffer_insert_05() {
        var buf = bufferFromStr("こんに");
        panics(() -> bufInsert(buf, 1, "foo"));
    }

    public function test_buffer_remove_01() {
        var buf = bufferFromStr("Hello!");
        buf.bufRemove(0, 2);
        eq(buf.text(), "llo!");
    }

    public function test_buffer_remove_02() {
        var buf = bufferFromStr("Hello!");
        buf.bufRemove(2, 4);
        eq(buf.text(), "Heo!");
    }

    public function test_buffer_remove_03() {
        var buf = bufferFromStr("Hello!");
        buf.bufRemove(4, 6);
        eq(buf.text(), "Hell");
    }

    public function test_buffer_remove_04() {
        var buf = bufferFromStr("Hello!");
        buf.bufRemove(0, 6);
        eq(buf.text(), "");
    }

    public function test_buffer_remove_05() {
        var buf = bufferFromStr("Hello!");
        panics(() -> buf.bufRemove(0, 7));
    }

    public function test_buffer_remove_06() {
        var buf = bufferFromStr("Hello!");
        panics(() -> buf.bufRemove(2, 1));
    }

    public function test_buffer_remove_07() {
        var buf = bufferFromStr("こんに");
        panics(() -> buf.bufRemove(1, 2));
    }

    //=========================================================
    // text.rs: `Text` tests.

    public function test_text_new_01() {
        var leaf = new Text();
        eq(leaf.text(), "");
    }

    public function test_text_from_str_01() {
        var leaf = textOf("");
        eq(leaf.text(), "");
    }

    public function test_text_from_str_02() {
        var text = "Hello world!";
        var textInfo = infoOf(text);
        var leaf = textOf(text);
        eq(leaf.text(), text);
        eqInfo(leaf.textInfo(), textInfo);
    }

    public function test_text_byte_to_char_idx_01() {
        var text = textOf("こんmちは");

        eq(0, text.byteToCharIdx(0));
        eq(0, text.byteToCharIdx(1));
        eq(0, text.byteToCharIdx(2));
        eq(1, text.byteToCharIdx(3));
        eq(1, text.byteToCharIdx(4));
        eq(1, text.byteToCharIdx(5));
        eq(2, text.byteToCharIdx(6));
        eq(3, text.byteToCharIdx(7));
        eq(3, text.byteToCharIdx(8));
        eq(3, text.byteToCharIdx(9));
        eq(4, text.byteToCharIdx(10));
        eq(4, text.byteToCharIdx(11));
        eq(4, text.byteToCharIdx(12));
        eq(5, text.byteToCharIdx(13));
    }

    public function test_text_char_to_byte_idx_01() {
        var text = textOf("こんmちは");

        eq(0, text.charToByteIdx(0));
        eq(3, text.charToByteIdx(1));
        eq(6, text.charToByteIdx(2));
        eq(7, text.charToByteIdx(3));
        eq(10, text.charToByteIdx(4));
        eq(13, text.charToByteIdx(5));
    }

    public function test_text_byte_to_utf16_idx_01() {
        var text = textOf("ん🐸mち");
        eq(0, text.byteToUtf16Idx(0));
        eq(0, text.byteToUtf16Idx(1));
        eq(0, text.byteToUtf16Idx(2));
        eq(1, text.byteToUtf16Idx(3));
        eq(1, text.byteToUtf16Idx(4));
        eq(1, text.byteToUtf16Idx(5));
        eq(1, text.byteToUtf16Idx(6));
        eq(3, text.byteToUtf16Idx(7));
        eq(4, text.byteToUtf16Idx(8));
        eq(4, text.byteToUtf16Idx(9));
        eq(4, text.byteToUtf16Idx(10));
        eq(5, text.byteToUtf16Idx(11));
    }

    public function test_text_utf16_to_byte_idx_01() {
        var text = textOf("ん🐸mち");

        eq(0, text.utf16ToByteIdx(0));
        eq(3, text.utf16ToByteIdx(1));
        eq(3, text.utf16ToByteIdx(2));
        eq(7, text.utf16ToByteIdx(3));
        eq(8, text.utf16ToByteIdx(4));
        eq(11, text.utf16ToByteIdx(5));
    }

    public function test_text_byte_to_line_idx_01() {
        var text = textOf("\r\n\r\n\n\r\r\n");
        var lineIdxs = [
            [0, 0],
            [0, 0],
            [1, 1],
            [1, 1],
            [2, 2],
            [3, 3],
            [3, 4],
            [3, 4],
            [4, 5],
        ];

        for (j in 0...lineIdxs.length) {
            var lf = lineIdxs[j][0];
            var crlf = lineIdxs[j][1];
            eq(lf, text.byteToLineIdx(j, LineType.LF));
            eq(crlf, text.byteToLineIdx(j, LineType.LF_CR));
        }
    }

    public function test_text_line_to_byte_idx_01() {
        var text = textOf("\r\n\r\n\n\r\r\n");

        var lineLfByteIdxs = [0, 2, 4, 5, 8];
        var lineCrlfByteIdxs = [0, 2, 4, 5, 6, 8];

        for (l in 0...lineLfByteIdxs.length) {
            eq(lineLfByteIdxs[l], text.lineToByteIdx(l, LineType.LF));
        }

        for (l in 0...lineCrlfByteIdxs.length) {
            eq(lineCrlfByteIdxs[l], text.lineToByteIdx(l, LineType.LF_CR));
        }
    }

    static function insertStr(leaf:Text, idx:Int, s:String):TextInfo {
        var b = bytesOf(s);
        return leaf.insertStrAndUpdateInfo(idx, b, 0, b.length, leaf.textInfo());
    }

    public function test_text_insert_str_and_update_info_01() {
        var leaf = new Text();

        var info = insertStr(leaf, 0, "o ");
        eqText(leaf, "o ");
        eqInfo(info, infoOf("o "));

        var info = insertStr(leaf, 0, "He");
        eqText(leaf, "Heo ");
        eqInfo(info, infoOf("Heo "));

        var info = insertStr(leaf, 2, "ll");
        eqText(leaf, "Hello ");
        eqInfo(info, infoOf("Hello "));

        var info = insertStr(leaf, 6, "world!");
        eqText(leaf, "Hello world!");
        eqInfo(info, infoOf("Hello world!"));
    }

    public function test_text_remove_range_and_update_info_01() {
        var leaf = textOf("Hello world!");

        var info = leaf.removeRangeAndUpdateInfo(4, 6, leaf.textInfo());
        eqText(leaf, "Hellworld!");
        eqInfo(info, infoOf("Hellworld!"));

        var info = leaf.removeRangeAndUpdateInfo(0, 3, leaf.textInfo());
        eqText(leaf, "lworld!");
        eqInfo(info, infoOf("lworld!"));

        var info = leaf.removeRangeAndUpdateInfo(4, 7, leaf.textInfo());
        eqText(leaf, "lwor");
        eqInfo(info, infoOf("lwor"));

        var info = leaf.removeRangeAndUpdateInfo(0, 4, leaf.textInfo());
        eqText(leaf, "");
        eqInfo(info, infoOf(""));
    }

    public function test_text_split_01() {
        var text = "Hello world!";
        var leaf = textOf(text);
        for (i in 0...blen(text) + 1) {
            var left:Text = cast leaf.cloneData();
            var right = left.split(i);
            eqText(left, bto(text, i));
            eqText(right, bfrom(text, i));
        }
    }

    public function test_text_split_02() {
        var leaf = new Text();
        var right = leaf.split(0);
        eqText(leaf, "");
        eqText(right, "");
    }

    public function test_text_split_03() {
        var leaf = textOf("人");
        panics(() -> leaf.split(1));
    }

    public function test_text_distribute_01() {
        var text = "Hello world!!";
        var expectedLeft = "Hello w";
        var expectedRight = "orld!!";
        for (splitI in 0...blen(text) + 1) {
            var leaf1 = textOf(bto(text, splitI));
            var leaf2 = textOf(bfrom(text, splitI));
            leaf1.distribute(leaf2);
            eqText(leaf1, expectedLeft);
            eqText(leaf2, expectedRight);
        }
    }

    public function test_text_distribute_02() {
        var text = "こんにちは";
        var splits:Array<Array<Dynamic>> = [
            [0, "こん", "にちは"],
            [3, "こん", "にちは"],
            [6, "こん", "にちは"],
            [9, "こんに", "ちは"],
            [12, "こんに", "ちは"],
            [15, "こんに", "ちは"],
        ];
        for (split in splits) {
            var splitI:Int = split[0];
            var leaf1 = textOf(bto(text, splitI));
            var leaf2 = textOf(bfrom(text, splitI));
            leaf1.distribute(leaf2);
            eqText(leaf1, split[1]);
            eqText(leaf2, split[2]);
        }
    }

    public function test_text_distribute_03() {
        // This tests a corner case where we can't split at the exact
        // desired split point because the left side is just shy of
        // being full and the right side is full and starts with a
        // multi-byte character.  In a naive implementation of
        // `distribute()` this case will panic as it tries to move
        // more data into the left side than can fit.
        var textL = "";
        var textR = "";
        while ((blen(textL) + blen("a")) <= (MAX_TEXT_SIZE - 1)) {
            textL += "a";
        }
        while ((blen(textR) + blen("🐸")) <= MAX_TEXT_SIZE) {
            textR += "🐸";
        }
        while ((blen(textR) + blen("a")) <= MAX_TEXT_SIZE) {
            textR += "a";
        }

        var leaf1 = textOf(textL);
        var leaf2 = textOf(textR);
        leaf1.distribute(leaf2);
        eq(leaf1.text() + leaf2.text(), textL + textR);
    }

    //=========================================================
    // children.rs tests (on Rust's `ChildrenInternal`: `innerPush()` and
    // `innerInsert()` do not touch the unbalance flags).

    // Generates a unique string with unique text info for any usize.
    static function iToS(i:Int):String {
        return repeat(Std.string(i), i + 1);
    }

    static function makeLeaf(text:String):Node {
        return textOf(text);
    }

    static function pushInfoAndNode(children:Children, text:String) {
        children.innerPush(infoOf(text), makeLeaf(text));
    }

    static function leafText(node:Node):String {
        return node.leafText().text();
    }

    static function makeChildrenFull(unbalanceFlag:Bool):Children {
        var children = new Children();
        for (i in 0...MAX_CHILDREN) {
            pushInfoAndNode(children, iToS(i));
            if (unbalanceFlag) {
                children.setUnbalanceFlag(i);
            }
        }

        return children;
    }

    static function makeChildrenHalfFull(unbalanceFlag:Bool):Children {
        var children = new Children();
        for (i in 0...Std.int(MAX_CHILDREN / 2)) {
            pushInfoAndNode(children, iToS(i));
            if (unbalanceFlag) {
                children.setUnbalanceFlag(i);
            }
        }

        return children;
    }

    // `!((!0) << n)`: the n low bits set.
    static inline function lowBits(n:Int):Int {
        return ~((~0) << n);
    }

    public function test_children_push_01() {
        var children = new Children();
        for (i in 0...MAX_CHILDREN) {
            pushInfoAndNode(children, iToS(i));
        }
        for (i in 0...MAX_CHILDREN) {
            eq(children.info[i].bytes, blen(iToS(i)));
            eq(leafText(children.nodes[i]), iToS(i));
        }
    }

    public function test_children_pop_01() {
        var children = makeChildrenFull(true);

        var i = MAX_CHILDREN - 1;
        while (i >= 0) {
            var node = children.pop();
            var info = children.info[children.len];

            eq(children.len, i);
            eq(info.bytes, blen(iToS(i)));
            eq(leafText(node), iToS(i));
            eq(lowBits(i), children.subtreeUnbalanceFlags);
            i--;
        }
    }

    public function test_children_insert_01() {
        var children = makeChildrenHalfFull(true);

        children.innerInsert(1, infoOf("a"), makeLeaf("a"));
        children.innerInsert(children.len, infoOf("b"), makeLeaf("b"));
        children.innerInsert(0, infoOf("c"), makeLeaf("c"));

        for (i in 0...children.len) {
            var text = if (i == 0) {
                "c";
            }
            else if (i == 2) {
                "a";
            }
            else if (i == children.len - 1) {
                "b";
            }
            else if (i < 2) {
                iToS(i - 1);
            }
            else {
                iToS(i - 2);
            }

            eq(children.info[i].bytes, blen(text));
            eq(leafText(children.nodes[i]), text);
        }

        var expectedBits = lowBits(children.len);
        expectedBits &= ~(1 << 0);
        expectedBits &= ~(1 << 2);
        expectedBits &= ~(1 << (children.len - 1));

        eq(expectedBits, children.subtreeUnbalanceFlags);
    }

    public function test_children_insert_02() {
        var children = makeChildrenFull(false);
        children.pop();
        for (i in 0...children.len) {
            if ((i % 2) == 0) {
                children.setUnbalanceFlag(i);
            }
        }

        children.innerInsert(2, infoOf("a"), makeLeaf("a"));

        for (i in 0...children.len) {
            var unbalanced = children.isNodeUnbalanced(i);
            if (i < 2) {
                eq((i % 2) == 0, unbalanced);
            }
            else if (i == 2) {
                eq(false, unbalanced);
            }
            else {
                eq((i % 2) != 0, unbalanced);
            }
        }
    }

    public function test_children_remove_01() {
        var children = makeChildrenFull(true);

        var lastI = children.len - 1;

        var lastInfo = children.info[lastI];
        var last = children.remove(lastI);
        var firstInfo = children.info[0];
        var first = children.remove(0);
        var middleInfo = children.info[1];
        var middle = children.remove(1);

        eq(children.len, MAX_CHILDREN - 3);

        eq(lastInfo.bytes, blen(iToS(lastI)));
        eq(leafText(last), iToS(lastI));

        eq(firstInfo.bytes, blen(iToS(0)));
        eq(leafText(first), iToS(0));

        eq(middleInfo.bytes, blen(iToS(2)));
        eq(leafText(middle), iToS(2));

        eq(lowBits(children.len), children.subtreeUnbalanceFlags);
    }

    public function test_children_remove_02() {
        var children = makeChildrenFull(false);
        for (i in 0...children.len) {
            if ((i % 2) == 0) {
                children.setUnbalanceFlag(i);
            }
        }

        children.remove(2);

        eq(0, children.subtreeUnbalanceFlags & ((~0) << children.len));

        for (i in 0...children.len) {
            var unbalanced = children.isNodeUnbalanced(i);
            if (i < 2) {
                eq((i % 2) == 0, unbalanced);
            }
            else {
                eq((i % 2) != 0, unbalanced);
            }
        }
    }

    public function test_children_remove_range_01() {
        var ranges = [[1, 1], [0, 2], [1, 3], [2, MAX_CHILDREN]];

        for (range in ranges) {
            var children = makeChildrenFull(true);
            var rangeLen = range[1] - range[0];

            children.removeMultiple(range[0], range[1]);
            eq(children.len, MAX_CHILDREN - rangeLen);
            for (i in 0...children.len) {
                var originalI = i < range[0] ? i : i + rangeLen;
                var text = iToS(originalI);

                eq(children.info[i].bytes, blen(text));
                eq(leafText(children.nodes[i]), text);
            }

            eq(lowBits(children.len), children.subtreeUnbalanceFlags);
        }
    }

    public function test_children_steal_range_from_01() {
        var idxs = [0, 1, Std.int(MAX_CHILDREN / 2)];
        var ranges = [[1, 1], [0, 2], [1, 3], [MAX_CHILDREN - 2, MAX_CHILDREN]];

        for (idx in idxs) {
            for (range in ranges) {
                var childrenTo = makeChildrenHalfFull(true);
                var childrenFrom = makeChildrenFull(true);
                var rangeLen = range[1] - range[0];

                childrenTo.stealRangeFrom(idx, childrenFrom, range[0], range[1]);

                // Verify `childrenFrom`.
                eq(childrenFrom.len, MAX_CHILDREN - rangeLen);
                for (i in 0...childrenFrom.len) {
                    var originalI = i < range[0] ? i : i + rangeLen;
                    var text = iToS(originalI);

                    eq(childrenFrom.info[i].bytes, blen(text));
                    eq(leafText(childrenFrom.nodes[i]), text);
                }

                // Verify `childrenTo`.
                eq(childrenTo.len, Std.int(MAX_CHILDREN / 2) + rangeLen);
                for (i in 0...childrenTo.len) {
                    var originalI = if (i < idx) {
                        i;
                    }
                    else if (i < (idx + rangeLen)) {
                        i - idx + range[0];
                    }
                    else {
                        i - rangeLen;
                    };
                    var text = iToS(originalI);

                    eq(childrenTo.info[i].bytes, blen(text));
                    eq(leafText(childrenTo.nodes[i]), text);
                }

                eq(lowBits(childrenFrom.len), childrenFrom.subtreeUnbalanceFlags);
                eq(lowBits(childrenTo.len), childrenTo.subtreeUnbalanceFlags);
            }
        }
    }

    //=========================================================
    // text_info.rs tests.

    public function test_text_info_new_01() {
        eqInfo(TextInfo.empty(), infoOf(""));
    }

    public function test_text_info_from_str_bytes_01() {
        eq(0, infoOf("").bytes);
        eq(6, infoOf("Hello!").bytes);
        eq(18, infoOf("こんにちは！").bytes);
    }

    public function test_text_info_from_str_chars_01() {
        eq(0, infoOf("").chars);
        eq(6, infoOf("Hello!").chars);
        eq(6, infoOf("こんにちは！").chars);
    }

    public function test_text_info_from_str_line_breaks_lf_01() {
        eq(0, infoOf("").lineBreaksLf);
        eq(0, infoOf("\u{0085}").lineBreaksLf);
        eq(0, infoOf("\r").lineBreaksLf);
        eq(1, infoOf("\n").lineBreaksLf);
        eq(1, infoOf("\r\n").lineBreaksLf);
        eq(1, infoOf("Hello\n world!").lineBreaksLf);
        eq(3, infoOf("\nこんにち\nは！\n").lineBreaksLf);
    }

    public function test_text_info_from_str_line_breaks_cr_lf_01() {
        eq(0, infoOf("").lineBreaksCrLf);
        eq(0, infoOf("\u{0085}").lineBreaksCrLf);
        eq(1, infoOf("\r").lineBreaksCrLf);
        eq(1, infoOf("\n").lineBreaksCrLf);
        eq(1, infoOf("\r\n").lineBreaksCrLf);
        eq(1, infoOf("Hello\n world!").lineBreaksCrLf);
        eq(4, infoOf("\nこん\rにち\nは！\r\n").lineBreaksCrLf);
    }

    // Not ported: `from_str_line_breaks_unicode_01` needs the
    // metric_lines_unicode feature (not enabled in gpui-kit).

}
