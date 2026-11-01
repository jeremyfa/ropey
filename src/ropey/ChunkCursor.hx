// Ported from ropey 2.0.0-beta.1: src/chunk_cursor.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

import haxe.io.Bytes;
import ropey.tree.Children;
import ropey.tree.Node;
import ropey.tree.Text;
import ropey.tree.TextInfo;

/**
 * A cursor for navigating the chunks of a text.
 *
 * Like in Rust, a cursor must not be used after the rope it comes from is
 * modified.
 */
class ChunkCursor {

    // The node stack (Rust's `Vec<StackItem>`), as parallel arrays.
    // Note: empty and ignored when `str` below is not null.
    var stackNode:Array<Node>;
    var stackInfo:Array<TextInfo>;
    var stackByteOffset:Array<Int>;
    var stackChildIdx:Array<Int>;
    var stackLen:Int;

    // If this is not null, then the chunk cursor is operating on a string
    // slice (`str[strOffset...strOffset + rangeEnd]`), not a normal rope.
    var str:Bytes;
    var strOffset:Int;

    // The byte range within the root node/string slice that is considered part
    // of this cursor's contents. For string slices this is always
    // `0...length_of_str`.
    var rangeStart:Int;
    var rangeEnd:Int;

    function new() {}

    /**
     * Attempts to advance the cursor to the next chunk.
     *
     * Returns true on success.  Returns false if it's already on the last
     * chunk, in which case this is a no-op.
     *
     * Runs in amortized O(1) time and worst-case O(log N) time.
     */
    public function next():Bool {
        // Already at the end.
        if (atLast()) {
            return false;
        }

        // Start at the node above the leaf.
        var stackIdx = stackLen - 2;

        // Find the deepest node that's not at its end already.
        while (stackChildIdx[stackIdx] >= (stackNode[stackIdx].childCount() - 1)) {
            stackIdx--;
        }

        // Refill the stack starting from that node.
        stackChildIdx[stackIdx] += 1;
        var byteOffset = stackByteOffset[stackIdx + 1] + stackInfo[stackIdx + 1].bytes;
        while (!stackNode[stackIdx].isLeaf) {
            var childI = stackChildIdx[stackIdx];
            var children:Children = cast stackNode[stackIdx];
            var node = children.nodes[childI];
            var info = children.info[childI];

            stackIdx++;
            stackNode[stackIdx] = node;
            stackInfo[stackIdx] = info;
            stackByteOffset[stackIdx] = byteOffset;
            stackChildIdx[stackIdx] = 0;
        }

        return true;
    }

    /**
     * Attempts to move the cursor to the previous chunk.
     *
     * Returns true on success.  Returns false if it's already on the first
     * chunk, in which case this is a no-op.
     *
     * Runs in amortized O(1) time and worst-case O(log N) time.
     */
    public function prev():Bool {
        // Already at the start.
        if (atFirst()) {
            return false;
        }

        // Start at the node above the leaf.
        var stackIdx = stackLen - 2;

        // Find the deepest node that's not at its start already.
        while (stackChildIdx[stackIdx] == 0) {
            stackIdx--;
        }

        // Refill the stack starting from that node.
        stackChildIdx[stackIdx] -= 1;
        var byteOffsetEnd = stackByteOffset[stackIdx + 1];
        while (!stackNode[stackIdx].isLeaf) {
            var childI = stackChildIdx[stackIdx];
            var children:Children = cast stackNode[stackIdx];
            var node = children.nodes[childI];
            var info = children.info[childI];
            var byteOffset = byteOffsetEnd - children.info[childI].bytes;
            var position = node.isLeaf ? 0 : (cast node : Children).len - 1;

            stackIdx++;
            stackNode[stackIdx] = node;
            stackInfo[stackIdx] = info;
            stackByteOffset[stackIdx] = byteOffset;
            stackChildIdx[stackIdx] = position;
        }

        return true;
    }

    /**
     * Returns the current chunk, decoded to a Haxe string.
     *
     * Runs in O(1) time.
     */
    public function chunk():String {
        if (str != null) {
            return Utf8.decode(str, strOffset, strOffset + rangeEnd);
        }

        var leaf:Text = cast stackNode[stackLen - 1];
        return Utf8.decode(leaf.buf, leafStart(), leafEnd());
    }

    /**
     * The UTF-8 bytes of the current chunk are `chunkBytes()[chunkStart()...chunkEnd()]`
     * (Rust's `chunk().as_bytes()`, without copying).
     */
    public inline function chunkBytes():Bytes {
        return str != null ? str : (cast stackNode[stackLen - 1] : Text).buf;
    }

    public inline function chunkStart():Int {
        return str != null ? strOffset : leafStart();
    }

    public inline function chunkEnd():Int {
        return str != null ? strOffset + rangeEnd : leafEnd();
    }

    /**
     * Length in bytes of the current chunk.
     */
    public inline function chunkLen():Int {
        return chunkEnd() - chunkStart();
    }

    inline function leafStart():Int {
        var start = rangeStart - stackByteOffset[stackLen - 1];
        return start < 0 ? 0 : start;
    }

    inline function leafEnd():Int {
        var offset = stackByteOffset[stackLen - 1];
        var bytes = stackInfo[stackLen - 1].bytes;
        return (offset + bytes) > rangeEnd ? rangeEnd - offset : bytes;
    }

    @:allow(ropey)
    function chunkSlice():RopeSlice {
        if (str != null) {
            return RopeSlice.fromStrBytes(str, strOffset, strOffset + rangeEnd);
        }

        return RopeSlice.create(stackNode[stackLen - 1], stackInfo[stackLen - 1], leafStart(), leafEnd());
    }

    /**
     * Returns whether the cursor is at the first chunk.
     *
     * Runs in O(1) time.
     */
    public function atFirst():Bool {
        if (str != null) {
            return true;
        }

        return stackByteOffset[stackLen - 1] <= rangeStart;
    }

    /**
     * Returns whether the cursor is at the last chunk.
     *
     * Runs in O(1) time.
     */
    public function atLast():Bool {
        if (str != null) {
            return true;
        }

        return (stackByteOffset[stackLen - 1] + stackInfo[stackLen - 1].bytes) >= rangeEnd;
    }

    /**
     * Returns the byte offset from the start of the text to the start of the
     * current chunk.
     *
     * Runs in O(1) time.
     */
    public function byteOffset():Int {
        if (str != null) {
            return 0;
        }

        // Offset from start of root.
        var offset = stackByteOffset[stackLen - 1];

        // Trimmed offset.
        if (offset > rangeEnd)
            offset = rangeEnd;
        offset -= rangeStart;
        return offset < 0 ? 0 : offset;
    }

    /**
     * Returns the byte offset from the start of the current chunk to the end
     * of the text.
     */
    @:allow(ropey)
    function byteOffsetFromEnd():Int {
        if (str != null) {
            return rangeEnd;
        }

        // Offset from start of root.
        var offset = stackByteOffset[stackLen - 1];

        // Trimmed and reversed offset.
        var result = rangeEnd - (offset > rangeStart ? offset : rangeStart);
        return result < 0 ? 0 : result;
    }

    //---------------------------------------------------------

    @:allow(ropey)
    static function create(node:Node, info:TextInfo, rangeStart:Int, rangeEnd:Int, atByteIdx:Int):ChunkCursor {
        if (atByteIdx < rangeStart || atByteIdx > rangeEnd) {
            throw new RopeyException(OutOfBounds);
        }

        var cursor = new ChunkCursor();
        cursor.stackNode = [];
        cursor.stackInfo = [];
        cursor.stackByteOffset = [];
        cursor.stackChildIdx = [];
        cursor.stackLen = 0;
        cursor.str = null;
        cursor.strOffset = 0;
        cursor.rangeStart = rangeStart;
        cursor.rangeEnd = rangeEnd;

        // Find the chunk the contains `atByteIdx` and set that as the current
        // chunk of the cursor.
        var currentNode = node;
        var currentInfo = info;
        var currentByteIdx = 0;
        var localByteIdx = atByteIdx;
        while (true) {
            if (currentNode.isLeaf) {
                cursor.pushItem(currentNode, currentInfo, currentByteIdx, 0);
                break;
            }
            else {
                var children:Children = cast currentNode;
                var childI = children.searchByteIdxOnly(localByteIdx, false);
                var accByteIdx = Children.searchAccBytes;

                cursor.pushItem(currentNode, currentInfo, currentByteIdx, childI);

                currentByteIdx += accByteIdx;
                localByteIdx -= accByteIdx;
                currentNode = children.nodes[childI];
                currentInfo = children.info[childI];
            }
        }

        // Handle a subtle corner case where the slice end is exactly on an
        // internal chunk boundary, causing the selected chunk to be the one
        // just *after* the slice range.
        if (cursor.byteOffset() >= (rangeEnd - rangeStart)) {
            cursor.prev();
        }

        return cursor;
    }

    inline function pushItem(node:Node, info:TextInfo, byteOffset:Int, childIdx:Int):Void {
        stackNode.push(node);
        stackInfo.push(info);
        stackByteOffset.push(byteOffset);
        stackChildIdx.push(childIdx);
        stackLen++;
    }

    @:allow(ropey)
    static function fromStr(text:Bytes, start:Int, end:Int):ChunkCursor {
        var cursor = new ChunkCursor();
        cursor.stackNode = null;
        cursor.stackInfo = null;
        cursor.stackByteOffset = null;
        cursor.stackChildIdx = null;
        cursor.stackLen = 0;
        cursor.str = text;
        cursor.strOffset = start;
        cursor.rangeStart = 0;
        cursor.rangeEnd = end - start;
        return cursor;
    }

    @:allow(ropey)
    inline function isFromStrSlice():Bool {
        return str != null;
    }

    /**
     * A copy of this cursor (Rust's `Clone`).
     */
    public function clone():ChunkCursor {
        var cursor = new ChunkCursor();
        cursor.stackNode = stackNode != null ? stackNode.copy() : null;
        cursor.stackInfo = stackInfo != null ? stackInfo.copy() : null;
        cursor.stackByteOffset = stackByteOffset != null ? stackByteOffset.copy() : null;
        cursor.stackChildIdx = stackChildIdx != null ? stackChildIdx.copy() : null;
        cursor.stackLen = stackLen;
        cursor.str = str;
        cursor.strOffset = strOffset;
        cursor.rangeStart = rangeStart;
        cursor.rangeEnd = rangeEnd;
        return cursor;
    }

    // Second and third results of `nextWithLineBoundary()` and
    // `prevWithLineBoundary()`.
    @:allow(ropey) var boundaryInfo:TextInfo;
    @:allow(ropey) var boundaryOffset:Int;

    /**
     * Like `next()`, but skips over chunks that don't contain line breaks.
     *
     * Returns the node of the common ancestor of the chunk moved from and the
     * chunk moved to (or null if it didn't move), and stores its info and its
     * byte offset relative to the start of the cursor range in
     * `boundaryInfo` and `boundaryOffset`.
     */
    @:allow(ropey)
    function nextWithLineBoundary(lineType:LineType):Node {
        // Already at the end.
        if (atLast()) {
            return null;
        }

        // Start at the node above the leaf.
        var stackIdx = stackLen - 2;

        // Find the deepest node that's not at its end already and has a
        // subsequent child node with a line break.
        // The idea behind this loop is that you're always *on* the
        // child you should move off of when you come in.
        while (true) {
            var nextOffset = stackInfo[stackIdx + 1].bytes + stackByteOffset[stackIdx + 1];

            if (nextOffset >= rangeEnd) {
                break;
            }

            if ((stackChildIdx[stackIdx] + 1) >= stackNode[stackIdx].childCount()) {
                stackIdx--;
                continue;
            }

            stackChildIdx[stackIdx] += 1;

            var childI = stackChildIdx[stackIdx];
            var children:Children = cast stackNode[stackIdx];
            stackNode[stackIdx + 1] = children.nodes[childI];
            stackInfo[stackIdx + 1] = children.info[childI];
            stackByteOffset[stackIdx + 1] = nextOffset;
            stackChildIdx[stackIdx + 1] = 0;

            if (children.info[childI].lineBreaks(lineType) > 0) {
                break;
            }
        }

        // Store common ancestor for returning later.
        var topNode = stackNode[stackIdx];
        boundaryInfo = stackInfo[stackIdx];
        boundaryOffset = stackByteOffset[stackIdx] - rangeStart;

        // Refill the stack starting from that node.
        // After the previous loop, we should now be on a child that either
        // contains the next line break or is the last node in the byte
        // range.
        stackIdx++; // We've already handled the immediate child in the previous loop.
        while (!stackNode[stackIdx].isLeaf) {
            var children:Children = cast stackNode[stackIdx];
            var childIdx = 0;
            var childByteOffset = stackByteOffset[stackIdx];
            var childNode = children.nodes[childIdx];
            var childInfo = children.info[childIdx];
            while ((childByteOffset + childInfo.bytes) < rangeEnd && childInfo.lineBreaks(lineType) == 0) {
                childIdx++;
                childByteOffset += childInfo.bytes;
                childNode = children.nodes[childIdx];
                childInfo = children.info[childIdx];
            }

            stackChildIdx[stackIdx] = childIdx;

            stackIdx++;
            stackNode[stackIdx] = childNode;
            stackInfo[stackIdx] = childInfo;
            stackByteOffset[stackIdx] = childByteOffset;
            stackChildIdx[stackIdx] = 0;
        }

        return topNode;
    }

    /**
     * Like `prev()`, but skips over chunks that don't contain line breaks.
     * See `nextWithLineBoundary()`.
     */
    @:allow(ropey)
    function prevWithLineBoundary(lineType:LineType):Node {
        // Already at the start.
        if (atFirst()) {
            return null;
        }

        // Start at the node above the leaf.
        var stackIdx = stackLen - 2;

        // Find the deepest node that's not at its start already and has a
        // prior child node with a line break.
        // The idea behind this loop is that you're always *on* the
        // child you should move off of when you come in.
        while (true) {
            var currentOffset = stackByteOffset[stackIdx + 1];
            if (currentOffset <= rangeStart) {
                break;
            }

            if (stackChildIdx[stackIdx] == 0) {
                stackIdx--;
                continue;
            }

            stackChildIdx[stackIdx] -= 1;

            var childI = stackChildIdx[stackIdx];
            var children:Children = cast stackNode[stackIdx];
            var childInfo = children.info[childI];
            stackNode[stackIdx + 1] = children.nodes[childI];
            stackInfo[stackIdx + 1] = childInfo;
            stackByteOffset[stackIdx + 1] = currentOffset - childInfo.bytes;
            stackChildIdx[stackIdx + 1] = 0;

            if (childInfo.lineBreaks(lineType) > 0) {
                break;
            }
        }

        // Store common ancestor for returning later.
        var topNode = stackNode[stackIdx];
        boundaryInfo = stackInfo[stackIdx];
        boundaryOffset = stackByteOffset[stackIdx] - rangeStart;

        // Refill the stack starting from that node.
        // After the previous loop, we should now be on a child that either
        // contains the next line break or is the last node in the byte
        // range.
        stackIdx++; // We've already handled the immediate child in the previous loop.
        while (!stackNode[stackIdx].isLeaf) {
            var children:Children = cast stackNode[stackIdx];
            var itemByteOffset = stackByteOffset[stackIdx];
            var itemInfo = stackInfo[stackIdx];
            var childIdx = children.len - 1;
            var childNode = children.nodes[childIdx];
            var childInfo = children.info[childIdx];
            var childByteOffset = itemByteOffset + itemInfo.bytes - childInfo.bytes;
            while (childByteOffset > rangeStart && childInfo.lineBreaks(lineType) == 0) {
                childIdx--;
                childNode = children.nodes[childIdx];
                childInfo = children.info[childIdx];
                childByteOffset -= childInfo.bytes;
            }

            stackChildIdx[stackIdx] = childIdx;

            stackIdx++;
            stackNode[stackIdx] = childNode;
            stackInfo[stackIdx] = childInfo;
            stackByteOffset[stackIdx] = childByteOffset;
            stackChildIdx[stackIdx] = 0;
        }

        return topNode;
    }

}
