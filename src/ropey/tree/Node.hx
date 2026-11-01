// Ported from ropey 2.0.0-beta.1: src/tree/node.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey.tree;

import haxe.io.Bytes;
import ropey.StrUtils.*;
import ropey.tree.Constants.MAX_CHILDREN;
import ropey.tree.Constants.MAX_TEXT_SIZE;
import ropey.tree.Constants.MIN_CHILDREN;
import ropey.tree.Constants.MIN_TEXT_SIZE;

/**
 * A node of the rope tree: either a leaf (`Text`) or an internal node
 * (`Children`).
 *
 * Rust's `Node` is `enum { Internal(Arc<Children>), Leaf(Arc<Text>) }`, and
 * ropes share nodes between clones, copying them on write with
 * `Arc::make_mut()`. Here the `Text` and `Children` objects are the shared
 * values themselves, and `rc` emulates the `Arc` strong count:
 *
 * - every tree slot (a `Children` entry or a rope root) holding a node counts
 *   as one reference;
 * - cloning a rope or a `Children` increments the counts of the nodes it
 *   shares;
 * - a method that needs to mutate a node first makes it unique (`makeMut()`):
 *   when the node is shared, its count is decremented and a copy is used;
 * - nodes dropped by the tree are released, recursively when their count
 *   reaches zero, like Rust's `Drop`.
 *
 * Ropes collected by the garbage collector never release their nodes, so a
 * count can only be too high, never too low: at worst a node is copied when it
 * was not shared anymore.
 *
 * Methods that mutate in Rust (`&mut self`) return the node to store back in
 * the parent slot, which is `this` or its unique copy.
 */
class Node {

    /**
     * Number of tree slots referencing this node (the `Arc` strong count).
     */
    public var rc:Int = 1;

    public final isLeaf:Bool;

    function new(isLeaf:Bool) {
        this.isLeaf = isLeaf;
    }

    /**
     * Deep enough copy of this node data, with a reference count of 1.
     */
    function cloneData():Node {
        throw 'abstract';
    }

    /**
     * Returns this node if it is not shared, else a unique copy of it
     * (`Arc::make_mut()`).
     */
    public inline function makeMut():Node {
        if (rc > 1) {
            rc--;
            return cloneData();
        }
        return this;
    }

    /**
     * Drops a reference to the given node.
     */
    public static function release(node:Node):Void {
        node.rc--;
        if (node.rc == 0 && !node.isLeaf) {
            var children:Children = cast node;
            for (i in 0...children.len) {
                release(children.nodes[i]);
            }
        }
    }

    /**
     * Shallowly computes the text info of this node.
     *
     * Assumes that the info of this node's children is up to date.
     */
    public function textInfo():TextInfo {
        if (isLeaf) {
            var text:Text = cast this;
            return TextInfo.fromStr(text.buf, 0, text.len);
        }
        else {
            return (cast this : Children).combinedTextInfo();
        }
    }

    public inline function isInternal():Bool {
        return !isLeaf;
    }

    public inline function isDirectlyUnbalanced():Bool {
        return if (isLeaf) {
            (cast this : Text).len < MIN_TEXT_SIZE;
        }
        else {
            (cast this : Children).len < MIN_CHILDREN;
        }
    }

    public inline function isSubtreeUnbalanced():Bool {
        return if (isLeaf) {
            false;
        }
        else {
            (cast this : Children).isAnyUnbalanced();
        }
    }

    public inline function childCount():Int {
        return children().len;
    }

    public inline function children():Children {
        if (isLeaf)
            throw new RopeyException(InvalidRange, 'explicit panic');
        return cast this;
    }

    public inline function leafText():Text {
        if (!isLeaf)
            throw new RopeyException(InvalidRange, 'explicit panic');
        return cast this;
    }

    /**
     * Note: `nodeInfo` is the text info *for the node this is being called
     * on*.  This is because node info for a child is stored in the parent.
     *
     * - `biasLeft`: if true, takes the left node when `byteIdx` hits a
     *   node boundary.  If false, takes the right node.
     *
     * On success, fills `result` with the node to store back in the parent
     * slot, its new text info, and if a split was caused the right side of the
     * split (the left remaining as the current node) and its text info.
     *
     * On failure, throws `RopeyException(NonCharBoundary)`.
     */
    public function insertAtByteIdx(byteIdx:Int, text:Bytes, start:Int, end:Int, biasLeft:Bool, nodeInfo:TextInfo, result:InsertResult):Void {
        if (isLeaf) {
            var leafText:Text = cast this;
            if (!leafText.isCharBoundary(byteIdx)) {
                throw new RopeyException(NonCharBoundary);
            }

            leafText = cast makeMut();
            if (end - start <= leafText.freeCapacity()) {
                // Enough room to insert.
                var newInfo = leafText.insertStrAndUpdateInfo(byteIdx, text, start, end, nodeInfo);
                result.node = leafText;
                result.info = newInfo;
                result.rightInfo = null;
                result.right = null;
            }
            else {
                // Not enough room to insert.  Need to split into two nodes.
                var rightText = leafText.insertSplit(byteIdx, text, start, end);
                result.node = leafText;
                result.info = leafText.textInfo();
                result.rightInfo = rightText.textInfo();
                result.right = rightText;
            }
        }
        else {
            var children:Children = cast makeMut();

            // Find the child we care about.
            var childI = children.searchByteIdxOnly(byteIdx, biasLeft);
            var accByteIdx = Children.searchAccBytes;
            var info = children.info[childI];

            // Recurse into the child.
            children.nodes[childI].insertAtByteIdx(byteIdx - accByteIdx, text, start, end, biasLeft, info, result);
            var child = result.node;
            if (child != children.nodes[childI]) {
                // The child was shared and has been copied.
                children.nodes[childI] = child;
            }
            var lInfo = result.info;
            var rInfo = result.rightInfo;
            var rNode = result.right;
            children.info[childI] = lInfo;
            children.updateUnbalanceFlag(childI);

            // Handle the residual node if there is one and return.
            if (rNode != null) {
                if (children.len < MAX_CHILDREN) {
                    var newNodeInfo = nodeInfo.sub(info).add(lInfo).add(rInfo);
                    children.insert(childI + 1, rInfo, rNode);
                    result.node = children;
                    result.info = newNodeInfo;
                    result.rightInfo = null;
                    result.right = null;
                }
                else {
                    var r = children.insertSplit(childI + 1, rInfo, rNode);
                    var rCombinedInfo = r.combinedTextInfo();
                    result.node = children;
                    result.info = children.combinedTextInfo();
                    result.rightInfo = rCombinedInfo;
                    result.right = r;
                }
            }
            else {
                var newNodeInfo = nodeInfo.sub(info).add(lInfo);
                result.node = children;
                result.info = newNodeInfo;
                result.rightInfo = null;
                result.right = null;
            }
        }
    }

    /**
     * Fills `result` with the node to store back in the parent slot, its
     * updated text info after removal, as well as a bool indicating if the
     * removal created a fresh chunk boundary.  The bool is needed to know if a
     * split-CRLF check is needed.
     *
     * NOTE: even when this fails, some removal may have happened.
     */
    public function removeByteRange(rangeStart:Int, rangeEnd:Int, nodeInfo:TextInfo, result:RemoveResult):Void {
        if (isLeaf) {
            var leafText:Text = cast this;

            var createdBoundary = (rangeStart == 0 || rangeEnd == leafText.len) && rangeStart < rangeEnd;

            if (!leafText.isCharBoundary(rangeStart) || !leafText.isCharBoundary(rangeEnd)) {
                throw new RopeyException(NonCharBoundary);
            }

            leafText = cast makeMut();
            var newNodeInfo = leafText.removeRangeAndUpdateInfo(rangeStart, rangeEnd, nodeInfo);

            result.node = leafText;
            result.info = newNodeInfo;
            result.createdBoundary = createdBoundary;
        }
        else {
            var children:Children = cast makeMut();

            // Find the start and end children of the range, and
            // their left-side byte indices within this node.
            var startChildI = children.searchByteIdxOnly(rangeStart, false);
            var startChildLeftByteIdx = Children.searchAccBytes;
            var endChildI = children.searchByteIdxOnly(rangeEnd, false);
            var endChildLeftByteIdx = Children.searchAccBytes;

            // Text info of the the start and end children.
            var startInfo = children.info[startChildI];
            var endInfo = children.info[endChildI];

            // Compute the start index relative to the contents of the
            // start child, and the end index relative to the contents
            // of the end child.
            var startByteIdx = rangeStart - startChildLeftByteIdx;
            var endByteIdx = rangeEnd - endChildLeftByteIdx;

            // Simple case: the removal is entirely within a single child.
            if (startChildI == endChildI) {
                if (startByteIdx == 0 && endByteIdx == startInfo.bytes) {
                    // The removal happens to be exactly the whole child.
                    var newNodeInfo = nodeInfo.sub(children.info[startChildI]);
                    release(children.remove(startChildI));
                    result.node = children;
                    result.info = newNodeInfo;
                    result.createdBoundary = true;
                }
                else {
                    children.nodes[startChildI].removeByteRange(startByteIdx, endByteIdx, startInfo, result);
                    storeChild(children, startChildI, result.node);
                    var newChildInfo = result.info;
                    var createdBoundary = result.createdBoundary;
                    var newNodeInfo = nodeInfo.sub(children.info[startChildI]).add(newChildInfo);
                    children.info[startChildI] = newChildInfo;
                    children.updateUnbalanceFlag(startChildI);
                    result.node = children;
                    result.info = newNodeInfo;
                    result.createdBoundary = createdBoundary;
                }
            }
            // More complex case: the removal spans multiple children.
            else {
                var removeWholeStartChild = startByteIdx == 0;
                var removeWholeEndChild = endByteIdx == children.info[endChildI].bytes;

                // Handle partial removal of leftmost child.
                if (!removeWholeStartChild) {
                    children.nodes[startChildI].removeByteRange(startByteIdx, startInfo.bytes, startInfo, result);
                    storeChild(children, startChildI, result.node);
                    children.info[startChildI] = result.info;
                    children.updateUnbalanceFlag(startChildI);
                }

                // Handle partial removal of rightmost child.
                if (!removeWholeEndChild) {
                    children.nodes[endChildI].removeByteRange(0, endByteIdx, endInfo, result);
                    storeChild(children, endChildI, result.node);
                    children.info[endChildI] = result.info;
                    children.updateUnbalanceFlag(endChildI);
                }

                // Remove nodes that need to be completely removed.
                var removalStart = removeWholeStartChild ? startChildI : startChildI + 1;
                var removalEnd = removeWholeEndChild ? endChildI + 1 : endChildI;
                if (removalStart < removalEnd) {
                    children.removeMultiple(removalStart, removalEnd);
                }

                // If the removal spanned multiple nodes, it had to create a
                // new boundary.
                result.node = children;
                result.info = children.combinedTextInfo();
                result.createdBoundary = true;
            }
        }
    }

    static inline function storeChild(children:Children, idx:Int, node:Node):Void {
        if (children.nodes[idx] != node) {
            children.nodes[idx] = node;
        }
    }

    /**
     * Does one rebalancing step, and returns the node to store back in the
     * parent slot.
     */
    public function partialRebalance():Node {
        if (isLeaf) {
            return this;
        }
        else {
            var childI = (cast this : Children).firstUnbalancedChildIdx();
            if (childI != -1) {
                var children:Children = cast makeMut();

                // First: dive deep.
                if (children.nodes[childI].isSubtreeUnbalanced()) {
                    storeChild(children, childI, children.nodes[childI].partialRebalance());
                    children.updateUnbalanceFlag(childI);
                }

                // Then: do a rebalance at this level if needed.
                if (children.nodes[childI].isDirectlyUnbalanced() && children.len > 1) {
                    if (childI < (children.len - 1)) {
                        children.mergeDistribute(childI, childI + 1);
                    }
                    else {
                        children.mergeDistribute(childI - 1, childI);
                    }
                }
                return children;
            }
            return this;
        }
    }

    //---------------------------------------------------------
    // `Text` fetching.
    //
    // Rust's `get_text_at_metric()` returns the `Text` that contains the
    // given index of a metric, and the left-side info of where it starts.
    // Haxe has no cheap tuples, so each metric conversion of
    // `shared_impl.rs` that uses it is inlined here: they accumulate the
    // left-side info in local variables while going down the tree.

    /**
     * `start_info.chars + text.byte_to_char_idx(byte_idx - start_info.bytes)`
     * with `(text, start_info) = get_text_at_byte(byte_idx)`.
     */
    public function treeByteToCharIdx(byteIdx:Int):Int {
        var node = this;
        var idx = byteIdx;
        var leftBytes = 0;
        var leftChars = 0;
        while (!node.isLeaf) {
            var children:Children = cast node;
            // search_by(|end| byte_idx < end.bytes)
            var accBytes = 0;
            var accChars = 0;
            var i = 0;
            var last = children.len - 1;
            while (i < last) {
                var info = children.info[i];
                if (idx < accBytes + info.bytes)
                    break;
                accBytes += info.bytes;
                accChars += info.chars;
                i++;
            }
            leftBytes += accBytes;
            leftChars += accChars;
            node = children.nodes[i];
            idx -= accBytes;
        }
        var text:Text = cast node;
        return leftChars + text.byteToCharIdx(byteIdx - leftBytes);
    }

    /**
     * `start_info.bytes + text.char_to_byte_idx(char_idx - start_info.chars)`
     * with `(text, start_info) = get_text_at_char(char_idx)`.
     */
    public function treeCharToByteIdx(charIdx:Int):Int {
        var node = this;
        var idx = charIdx;
        var leftBytes = 0;
        var leftChars = 0;
        while (!node.isLeaf) {
            var children:Children = cast node;
            // search_by(|end| char_idx < end.chars)
            var accBytes = 0;
            var accChars = 0;
            var i = 0;
            var last = children.len - 1;
            while (i < last) {
                var info = children.info[i];
                if (idx < accChars + info.chars)
                    break;
                accBytes += info.bytes;
                accChars += info.chars;
                i++;
            }
            leftBytes += accBytes;
            leftChars += accChars;
            node = children.nodes[i];
            idx -= accChars;
        }
        var text:Text = cast node;
        return leftBytes + text.charToByteIdx(charIdx - leftChars);
    }

    /**
     * `start_info.utf16 + text.byte_to_utf16_idx(byte_idx - start_info.bytes)`
     * with `(text, start_info) = get_text_at_byte(byte_idx)`.
     */
    public function treeByteToUtf16Idx(byteIdx:Int):Int {
        var node = this;
        var idx = byteIdx;
        var leftBytes = 0;
        var leftUtf16 = 0;
        while (!node.isLeaf) {
            var children:Children = cast node;
            // search_by(|end| byte_idx < end.bytes)
            var accBytes = 0;
            var accUtf16 = 0;
            var i = 0;
            var last = children.len - 1;
            while (i < last) {
                var info = children.info[i];
                if (idx < accBytes + info.bytes)
                    break;
                accBytes += info.bytes;
                accUtf16 += info.utf16;
                i++;
            }
            leftBytes += accBytes;
            leftUtf16 += accUtf16;
            node = children.nodes[i];
            idx -= accBytes;
        }
        var text:Text = cast node;
        return leftUtf16 + text.byteToUtf16Idx(byteIdx - leftBytes);
    }

    /**
     * `start_info.bytes + text.utf16_to_byte_idx(utf16_idx - start_info.utf16)`
     * with `(text, start_info) = get_text_at_utf16(utf16_idx)`.
     */
    public function treeUtf16ToByteIdx(utf16Idx:Int):Int {
        var node = this;
        var idx = utf16Idx;
        var leftBytes = 0;
        var leftUtf16 = 0;
        while (!node.isLeaf) {
            var children:Children = cast node;
            // search_by(|end| utf16_idx < end.utf16)
            var accBytes = 0;
            var accUtf16 = 0;
            var i = 0;
            var last = children.len - 1;
            while (i < last) {
                var info = children.info[i];
                if (idx < accUtf16 + info.utf16)
                    break;
                accBytes += info.bytes;
                accUtf16 += info.utf16;
                i++;
            }
            leftBytes += accBytes;
            leftUtf16 += accUtf16;
            node = children.nodes[i];
            idx -= accUtf16;
        }
        var text:Text = cast node;
        return leftBytes + text.utf16ToByteIdx(utf16Idx - leftUtf16);
    }

    /**
     * `start_info.line_breaks(line_type) + text.byte_to_line_idx(byte_idx - start_info.bytes, line_type)`
     * with `(text, start_info) = get_text_at_byte(byte_idx)`.
     */
    public function treeByteToLineIdx(byteIdx:Int, lineType:LineType):Int {
        var node = this;
        var idx = byteIdx;
        var leftBytes = 0;
        var leftBreaks = 0;
        while (!node.isLeaf) {
            var children:Children = cast node;
            // search_by(|end| byte_idx < end.bytes)
            var accBytes = 0;
            var accBreaks = 0;
            var i = 0;
            var last = children.len - 1;
            while (i < last) {
                var info = children.info[i];
                if (idx < accBytes + info.bytes)
                    break;
                accBytes += info.bytes;
                accBreaks += info.lineBreaks(lineType);
                i++;
            }
            leftBytes += accBytes;
            leftBreaks += accBreaks;
            node = children.nodes[i];
            idx -= accBytes;
        }
        var text:Text = cast node;
        return leftBreaks + text.byteToLineIdx(byteIdx - leftBytes, lineType);
    }

    /**
     * `start_info.bytes + text.line_to_byte_idx(line_idx - start_info.line_breaks(line_type), line_type)`
     * with `(text, start_info) = get_text_at_line_break(line_idx, line_type)`.
     */
    public function treeLineToByteIdx(lineIdx:Int, lineType:LineType):Int {
        var node = this;
        var idx = lineIdx;
        var leftBytes = 0;
        var leftBreaks = 0;
        while (!node.isLeaf) {
            var children:Children = cast node;
            // search_by(|end| line_break_idx <= end.line_breaks(line_type))
            var accBytes = 0;
            var accBreaks = 0;
            var i = 0;
            var last = children.len - 1;
            while (i < last) {
                var info = children.info[i];
                var nextBreaks = accBreaks + info.lineBreaks(lineType);
                if (idx <= nextBreaks)
                    break;
                accBytes += info.bytes;
                accBreaks = nextBreaks;
                i++;
            }
            leftBytes += accBytes;
            leftBreaks += accBreaks;
            node = children.nodes[i];
            idx -= accBreaks;
        }
        var text:Text = cast node;
        return leftBytes + text.lineToByteIdx(lineIdx - leftBreaks, lineType);
    }

    /**
     * `get_text_at_byte()` returning only the `Text`, with its start byte
     * index stored in `Node.textStartBytes` (used where Rust only reads
     * `start_info.bytes`).
     */
    public function getTextAtByte(byteIdx:Int):Text {
        var node = this;
        var idx = byteIdx;
        var leftBytes = 0;
        while (!node.isLeaf) {
            var children:Children = cast node;
            // search_by(|end| byte_idx < end.bytes)
            var accBytes = 0;
            var i = 0;
            var last = children.len - 1;
            while (i < last) {
                var info = children.info[i];
                if (idx < accBytes + info.bytes)
                    break;
                accBytes += info.bytes;
                i++;
            }
            leftBytes += accBytes;
            node = children.nodes[i];
            idx -= accBytes;
        }
        textStartBytes = leftBytes;
        return cast node;
    }

    /**
     * Like `getTextAtByte()` but uses `search_byte_idx_only()` like Rust's
     * `get_text_at_byte_fast()`.
     *
     * Returns the text itself, and stores the byte offset of the start of its
     * left edge in the context of the whole text of the node tree in
     * `Node.textStartBytes`.
     */
    public function getTextAtByteFast(byteIdx:Int):Text {
        var idx = byteIdx;
        var node = this;

        while (!node.isLeaf) {
            var children:Children = cast node;
            var childI = children.searchByteIdxOnly(idx, false);
            node = children.nodes[childI];
            idx -= Children.searchAccBytes;
        }
        textStartBytes = byteIdx - idx;
        return cast node;
    }

    /**
     * Second result of `getTextAtByte()` and `getTextAtByteFast()`.
     */
    public static var textStartBytes:Int = 0;

    //---------------------------------------------------------
    // Misc.

    /**
     * Returns whether splitting at `byteIdx` would split a CRLF pair, if such
     * a split would be relevant to the line-counting metrics of `lineType`.
     *
     * Specifically, CRLF pairs are not relevant to LF-only line metrics, so
     * for that line type this will always return false.  Otherwise it will
     * return if a CRLF pair would be split.
     */
    public function isRelevantCrlfSplit(byteIdx:Int, lineType:LineType):Bool {
        return switch lineType {
            case LF:
                false;
            case LF_CR:
                var text = getTextAtByte(byteIdx);
                var idx = byteIdx - textStartBytes;
                endsWithCr(text.buf, 0, idx) && startsWithLf(text.buf, idx, text.len);
        }
    }

    //---------------------------------------------------------
    // Debugging/testing helpers.

    /**
     * Checks that all leaf nodes are at the same depth.
     */
    public function assertEqualLeafDepth():Int {
        if (isLeaf) {
            return 1;
        }
        else {
            var children:Children = cast this;
            var firstDepth = children.nodes[0].assertEqualLeafDepth();
            for (i in 1...children.len) {
                if (children.nodes[i].assertEqualLeafDepth() != firstDepth)
                    throw 'assertion failed: equal leaf depth';
            }
            return firstDepth + 1;
        }
    }

    /**
     * Checks that there are no empty internal nodes in the tree.
     */
    public function assertNoEmptyInternal():Void {
        if (!isLeaf) {
            var children:Children = cast this;
            if (children.len <= 0)
                throw 'assertion failed: children.len() > 0';
            for (i in 0...children.len) {
                children.nodes[i].assertNoEmptyInternal();
            }
        }
    }

    /**
     * Checks that there are no empty leaf nodes in the tree.
     */
    public function assertNoEmptyLeaf():Void {
        if (isLeaf) {
            if ((cast this : Text).len <= 0)
                throw 'assertion failed: text.len() > 0';
        }
        else {
            var children:Children = cast this;
            for (i in 0...children.len) {
                children.nodes[i].assertNoEmptyLeaf();
            }
        }
    }

    /**
     * Checks that all cached TextInfo in the tree is correct.
     */
    public function assertAccurateTextInfo():TextInfo {
        if (isLeaf) {
            // Freshly compute the relevant info from scratch.
            var text:Text = cast this;
            return TextInfo.fromStr(text.buf, 0, text.len);
        }
        else {
            var children:Children = cast this;
            var accInfo = TextInfo.empty();
            for (i in 0...children.len) {
                var info = children.info[i];
                if (!info.equals(children.nodes[i].assertAccurateTextInfo()))
                    throw 'assertion failed: accurate text info';
                accInfo = accInfo.add(info);
            }
            return accInfo;
        }
    }

    /**
     * Checks that all the unbalance flags in the tree are correct.
     *
     * Note: the return value is not "success", it's used in the recursion.
     */
    public function assertAccurateUnbalanceFlags():Bool {
        if (isLeaf) {
            // Freshly compute whether the leaf is undersized.
            return (cast this : Text).len < MIN_TEXT_SIZE;
        }
        else {
            var children:Children = cast this;
            var anyUnbalanced = false;
            for (i in 0...children.len) {
                var unbalanced = children.nodes[i].assertAccurateUnbalanceFlags() || children.nodes[i].isDirectlyUnbalanced();
                if (unbalanced != children.isNodeUnbalanced(i))
                    throw 'assertion failed: accurate unbalance flags';
                anyUnbalanced = anyUnbalanced || unbalanced;
            }
            return anyUnbalanced;
        }
    }

}

/**
 * Result of `Node.insertAtByteIdx()` (`(TextInfo, Option<(TextInfo, Node)>)`
 * in Rust), plus the node to store back in the parent slot.
 */
class InsertResult {

    public var node:Node = null;

    public var info:TextInfo = null;

    public var rightInfo:TextInfo = null;

    public var right:Node = null;

    public function new() {}

}

/**
 * Result of `Node.removeByteRange()` (`(TextInfo, bool)` in Rust), plus the
 * node to store back in the parent slot.
 */
class RemoveResult {

    public var node:Node = null;

    public var info:TextInfo = null;

    public var createdBoundary:Bool = false;

    public function new() {}

}
