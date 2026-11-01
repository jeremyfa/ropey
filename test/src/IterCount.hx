/**
 * Rust's `Iterator::count()` for the ropey iterators (consumes the
 * iterator), used by the ported tests.
 */
class IterCount {

    public static function count(it:ropey.iter.Chunks):Int {
        var n = 0;
        while (it.nextRaw())
            n++;
        return n;
    }

}

class BytesCount {

    public static function count(it:ropey.iter.Bytes):Int {
        var n = 0;
        while (it.next() != -1)
            n++;
        return n;
    }

}

class CharsCount {

    public static function count(it:ropey.iter.Chars):Int {
        var n = 0;
        while (it.next() != -1)
            n++;
        return n;
    }

}

class LinesCount {

    public static function count(it:ropey.iter.Lines):Int {
        var n = 0;
        while (it.next() != null)
            n++;
        return n;
    }

}
