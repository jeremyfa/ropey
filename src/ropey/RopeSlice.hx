// Ported from ropey 2.0.0-beta.1: src/slice.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

import haxe.io.Bytes;
import ropey.tree.Children;
import ropey.tree.Node;
import ropey.tree.TextInfo;

/**
 * An immutable view into part of a `Rope`, or into a string.
 *
 * Like in Rust, a slice of a rope must not be used after that rope is
 * modified.
 *
 * See `RopeBase` for the methods shared with `Rope`.
 */
class RopeSlice extends RopeBase {

    function new() {
        super();
    }

    /**
     * `RopeSlice::new()`: finds the deepest node that still contains the full
     * range given.
     */
    @:allow(ropey)
    static function create(root:Node, rootInfo:TextInfo, start:Int, end:Int):RopeSlice {
        var result = new RopeSlice();

        // Special case for performance, since this actually comes up a fair bit.
        if (start == 0 && end == rootInfo.bytes) {
            result.root = root;
            result.rootInfo = rootInfo;
            result.rangeStart = start;
            result.rangeEnd = end;
            return result;
        }

        // Find the deepest node that still contains the full range given.
        var node = root;
        var nodeInfo = rootInfo;
        while (!node.isLeaf) {
            var children:Children = cast node;
            var childStartByte = 0;
            var found = false;
            for (i in 0...children.len) {
                var info = children.info[i];
                var childEndByte = childStartByte + info.bytes;
                if (start >= childStartByte && end <= childEndByte) {
                    start -= childStartByte;
                    end -= childStartByte;
                    node = children.nodes[i];
                    nodeInfo = info;
                    found = true;
                    break;
                }
                childStartByte = childEndByte;
            }
            if (!found)
                break;
        }

        result.root = node;
        result.rootInfo = nodeInfo;
        result.rangeStart = start;
        result.rangeEnd = end;
        return result;
    }

    /**
     * `RopeSlice::from(&str)`.
     */
    public static function fromStr(text:String):RopeSlice {
        var bytes = Utf8.encode(text);
        return fromStrBytes(bytes, 0, bytes.length);
    }

    /**
     * A slice over the UTF-8 text `bytes[start...end]` (`RopeSlice::from(&str)`).
     */
    public static function fromStrBytes(bytes:Bytes, start:Int, end:Int):RopeSlice {
        var result = new RopeSlice();
        result.str = bytes;
        result.strOffset = start;
        result.rangeStart = 0;
        result.rangeEnd = end - start;
        return result;
    }

    /**
     * `RopeSlice::from(&Rope)`.
     */
    public static function fromRope(rope:Rope):RopeSlice {
        return create(rope.root, rope.rootInfo, 0, rope.rootInfo.bytes);
    }

    /**
     * Whether this slice was made from a string (`SliceInner::Str`).
     */
    @:allow(ropey)
    inline function isStr():Bool {
        return str != null;
    }

}
