// Ported from ropey 2.0.0-beta.1: tests/proptest_tests.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

import TestUtil.*;
import ropey.LineType;
import ropey.Rope;
import ropey.RopeBase;
import ropey.Utf8;

/**
 * The property tests of ropey, run on generated inputs.
 *
 * Rust uses proptest with 512 cases per test and string strategies such as
 * `\PC{0,200}` (any non-control chars). Here a seeded random generator makes
 * the same kinds of inputs (reproducible from run to run), `CASES` per test.
 * The expected values come from simple reference implementations written in
 * this file (Rust uses the `str_indices` crate and `String`).
 */
class PropTests {

    static inline final CASES = 512;

    static final TEXT = PropText.TEXT;

    var seed = 0x2545F491;

    public function new() {}

    //---------------------------------------------------------
    // Random inputs.

    // xorshift32
    function nextInt():Int {
        var x = seed;
        x ^= x << 13;
        x ^= x >>> 17;
        x ^= x << 5;
        seed = x;
        return x & 0x7FFFFFFF;
    }

    function below(n:Int):Int {
        return nextInt() % n;
    }

    function usize():Int {
        return nextInt();
    }

    function bool():Bool {
        return nextInt() & 1 == 1;
    }

    /**
     * A random non-control char (`\PC`): mostly ASCII, with Latin, CJK,
     * combining marks, emoji (outside the BMP) and a few line separators
     * (U+2028, U+2029 and U+0085 are not in the Cc category).
     */
    function randomChar():Int {
        var k = below(20);
        return switch k {
            case 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7: 0x20 + below(0x7F - 0x20);
            case 8 | 9: 0xA0 + below(0x250 - 0xA0);
            case 10 | 11: 0x300 + below(0x70);
            case 12 | 13: 0x3040 + below(0x9FFF - 0x3040);
            case 14: 0xAC00 + below(0xD7A3 - 0xAC00);
            case 15 | 16: 0x1F300 + below(0x1FAFF - 0x1F300);
            case 17: 0x20000 + below(0x2A6DF - 0x20000);
            case 18: [0x2028, 0x2029, 0x0085, 0xFEFF, 0xFFFD][below(5)];
            default: 0x400 + below(0x500 - 0x400);
        }
    }

    /**
     * `\PC{min,max}`.
     */
    function randomText(min:Int, max:Int):String {
        var n = min + below(max - min + 1);
        var buf = new StringBuf();
        for (_ in 0...n)
            buf.addChar(randomChar());
        return buf.toString();
    }

    /**
     * `(\u{000A}|\u{000D}|\u{000A}\u{000D}){0,200}`, with `extra` added to
     * the alternatives when not null.
     */
    function randomBreaks(?extra:String):String {
        var n = below(201);
        var alternatives = ["\n", "\r", "\n\r"];
        if (extra != null)
            alternatives.push(extra);
        var buf = new StringBuf();
        for (_ in 0...n)
            buf.add(alternatives[below(alternatives.length)]);
        return buf.toString();
    }

    /**
     * `\n{0,5}\PC{0,100}\n{0,5}\PC{0,100}\n{0,5}`.
     */
    function randomLinesText():String {
        return repeat("\n", below(6)) + randomText(0, 100) + repeat("\n", below(6)) + randomText(0, 100) + repeat("\n", below(6));
    }

    //---------------------------------------------------------
    // Reference implementations.

    static function closestCharBoundary(text:String, byteIdx:Int):Int {
        var len = blen(text);
        if (byteIdx > len)
            byteIdx = len;
        while (!isCharBoundary(text, byteIdx)) {
            byteIdx += 1;
        }
        return byteIdx;
    }

    static function stringInsert(text:String, byteIdx:Int, textIns:String):String {
        return bto(text, byteIdx) + textIns + bfrom(text, byteIdx);
    }

    static function stringRemove(text:String, byteStart:Int, byteEnd:Int):String {
        return bto(text, byteStart) + bfrom(text, byteEnd);
    }

    static function countUtf16(text:String):Int {
        var n = 0;
        for (c in charsOf(text))
            n += c >= 0x10000 ? 2 : 1;
        return n;
    }

    /**
     * Byte indices of the starts of the lines after each line break.
     */
    static function lineStarts(text:String, lineType:LineType):Array<Int> {
        var b = bytesOf(text);
        var starts = [];
        var i = 0;
        while (i < b.length) {
            var c = b.get(i);
            if (c == 0x0A) {
                starts.push(i + 1);
            }
            else if (c == 0x0D && lineType == LineType.LF_CR) {
                if (i + 1 < b.length && b.get(i + 1) == 0x0A) {
                    starts.push(i + 2);
                    i++;
                }
                else {
                    starts.push(i + 1);
                }
            }
            i++;
        }
        return starts;
    }

    static function countBreaks(text:String, lineType:LineType):Int {
        return lineStarts(text, lineType).length;
    }

    static function linesFromByteIdx(text:String, byteIdx:Int, lineType:LineType):Int {
        // A CRLF pair counts as a break once the LF is passed, so a byte
        // index between CR and LF is still on the line before.
        var n = 0;
        for (s in lineStarts(text, lineType)) {
            if (s <= byteIdx)
                n++;
        }
        return n;
    }

    static function linesToByteIdx(text:String, lineIdx:Int, lineType:LineType):Int {
        if (lineIdx == 0)
            return 0;
        var starts = lineStarts(text, lineType);
        return lineIdx <= starts.length ? starts[lineIdx - 1] : blen(text);
    }

    static function assertMetricsEq(rope:RopeBase, text:String, ?pos:haxe.PosInfos) {
        eq(rope.len(), blen(text), pos);
        eq(rope.lenChars(), charsOf(text).length, pos);
        eq(rope.lenUtf16(), countUtf16(text), pos);
        eq(rope.lenLines(LineType.LF), countBreaks(text, LineType.LF) + 1, pos);
        eq(rope.lenLines(LineType.LF_CR), countBreaks(text, LineType.LF_CR) + 1, pos);
    }

    static function prevLineByteIdx(text:String):Int {
        var b = bytesOf(text);
        var idx = b.length - 2;
        while (idx >= 0) {
            var byte = b.get(idx);
            if (byte == 0x0A || byte == 0x0D) {
                return idx + 1;
            }
            idx--;
        }
        return 0;
    }

    static function lastByte(text:String):Int {
        var b = bytesOf(text);
        return b.length > 0 ? b.get(b.length - 1) : -1;
    }

    //---------------------------------------------------------
    // Tests.

    public function test_pt_from_str() {
        for (_ in 0...CASES) {
            var text = randomText(0, 200);
            var rope = Rope.fromStr(text);
            rope.assertInvariants();

            for (t in makeTestData(rope, text)) {
                eq(t, text);
                assertMetricsEq(t, text);
            }
        }
    }

    public function test_pt_from_str_crlf() {
        for (_ in 0...CASES) {
            var text = randomBreaks();
            var rope = Rope.fromStr(text);
            rope.assertInvariants();

            for (t in makeTestData(rope, text)) {
                eq(t, text);
                assertMetricsEq(t, text);
            }
        }
    }

    public function test_pt_insert() {
        for (_ in 0...CASES) {
            var idx = below(blen(TEXT) + 1);
            var insText = randomText(0, 50);

            var rope = Rope.fromStr(TEXT);
            var text = TEXT;

            var idx = closestCharBoundary(TEXT, idx);

            rope.insert(idx, insText);
            text = stringInsert(text, idx, insText);

            for (t in makeTestData(rope, text)) {
                eq(t, text);
                assertMetricsEq(t, text);
            }

            rope.assertInvariants();
        }
    }

    public function test_pt_insert_crlf() {
        for (_ in 0...CASES) {
            var crOrLf = bool();
            var idx = usize();
            var startText = randomBreaks();

            var rope = Rope.fromStr(startText);
            var text = startText;

            var idx = closestCharBoundary(startText, idx % (blen(startText) + 1));
            var insText = crOrLf ? "\r" : "\n";

            rope.insert(idx, insText);
            text = stringInsert(text, idx, insText);

            for (t in makeTestData(rope, text)) {
                eq(t, text);
                assertMetricsEq(t, text);
            }

            rope.assertInvariants();
        }
    }

    public function test_pt_remove() {
        for (_ in 0...CASES) {
            var idx1 = below(blen(TEXT) + 1);
            var idx2 = below(blen(TEXT) + 1);

            var rope = Rope.fromStr(TEXT);
            var text = TEXT;

            var idxLeft = closestCharBoundary(TEXT, idx1 < idx2 ? idx1 : idx2);
            var idxRight = closestCharBoundary(TEXT, idx1 < idx2 ? idx2 : idx1);

            rope.remove(idxLeft, idxRight);
            text = stringRemove(text, idxLeft, idxRight);

            for (t in makeTestData(rope, text)) {
                eq(t, text);
                assertMetricsEq(t, text);
            }

            rope.assertInvariants();

            isTrue(rope.attemptFullRebalance(100));
            rope.assertInvariants();
        }
    }

    public function test_pt_remove_crlf() {
        for (_ in 0...CASES) {
            var idx1 = usize();
            var idx2 = usize();
            var startText = randomBreaks();
            if (startText.length == 0) {
                continue;
            }

            var rope = Rope.fromStr(startText);
            var text = startText;

            var tmp1 = closestCharBoundary(startText, idx1 % (blen(startText) + 1));
            var tmp2 = closestCharBoundary(startText, idx2 % (blen(startText) + 1));

            var idxLeft = tmp1 < tmp2 ? tmp1 : tmp2;
            var idxRight = tmp1 < tmp2 ? tmp2 : tmp1;

            rope.remove(idxLeft, idxRight);
            text = stringRemove(text, idxLeft, idxRight);

            for (t in makeTestData(rope, text)) {
                eq(t, text);
                assertMetricsEq(t, text);
            }

            rope.assertInvariants();

            isTrue(rope.attemptFullRebalance(100));
            rope.assertInvariants();
        }
    }

    public function test_pt_byte_to_line_idx() {
        for (_ in 0...CASES) {
            var text = randomBreaks("\u{2028}");
            var rope = Rope.fromStr(text);

            for (t in makeTestData(rope, text)) {
                for (i in 0...blen(text) + 1) {
                    eq(linesFromByteIdx(text, i, LineType.LF), t.byteToLineIdx(i, LineType.LF));
                    eq(linesFromByteIdx(text, i, LineType.LF_CR), t.byteToLineIdx(i, LineType.LF_CR));
                }
            }
        }
    }

    public function test_pt_line_to_byte_idx() {
        for (_ in 0...CASES) {
            var text = randomBreaks("\u{2028}");
            var rope = Rope.fromStr(text);

            for (t in makeTestData(rope, text)) {
                for (lineType in [LineType.LF, LineType.LF_CR]) {
                    var lineCount = countBreaks(text, lineType) + 1;
                    for (i in 0...lineCount + 1) {
                        eq(linesToByteIdx(text, i, lineType), t.lineToByteIdx(i, lineType));
                    }
                }
            }
        }
    }

    public function test_pt_chunks_iter_next() {
        for (_ in 0...CASES) {
            var text = randomText(0, 200);
            var r = Rope.fromStr(text);

            for (t in makeTestData(r, text)) {
                var idx = 0;
                var chunks = t.chunks();
                var chunk;
                while ((chunk = chunks.next()) != null) {
                    eq(chunk, bsub(text, idx, idx + blen(chunk)));
                    idx += blen(chunk);
                }

                eq(idx, blen(text));
            }
        }
    }

    function randomRange(text:String):Array<Int> {
        var idx1 = closestCharBoundary(text, usize() % (blen(text) + 1));
        var idx2 = closestCharBoundary(text, usize() % (blen(text) + 1));
        return idx1 < idx2 ? [idx1, idx2] : [idx2, idx1];
    }

    public function test_pt_slice_chunks_iter_next() {
        for (_ in 0...CASES) {
            var fullText = randomText(0, 200);
            var range = randomRange(fullText);
            var start = range[0];
            var end = range[1];
            var r = Rope.fromStr(fullText);

            for (t in makeTestData(r, fullText)) {
                var text = bsub(fullText, start, end);
                var s = t.slice(start, end);

                var idx = 0;
                var chunks = s.chunks();
                var chunk;
                while ((chunk = chunks.next()) != null) {
                    eq(chunk, bsub(text, idx, idx + blen(chunk)));
                    idx += blen(chunk);
                }

                eq(idx, blen(text));
            }
        }
    }

    function checkLinesNext(s:RopeBase, text:String) {
        var lineTxt = text;

        var idx = 0;
        var lines = s.lines(LineType.LF_CR);
        var line;
        while ((line = lines.next()) != null) {
            var nextIdx = linesToByteIdx(lineTxt, 1, LineType.LF_CR);
            var txtChunk = bto(lineTxt, nextIdx);
            lineTxt = bfrom(lineTxt, nextIdx);
            eq(line, txtChunk);
            idx += line.len();
        }

        eq(idx, blen(text));
    }

    function checkLinesPrev(s:RopeBase, text:String) {
        var lineTxt = text;

        var first = true;
        var idx = blen(text);
        var lines = s.linesAt(s.lenLines(LineType.LF_CR), LineType.LF_CR).reversed();
        var line;
        while ((line = lines.next()) != null) {
            var last = lastByte(lineTxt);
            var txtChunk = if (first && (last == "\n".code || last == "\r".code)) {
                "";
            }
            else {
                var prevIdx = prevLineByteIdx(lineTxt);
                var txtChunk = bfrom(lineTxt, prevIdx);
                lineTxt = bto(lineTxt, prevIdx);
                txtChunk;
            };
            eq(line, txtChunk);
            idx -= line.len();
            first = false;
        }

        eq(idx, 0);
    }

    public function test_pt_lines_iter_next() {
        for (_ in 0...CASES) {
            var text = randomLinesText();
            var r = Rope.fromStr(text);

            for (t in makeTestData(r, text)) {
                checkLinesNext(t, text);
            }
        }
    }

    public function test_pt_lines_iter_prev() {
        for (_ in 0...CASES) {
            var text = randomLinesText();
            var r = Rope.fromStr(text);

            for (t in makeTestData(r, text)) {
                checkLinesPrev(t, text);
            }
        }
    }

    public function test_pt_slice_lines_iter_next() {
        for (_ in 0...CASES) {
            var fullText = randomLinesText();
            var range = randomRange(fullText);
            var r = Rope.fromStr(fullText);

            for (t in makeTestData(r, fullText)) {
                var text = bsub(fullText, range[0], range[1]);
                var s = t.slice(range[0], range[1]);
                checkLinesNext(s, text);
            }
        }
    }

    public function test_pt_slice_lines_iter_prev() {
        for (_ in 0...CASES) {
            var fullText = randomLinesText();
            var range = randomRange(fullText);
            var r = Rope.fromStr(fullText);

            for (t in makeTestData(r, fullText)) {
                var text = bsub(fullText, range[0], range[1]);
                var s = t.slice(range[0], range[1]);

                eq(s.len(), blen(text));

                checkLinesPrev(s, text);
            }
        }
    }

    public function test_pt_char_indices_iter() {
        for (_ in 0...CASES) {
            var text = randomLinesText();
            var r = Rope.fromStr(text);
            for (t in makeTestData(r, text)) {
                // Forward.
                var offset = 0;
                var iter = t.charIndices();
                var ch;
                while ((ch = iter.next()) != -1) {
                    eq(offset, iter.index);
                    offset += Utf8.lenUtf8(ch);

                    var remaining = t.len() - offset;
                    isTrue(iter.sizeHint() <= remaining && iter.sizeHintMax() >= remaining);
                }
                eq(offset, t.len());

                // Backward.
                var offset = t.len();
                var iter = t.charIndicesAt(t.len());
                while ((ch = iter.prev()) != -1) {
                    offset -= Utf8.lenUtf8(ch);
                    eq(offset, iter.index);

                    var remaining = t.len() - offset;
                    isTrue(iter.sizeHint() <= remaining && iter.sizeHintMax() >= remaining);
                }
                eq(offset, 0);
            }
        }
    }

    public function test_pt_char_indices_iter_reversed() {
        for (_ in 0...CASES) {
            var text = randomLinesText();
            var r = Rope.fromStr(text);
            for (t in makeTestData(r, text)) {
                // Backward.
                var offset = t.len();
                var iter = t.charIndicesAt(t.len()).reversed();
                var ch;
                while ((ch = iter.next()) != -1) {
                    offset -= Utf8.lenUtf8(ch);
                    eq(offset, iter.index);

                    isTrue(iter.sizeHint() <= offset && iter.sizeHintMax() >= offset);
                }
                eq(offset, 0);

                // Forward.
                var offset = 0;
                var iter = t.charIndices().reversed();
                while ((ch = iter.prev()) != -1) {
                    eq(offset, iter.index);
                    offset += Utf8.lenUtf8(ch);

                    isTrue(iter.sizeHint() <= offset && iter.sizeHintMax() >= offset);
                }
                eq(offset, t.len());
            }
        }
    }

}
