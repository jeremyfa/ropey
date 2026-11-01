import haxe.io.Bytes;
import ropey.Rope;
import ropey.RopeBase;
import ropey.RopeBuilder;
import ropey.RopeSlice;

/**
 * Assertions and helpers shared by the ported tests.
 *
 * Rust strings are indexed by UTF-8 byte offsets: `blen()`, `bsub()`... work
 * on byte offsets of Haxe strings, so the ported tests can keep their indices.
 */
class TestUtil {

    public static var assertions = 0;

    // 127 bytes, 103 chars, 1 line
    public static inline final TEXT = "Hello there!  How're you doing?  It's "
        + "a fine day, isn't it?  Aren't you glad "
        + "we're alive?  こんにちは、みんなさん！";

    // 124 bytes, 100 chars, 4 lines
    public static inline final TEXT_LINES = "Hello there!  How're you doing?\nIt's "
        + "a fine day, isn't it?\nAren't you glad "
        + "we're alive?\nこんにちは、みんなさん！";

    // 143 bytes, 107 chars, 111 utf16 code units, 1 line
    public static inline final TEXT_EMOJI = "Hello there!🐸  How're you doing?🐸  It's "
        + "a fine day, isn't it?🐸  Aren't you glad "
        + "we're alive?🐸  こんにちは、みんなさん！";

    public static function fail(message:String, ?pos:haxe.PosInfos):Void {
        throw new TestFailure(message + ' (' + pos.fileName + ':' + pos.lineNumber + ')');
    }

    static function show(v:Dynamic):String {
        if (v == null)
            return 'null';
        if (Std.isOfType(v, String))
            return '"' + v + '"';
        return Std.string(v);
    }

    static function same(a:Dynamic, b:Dynamic):Bool {
        if (a == null || b == null)
            return a == null && b == null;
        if (Std.isOfType(a, RopeBase)) {
            if (Std.isOfType(b, RopeBase))
                return (a : RopeBase).equals(b);
            if (Std.isOfType(b, String))
                return (a : RopeBase).equalsStr(b);
            return false;
        }
        if (Std.isOfType(b, RopeBase))
            return same(b, a);
        if (Std.isOfType(a, Array) && Std.isOfType(b, Array)) {
            var aa:Array<Dynamic> = a;
            var bb:Array<Dynamic> = b;
            if (aa.length != bb.length)
                return false;
            for (i in 0...aa.length) {
                if (!same(aa[i], bb[i]))
                    return false;
            }
            return true;
        }
        return a == b;
    }

    /**
     * `assert_eq!(a, b)`.
     */
    public static function eq(a:Dynamic, b:Dynamic, ?pos:haxe.PosInfos):Void {
        assertions++;
        if (!same(a, b))
            fail('expected ' + show(a) + ' == ' + show(b), pos);
    }

    /**
     * `assert_ne!(a, b)`.
     */
    public static function ne(a:Dynamic, b:Dynamic, ?pos:haxe.PosInfos):Void {
        assertions++;
        if (same(a, b))
            fail('expected ' + show(a) + ' != ' + show(b), pos);
    }

    /**
     * `assert!(cond)`.
     */
    public static function isTrue(cond:Bool, ?pos:haxe.PosInfos):Void {
        assertions++;
        if (!cond)
            fail('assertion failed', pos);
    }

    /**
     * `#[should_panic]`: `f` must throw.
     */
    public static function panics(f:Void->Void, ?pos:haxe.PosInfos):Void {
        assertions++;
        var threw = false;
        try {
            f();
        }
        catch (e:TestFailure) {
            throw e;
        }
        catch (e:Dynamic) {
            threw = true;
        }
        if (!threw)
            fail('expected a panic', pos);
    }

    //-----------------------------------------------------
    // Byte indexed strings.

    public static inline function bytesOf(s:String):Bytes {
        return Bytes.ofString(s, UTF8);
    }

    /**
     * `s.len()`: the length of `s` in UTF-8 bytes.
     */
    public static function blen(s:String):Int {
        return bytesOf(s).length;
    }

    /**
     * `&s[start..end]` with byte offsets.
     */
    public static function bsub(s:String, start:Int, end:Int):String {
        var b = bytesOf(s);
        if (start < 0 || end > b.length || start > end)
            throw 'bsub: bad range';
        return b.getString(start, end - start, UTF8);
    }

    public static function bfrom(s:String, start:Int):String {
        var b = bytesOf(s);
        return b.getString(start, b.length - start, UTF8);
    }

    public static inline function bto(s:String, end:Int):String {
        return bsub(s, 0, end);
    }

    /**
     * `s.is_char_boundary(i)`.
     */
    public static function isCharBoundary(s:String, i:Int):Bool {
        var b = bytesOf(s);
        if (i == 0 || i == b.length)
            return true;
        if (i > b.length)
            return false;
        return (b.get(i) & 0xC0) != 0x80;
    }

    /**
     * `s.chars()` as code points.
     */
    public static function charsOf(s:String):Array<Int> {
        var result = [];
        var b = bytesOf(s);
        var i = 0;
        while (i < b.length) {
            var c = ropey.Utf8.codePointAt(b, i);
            result.push(c);
            i += ropey.Utf8.lenUtf8(c);
        }
        return result;
    }

    /**
     * `s.char_indices()` as byte offsets (same order as `charsOf()`).
     */
    public static function charOffsetsOf(s:String):Array<Int> {
        var result = [];
        var b = bytesOf(s);
        var i = 0;
        while (i < b.length) {
            result.push(i);
            i += ropey.Utf8.lenUtf8(ropey.Utf8.codePointAt(b, i));
        }
        return result;
    }

    /**
     * `s.bytes()`.
     */
    public static function bytesArrayOf(s:String):Array<Int> {
        var b = bytesOf(s);
        return [for (i in 0...b.length) b.get(i)];
    }

    public static function strOfChar(c:Int):String {
        var buf = new StringBuf();
        buf.addChar(c);
        return buf.toString();
    }

    public static function repeat(s:String, n:Int):String {
        var buf = new StringBuf();
        for (_ in 0...n)
            buf.add(s);
        return buf.toString();
    }

    //-----------------------------------------------------
    // Ropes.

    /**
     * Note: ensures that the chunks as given become individual leaf nodes in
     * the rope.
     */
    public static function makeRopeFromChunks(chunks:Array<String>):Rope {
        var rb = new RopeBuilder();
        for (chunk in chunks)
            rb._appendChunkAsLeaf(chunk);
        return rb.finish();
    }

    public static function makeTextFromChunks(chunks:Array<String>):String {
        return chunks.join('');
    }

    /**
     * Constructs both a Rope-based slice and str-based slice, with the same
     * contents (byte range `start...end`, `end == -1` for the whole text).
     */
    public static function makeTestData(rope:Rope, text:String, start:Int = 0, end:Int = -1, ?pos:haxe.PosInfos):Array<RopeSlice> {
        eq(rope, text, pos);
        if (end < 0)
            end = blen(text);
        return [rope.slice(start, end), RopeSlice.fromStr(bsub(text, start, end))];
    }

}

class TestFailure {

    public final message:String;

    public function new(message:String) {
        this.message = message;
    }

    public function toString():String {
        return message;
    }

}
