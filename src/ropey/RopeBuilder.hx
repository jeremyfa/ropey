// Ported from ropey 2.0.0-beta.1: src/rope_builder.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

import haxe.io.Bytes;
import ropey.StrUtils.*;
import ropey.tree.Children;
import ropey.tree.Constants.MAX_CHILDREN;
import ropey.tree.Constants.MAX_TEXT_SIZE;
import ropey.tree.Constants.MIN_CHILDREN;
import ropey.tree.Node;
import ropey.tree.Text;

/**
 * An efficient incremental `Rope` builder.
 *
 * This is used to efficiently build ropes from sequences of text chunks.  It
 * is useful for creating ropes from:
 *
 * - ...large text files, without pre-loading their entire contents into
 *   memory (but see `Rope.fromReader()` in Rust for a convenience function
 *   that does this for casual use cases).
 * - ...streaming data sources.
 * - ...non-utf8 text data, doing the encoding conversion incrementally as you
 *   go.
 *
 * Unlike repeatedly calling `Rope.insert()` on the end of a rope, this API
 * runs in time linear to the amount of data fed to it, and is overall much
 * faster.
 */
class RopeBuilder {

    // The stack represents the right-most path down the tree of the rope,
    // starting from the root at index 0, and terminating in the deepest,
    // right-most non-leaf node.  The idea is that as we append more and more
    // nodes, the right-most nodes down the tree fill up, and as each one
    // fills up it gets added as a child of the node above it in the stack and
    // replaced with a fresh new node.
    //
    // There is one exception to the stack terminating in a non-leaf node: when
    // a leaf is the *only* node in the tree so far (i.e. the root).
    var stack:Array<Node>;

    var buffer:Bytes;

    var bufferLen:Int;

    /**
     * Creates a new RopeBuilder, ready for input.
     */
    public function new() {
        stack = [];
        buffer = Bytes.alloc(MAX_TEXT_SIZE);
        bufferLen = 0;
    }

    /**
     * Appends `chunk` to the end of the in-progress `Rope`.
     *
     * Call this method repeatedly to incrementally build up a `Rope`.  The
     * passed text chunk can be as large or small as desired, but larger
     * chunks will result in better performance.
     */
    public function append(chunk:String):Void {
        var bytes = Utf8.encode(chunk);
        appendBytes(bytes, 0, bytes.length);
    }

    /**
     * Appends the UTF-8 text `chunk[start...end]`.
     */
    public function appendBytes(chunk:Bytes, start:Int, end:Int):Void {
        while (end > start) {
            if (bufferLen == 0 && end - start >= MAX_TEXT_SIZE) {
                // Process text data directly, skipping the buffer.
                var splitIdx = findAppropriateSplitFloor(MAX_TEXT_SIZE, chunk, start, end);
                appendLeafNode(Text.fromStr(chunk, start, start + splitIdx));
                start += splitIdx;
            }
            // Note: the `- 4` is to account for the variable-length utf8
            // encoding.  Without that, we could end up stuck in an infinite
            // loop where the buffer isn't considered full and thus won't be
            // processed, but there also isn't room at the end of the buffer to
            // fit the next code point from `chunk`.
            else if (bufferLen > (MAX_TEXT_SIZE - 4)) {
                // Process filled buffer.
                appendLeafNode(Text.fromStr(buffer, 0, bufferLen));
                bufferLen = 0;
            }
            else {
                // Append to the buffer.
                var targetLen = MAX_TEXT_SIZE - bufferLen;
                var splitIdx = findAppropriateSplitFloor(targetLen, chunk, start, end);
                buffer.blit(bufferLen, chunk, start, splitIdx);
                bufferLen += splitIdx;
                start += splitIdx;
            }
        }
    }

    /**
     * Finishes the build, and returns the `Rope`.
     *
     * Note: the builder must not be used again after this.
     */
    public function finish():Rope {
        // Append the last leaf.
        if (bufferLen > 0) {
            appendLeafNode(Text.fromStr(buffer, 0, bufferLen));
            bufferLen = 0;
        }

        // Special case for empty rope.
        if (stack.length == 0) {
            return new Rope();
        }

        // Zip up all the remaining nodes on the stack
        var stackIdx = stack.length - 1;
        while (stackIdx >= 1) {
            var node = stack.pop();
            (cast stack[stackIdx - 1] : Children).push(node.textInfo(), node);
            stackIdx--;
        }

        // Create the rope.
        var root = stack.pop();
        computeAndSetUnbalanceFlagsDeep(root);
        var rootInfo = root.textInfo();
        return new Rope(root, rootInfo);
    }

    //-----------------------------------------------------------------

    @:allow(ropey)
    function buildAtOnce(text:Bytes, start:Int, end:Int):Rope {
        while (end > start) {
            var splitIdx = findAppropriateSplitFloor(MAX_TEXT_SIZE, text, start, end);
            appendLeafNode(Text.fromStr(text, start, start + splitIdx));
            start += splitIdx;
        }

        return finish();
    }

    /**
     * NOT PART OF THE PUBLIC API (used by the tests).
     */
    public function _appendChunkAsLeaf(contents:String):Void {
        var bytes = Utf8.encode(contents);
        appendLeafNode(Text.fromStr(bytes, 0, bytes.length));
    }

    function appendLeafNode(leaf:Node):Void {
        // This will fill up the tree nicely, without packing it so tight that
        // initial edits will be inefficient.
        final TARGET_CHILDREN = Std.int((MIN_CHILDREN + MAX_CHILDREN) / 2);

        if (stack.length == 0) {
            stack.push(leaf);
            return;
        }

        if (stack[stack.length - 1].isLeaf) {
            var last = stack.pop();

            var children = new Children();
            children.push(last.textInfo(), last);
            children.push(leaf.textInfo(), leaf);

            stack.push(children);
            return;
        }

        var right = leaf;
        var stackIdx = stack.length - 1;
        while (true) {
            if (stackIdx < 0) {
                // We're above the root, so do a root split.
                var children = new Children();
                children.push(right.textInfo(), right);
                stack.insert(0, children);
                break;
            }
            else if (stack[stackIdx].childCount() < TARGET_CHILDREN) {
                // There's room to add a child, so do that.
                (cast stack[stackIdx] : Children).push(right.textInfo(), right);
                break;
            }
            else {
                // We've reached the target child count at this level of the
                // stack, so swap out the current node at this level with a
                // fresh new node, and hold on to the reached-target-child-count
                // node to be added as a child of the next level up.
                var children = new Children();
                children.push(right.textInfo(), right);
                right = stack[stackIdx];
                stack[stackIdx] = children;
                stackIdx--;
            }
        }
    }

    static function computeAndSetUnbalanceFlagsDeep(node:Node):Void {
        if (!node.isLeaf) {
            var children:Children = cast node;
            for (i in 0...children.len) {
                computeAndSetUnbalanceFlagsDeep(children.nodes[i]);
                children.updateUnbalanceFlag(i);
            }
        }
    }

}
