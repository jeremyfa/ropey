// Ported from ropey 2.0.0-beta.1: src/tree/children.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey.tree;

import haxe.ds.Vector;
import ropey.tree.Constants.MAX_CHILDREN;
import ropey.tree.Constants.MAX_TEXT_SIZE;

/**
 * Internal node of the Rope, with other nodes as children.
 *
 * In Rust an internal node is a `Node::Internal(Arc<Children>)`. Here
 * `Children` itself is the shared node object (see `Node`).
 *
 * This is essentially a fixed-capacity `Vec`.  However, it actually contains
 * _two_ arrays rather than just one, but which share a length.
 */
class Children extends Node {

    /**
     * An array of the child nodes (`0...len` are valid).
     */
    public final nodes:Vector<Node>;

    /**
     * An array of the child node text infos (`0...len` are valid).
     */
    public final info:Vector<TextInfo>;

    var subtreeUnbalanceFlags:Int;

    public var len(default, null):Int;

    /**
     * Results of the `search*()` methods returning a left-side accumulated
     * info (Rust returns them as a tuple with the child index).
     */
    public static var searchAccBytes:Int = 0;

    public function new() {
        super(false);
        nodes = new Vector(MAX_CHILDREN);
        info = new Vector(MAX_CHILDREN);
        subtreeUnbalanceFlags = 0;
        len = 0;
    }

    /**
     * `Clone` of Rust's `ChildrenInternal`: the child nodes are shared
     * (their reference count is incremented), the infos are immutable.
     */
    override function cloneData():Node {
        var result = new Children();
        for (i in 0...len) {
            var node = nodes[i];
            node.rc++;
            result.nodes[i] = node;
            result.info[i] = info[i];
        }
        result.len = len;
        result.subtreeUnbalanceFlags = subtreeUnbalanceFlags;
        return result;
    }

    /**
     * Ensures the child at `idx` is not shared with another tree (`Arc::make_mut()`
     * through `nodes_mut()`), and returns it.
     */
    public inline function nodeMut(idx:Int):Node {
        var node = nodes[idx];
        if (node.rc > 1) {
            node.rc--;
            node = node.cloneData();
            nodes[idx] = node;
        }
        return node;
    }

    /**
     * Pushes an item onto the end of the child array.
     *
     * Increases length by one.  Throws if already full.
     */
    public function push(itemInfo:TextInfo, itemNode:Node):Void {
        innerPush(itemInfo, itemNode);
        updateUnbalanceFlag(len - 1);
    }

    /**
     * Pushes an element onto the end of the array, and then splits it in half,
     * returning the right half.
     *
     * This works even when the array is full.
     */
    public function pushSplit(newChildInfo:TextInfo, newChildNode:Node):Children {
        var rCount = Std.int((len + 1) / 2);
        var lCount = (len + 1) - rCount;

        var right = splitOff(lCount);
        right.push(newChildInfo, newChildNode);
        return right;
    }

    /**
     * Merges two nodes together.
     *
     * Assumes the two nodes are adjacent to each other, with `idx1`
     * preceding `idx2`.
     *
     * Note: will throw internally if there's too much data to
     * combine into one node.
     */
    public function merge(idx1:Int, idx2:Int):Void {
        var node1 = nodes[idx1];
        var node2 = nodes[idx2];
        if (node1.isLeaf && node2.isLeaf) {
            var text1:Text = cast nodeMut(idx1);
            var text2:Text = cast node2;
            text1.appendStr(text2.buf, 0, text2.len);
        }
        else if (!node1.isLeaf && !node2.isLeaf) {
            var children1:Children = cast nodeMut(idx1);
            var children2:Children = cast nodeMut(idx2);
            var children2Len = children2.len;
            children1.stealRangeFrom(children1.len, children2, 0, children2Len);
        }
        else {
            throw new RopeyException(InvalidRange, "Can't merge two nodes of different types.");
        }

        info[idx1] = info[idx1].add(info[idx2]);
        Node.release(remove(idx2));
        updateUnbalanceFlag(idx1);
    }

    /**
     * Equally distributes the data between two nodes.
     *
     * Assumes the two nodes are adjacent to each other, with `idx1`
     * preceding `idx2`.
     */
    public function distribute(idx1:Int, idx2:Int):Void {
        var node1 = nodes[idx1];
        var node2 = nodes[idx2];
        if (node1.isLeaf && node2.isLeaf) {
            var text1:Text = cast nodeMut(idx1);
            var text2:Text = cast nodeMut(idx2);
            text1.distribute(text2);

            info[idx1] = text1.textInfo();
            info[idx2] = text2.textInfo();
        }
        else if (!node1.isLeaf && !node2.isLeaf) {
            var lhs:Children = cast nodeMut(idx1);
            var rhs:Children = cast nodeMut(idx2);
            var rhsTargetLen = Std.int((lhs.len + rhs.len) / 2);
            if (rhs.len < rhsTargetLen) {
                var start = lhs.len + rhs.len - rhsTargetLen;
                var lhsLen = lhs.len;
                rhs.stealRangeFrom(0, lhs, start, lhsLen);
            }
            else if (rhs.len > rhsTargetLen) {
                var end = rhs.len - rhsTargetLen;
                lhs.stealRangeFrom(lhs.len, rhs, 0, end);
            }

            info[idx1] = lhs.combinedTextInfo();
            info[idx2] = rhs.combinedTextInfo();
        }
        else {
            throw new RopeyException(InvalidRange, "Can't distribute data between two nodes of different types.");
        }
        updateUnbalanceFlag(idx1);
        updateUnbalanceFlag(idx2);
    }

    /**
     * Attempts to merge two nodes, and if it's too much data to merge
     * equi-distributes the data between the two.
     *
     * Assumes the two nodes are adjacent to each other, with `idx1`
     * preceding `idx2`.
     *
     * Returns:
     *
     * - True: merge was successful.
     * - False: merge failed, equidistributed instead.
     */
    public function mergeDistribute(idx1:Int, idx2:Int):Bool {
        var node1 = nodes[idx1];
        var node2 = nodes[idx2];
        var doMerge = if (node1.isLeaf && node2.isLeaf) {
            ((cast node1 : Text).len + (cast node2 : Text).len) <= MAX_TEXT_SIZE;
        }
        else if (!node1.isLeaf && !node2.isLeaf) {
            ((cast node1 : Children).len + (cast node2 : Children).len) <= MAX_CHILDREN;
        }
        else {
            throw new RopeyException(InvalidRange, 'Siblings have different node types');
        }

        if (doMerge) {
            merge(idx1, idx2);
            return true;
        }
        else {
            distribute(idx1, idx2);
            return false;
        }
    }

    /**
     * Pops an item off the end of the array and returns its node (read
     * `info[len]` right after the call for its info).
     *
     * Decreases length by one.  Throws if already empty.
     */
    public function pop():Node {
        if (len <= 0)
            throw new RopeyException(OutOfBounds, 'assertion failed: self.len() > 0');
        len--;

        subtreeUnbalanceFlags &= ~(1 << len);

        var node = nodes[len];
        nodes[len] = null;
        return node;
    }

    /**
     * Inserts an item into the array at the given index.
     *
     * Increases length by one.  Throws if already full.  Preserves ordering
     * of the other items.
     */
    public function insert(idx:Int, itemInfo:TextInfo, itemNode:Node):Void {
        innerInsert(idx, itemInfo, itemNode);
        updateUnbalanceFlag(idx);
    }

    /**
     * Inserts an element into the array, and then splits it in half, returning
     * the right half.
     *
     * This works even when the array is full.
     */
    public function insertSplit(idx:Int, itemInfo:TextInfo, itemNode:Node):Children {
        if (len <= 0)
            throw new RopeyException(OutOfBounds, 'assertion failed: self.len() > 0');
        if (idx > len)
            throw new RopeyException(OutOfBounds, 'assertion failed: idx <= self.len()');
        var extraInfo:TextInfo;
        var extraNode:Node;
        if (idx < len) {
            extraInfo = info[len - 1];
            extraNode = pop();
            info[len] = null;
            insert(idx, itemInfo, itemNode);
        }
        else {
            extraInfo = itemInfo;
            extraNode = itemNode;
        }

        return pushSplit(extraInfo, extraNode);
    }

    /**
     * Removes the item at the given index from the array, and returns its
     * node (moved out, the caller must release it if it drops it).
     *
     * Decreases length by one.  Preserves ordering of the other items.
     */
    public function remove(idx:Int):Node {
        if (idx >= len)
            throw new RopeyException(OutOfBounds, 'assertion failed: idx < self.len()');

        var node = nodes[idx];

        var i = idx;
        while (i < len - 1) {
            nodes[i] = nodes[i + 1];
            info[i] = info[i + 1];
            i++;
        }
        nodes[len - 1] = null;
        info[len - 1] = null;

        // The unbalance flags.
        var lowMask = rangeBitmask(0, idx);
        var highMask = rangeBitmask(idx + 1, len);
        subtreeUnbalanceFlags = ((subtreeUnbalanceFlags & highMask) >>> 1) | (subtreeUnbalanceFlags & lowMask);

        len--;

        return node;
    }

    /**
     * Removes the items in the given index range (right exclusive), and
     * drops them.
     *
     * Preserves ordering of the remaining items.
     */
    public function removeMultiple(rangeStart:Int, rangeEnd:Int):Void {
        if (rangeStart > rangeEnd)
            throw new RopeyException(InvalidRange, 'assertion failed: range[0] <= range[1]');
        if (rangeEnd > len)
            throw new RopeyException(OutOfBounds, 'assertion failed: range[1] <= self.len()');

        // Step 1: drop the nodes to be removed.
        for (i in rangeStart...rangeEnd) {
            Node.release(nodes[i]);
        }

        // Step 2: shift items over to fill in the gap.
        var rangeLen = rangeEnd - rangeStart;
        var i = rangeStart;
        while (i + rangeLen < len) {
            nodes[i] = nodes[i + rangeLen];
            info[i] = info[i + rangeLen];
            i++;
        }
        while (i < len) {
            nodes[i] = null;
            info[i] = null;
            i++;
        }

        // Move the unbalance flags.
        var lowMask = rangeBitmask(0, rangeStart);
        var highMask = rangeBitmask(rangeEnd, len);
        subtreeUnbalanceFlags = ((subtreeUnbalanceFlags & highMask) >>> rangeLen) | (subtreeUnbalanceFlags & lowMask);

        len -= rangeLen;
    }

    /**
     * Splits the array in two at `idx`, returning the right part of the split.
     */
    public function splitOff(idx:Int):Children {
        if (idx > len)
            throw new RopeyException(OutOfBounds, 'assertion failed: idx <= self.len()');

        var other = new Children();
        var selfLen = len;
        other.stealRangeFrom(0, this, idx, selfLen);

        return other;
    }

    public inline function isNodeUnbalanced(childIdx:Int):Bool {
        return subtreeUnbalanceFlags & (1 << childIdx) != 0;
    }

    public inline function isAnyUnbalanced():Bool {
        return subtreeUnbalanceFlags != 0;
    }

    /**
     * Index of the first unbalanced child, or -1 (`None`).
     */
    public function firstUnbalancedChildIdx():Int {
        if (isAnyUnbalanced()) {
            var flags = subtreeUnbalanceFlags;
            var n = 0;
            while (flags & 1 == 0) {
                flags >>>= 1;
                n++;
            }
            return n;
        }
        else {
            return -1;
        }
    }

    public inline function setUnbalanceFlag(idx:Int):Void {
        subtreeUnbalanceFlags |= 1 << idx;
    }

    public inline function clearUnbalanceFlag(idx:Int):Void {
        subtreeUnbalanceFlags &= ~(1 << idx);
    }

    /**
     * Raw flags, for the tests.
     */
    public inline function unbalanceFlags():Int {
        return subtreeUnbalanceFlags;
    }

    public function updateUnbalanceFlag(childIdx:Int):Void {
        var child = nodes[childIdx];

        if (child.isSubtreeUnbalanced() || child.isDirectlyUnbalanced()) {
            setUnbalanceFlag(childIdx);
        }
        else {
            clearUnbalanceFlag(childIdx);
        }
    }

    public function combinedTextInfo():TextInfo {
        var bytes = 0;
        var chars = 0;
        var utf16 = 0;
        var lf = 0;
        var crlf = 0;
        for (i in 0...len) {
            var next = info[i];
            bytes += next.bytes;
            chars += next.chars;
            utf16 += next.utf16;
            lf += next.lineBreaksLf;
            crlf += next.lineBreaksCrLf;
        }
        return new TextInfo(bytes, chars, utf16, lf, crlf);
    }

    /**
     * Same as `search_byte_idx()`, except that it only calculates the
     * left-side-accumulated _byte_ index rather than the full text info.
     *
     * This also has an additional parameter: `biasLeft`.  This should be false
     * if you're looking for the node that actually contains the given byte.
     * However, if you're searching for a *gap* (e.g. when inserting) and want
     * to traverse into nodes to the left of the boundary when there's a choice,
     * set it to true.
     *
     * Returns the child index, and sets `Children.searchAccBytes` to its left
     * accumulated byte index.
     *
     * One-past-the end is valid, and will return the last child.
     */
    public function searchByteIdxOnly(byteIdx:Int, biasLeft:Bool):Int {
        var accumByteIdx = 0;
        var idx = 0;
        var last = len - 1;
        while (idx < last) {
            var nextAccum = accumByteIdx + info[idx].bytes;
            if (byteIdx < nextAccum || (biasLeft && byteIdx == nextAccum)) {
                break;
            }
            accumByteIdx = nextAccum;
            idx++;
        }
        searchAccBytes = accumByteIdx;
        return idx;
    }

    //===========================================================================
    // The guts of Children (Rust's `inner::ChildrenInternal`).

    static inline function rangeBitmask(rangeLow:Int, rangeHigh:Int):Int {
        var a = (~0) << rangeLow;
        var b = rangeHigh >= 32 ? 0 : (~0) << rangeHigh;
        return a & ~b;
    }

    function innerPush(itemInfo:TextInfo, itemNode:Node):Void {
        if (len >= MAX_CHILDREN)
            throw new RopeyException(OutOfBounds, 'assertion failed: self.len() < MAX_CHILDREN');
        info[len] = itemInfo;
        nodes[len] = itemNode;
        len++;
    }

    function innerInsert(idx:Int, itemInfo:TextInfo, itemNode:Node):Void {
        if (idx > len)
            throw new RopeyException(OutOfBounds, 'assertion failed: idx <= self.len()');
        if (len >= MAX_CHILDREN)
            throw new RopeyException(OutOfBounds, 'assertion failed: self.len() < MAX_CHILDREN');

        // Shift over the elements to make room for the new inserted item.
        var i = len;
        while (i > idx) {
            nodes[i] = nodes[i - 1];
            info[i] = info[i - 1];
            i--;
        }

        // Put the new items in.
        info[idx] = itemInfo;
        nodes[idx] = itemNode;

        // The unbalance flags.
        var lowMask = rangeBitmask(0, idx);
        var highMask = rangeBitmask(idx, len);
        subtreeUnbalanceFlags = ((subtreeUnbalanceFlags & highMask) << 1) | (subtreeUnbalanceFlags & lowMask);

        len++;
    }

    /**
     * Removes a range of items from `other`, and inserts them into `this`.
     *
     * Throws if there isn't enough room to insert, or if the insert index
     * or from-range are out of bounds.
     */
    public function stealRangeFrom(toIdx:Int, other:Children, fromStart:Int, fromEnd:Int):Void {
        if (toIdx > len)
            throw new RopeyException(OutOfBounds, 'assertion failed: to_idx <= self.len()');
        if (fromStart > fromEnd)
            throw new RopeyException(InvalidRange, 'assertion failed: from_range[0] <= from_range[1]');
        if (fromEnd > other.len)
            throw new RopeyException(OutOfBounds, 'assertion failed: from_range[1] <= other.len()');

        var fromLen = fromEnd - fromStart;
        if (fromLen > MAX_CHILDREN - len)
            throw new RopeyException(OutOfBounds, 'assertion failed: from_len <= (MAX_CHILDREN - self.len())');

        var toEndIdx = toIdx + fromLen;

        // Step 1: make room in `this` for the items.
        {
            var i = len - 1;
            while (i >= toIdx) {
                nodes[i + fromLen] = nodes[i];
                info[i + fromLen] = info[i];
                i--;
            }

            // The unbalance flags.
            var lowMask = rangeBitmask(0, toIdx);
            var highMask = rangeBitmask(toIdx, len);
            subtreeUnbalanceFlags = ((subtreeUnbalanceFlags & highMask) << fromLen) | (subtreeUnbalanceFlags & lowMask);

            len += fromLen;
        }

        // Step 2: move the items from other to this.
        {
            for (i in 0...fromLen) {
                nodes[toIdx + i] = other.nodes[fromStart + i];
                info[toIdx + i] = other.info[fromStart + i];
            }

            // The unbalance flags.
            var mask = rangeBitmask(fromStart, fromEnd);
            if (fromStart <= toIdx) {
                subtreeUnbalanceFlags |= (other.subtreeUnbalanceFlags & mask) << (toIdx - fromStart);
            }
            else {
                subtreeUnbalanceFlags |= (other.subtreeUnbalanceFlags & mask) >>> (fromStart - toIdx);
            }
        }

        // Step 3: shift over the items in `other` to fill the gap.
        {
            var i = fromStart;
            while (i + fromLen < other.len) {
                other.nodes[i] = other.nodes[i + fromLen];
                other.info[i] = other.info[i + fromLen];
                i++;
            }
            while (i < other.len) {
                other.nodes[i] = null;
                other.info[i] = null;
                i++;
            }

            // The unbalance flags.
            var lowMask = rangeBitmask(0, fromStart);
            var highMask = rangeBitmask(fromEnd, other.len);
            other.subtreeUnbalanceFlags = ((other.subtreeUnbalanceFlags & highMask) >>> fromLen) | (other.subtreeUnbalanceFlags & lowMask);

            other.len -= fromLen;
        }
    }

}
