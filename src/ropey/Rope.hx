// Ported from ropey 2.0.0-beta.1: src/rope.rs
// Original code Copyright (c) 2023 Nathan Vegdahl, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe. See README.md.

package ropey;

import haxe.io.Bytes;
import ropey.StrUtils.*;
import ropey.tree.Children;
import ropey.tree.Constants.MAX_TEXT_SIZE;
import ropey.tree.Node;
import ropey.tree.Text;
import ropey.tree.TextInfo;

/**
 * A UTF-8 text rope.
 *
 * The time complexity of nearly all edit and query operations on `Rope` are
 * worst-case `O(log N)` in the length of the rope.
 *
 * Cloning `Rope`s is extremely cheap, running in `O(1)` time and taking a
 * small constant amount of memory for the new clone, regardless of text size.
 * This is accomplished by data sharing between `Rope` clones.  The memory used
 * by clones only grows incrementally as their contents diverge due to edits.
 *
 * See `RopeBase` for the query methods shared with `RopeSlice`.
 */
class Rope extends RopeBase {

    //---------------------------------------------------------
    // Constructors.

    /**
     * Creates an empty `Rope`.
     *
     * (The arguments are internal: ropes made by `RopeBuilder` pass their
     * tree directly.)
     */
    public function new(?_root:Node, ?_rootInfo:TextInfo) {
        super();
        if (_root != null) {
            root = _root;
            rootInfo = _rootInfo;
            rangeStart = 0;
            rangeEnd = _rootInfo.bytes;
        }
        else {
            root = new Text();
            rootInfo = TextInfo.empty();
            rangeStart = 0;
            rangeEnd = 0;
        }
    }

    /**
     * Creates a `Rope` from a string.
     *
     * Runs in O(N) time.
     */
    public static function fromStr(text:String):Rope {
        var bytes = Utf8.encode(text);
        return new RopeBuilder().buildAtOnce(bytes, 0, bytes.length);
    }

    /**
     * Creates a `Rope` from UTF-8 bytes (`text[start...end]`, which must be
     * valid UTF-8).
     */
    public static function fromUtf8(text:Bytes, start:Int = 0, end:Int = -1):Rope {
        if (end < 0)
            end = text.length;
        return new RopeBuilder().buildAtOnce(text, start, end);
    }

    /**
     * `Rope::from(RopeSlice)`.
     */
    public static function fromSlice(rs:RopeSlice):Rope {
        var rb = new RopeBuilder();
        var chunks = rs.chunks();
        while (chunks.nextRaw()) {
            rb.appendBytes(chunks.rawBytes, chunks.rawStart, chunks.rawEnd);
        }
        return rb.finish();
    }

    /**
     * Cheap `O(1)` clone, sharing the tree with this rope.
     */
    public function clone():Rope {
        root.rc++;
        var result = new Rope(root, rootInfo);
        result.rangeStart = rangeStart;
        result.rangeEnd = rangeEnd;
        return result;
    }

    //-----------------------------------------------------------------------
    // Edit methods

    /**
     * Inserts `text` at byte index `byteIdx`.
     *
     * Runs in O(M log N) time, where N is the length of the `Rope` and M
     * is the length of `text`.
     *
     * Throws:
     *
     * - If `byteIdx` is out of bounds (i.e. `byteIdx > len()`).
     * - If `byteIdx` is not on a char boundary.
     */
    public function insert(byteIdx:Int, text:String):Void {
        var bytes = Utf8.encode(text);
        var error = tryInsertBytes(byteIdx, bytes, 0, bytes.length);
        if (error != null)
            throw new RopeyException(error);
    }

    /**
     * Inserts the UTF-8 text `text[start...end]` at byte index `byteIdx`.
     */
    public function insertBytes(byteIdx:Int, text:Bytes, start:Int, end:Int):Void {
        var error = tryInsertBytes(byteIdx, text, start, end);
        if (error != null)
            throw new RopeyException(error);
    }

    /**
     * Inserts a single char (code point) `ch` at byte index `byteIdx`.
     *
     * Runs in O(log N) time.
     */
    public function insertChar(byteIdx:Int, ch:Int):Void {
        var bytes = Utf8.encodeChar(ch);
        var error = tryInsertBytes(byteIdx, bytes, 0, bytes.length);
        if (error != null)
            throw new RopeyException(error);
    }

    /**
     * Removes the text in the given byte index range `start...end` (Rust's
     * `remove(start..end)`; use `removeFrom(start)` for `start..`).
     *
     * Runs in O(M + log N) time, where N is the length of the `Rope` and M
     * is the length of the range being removed.
     *
     * Throws:
     *
     * - If the start of the range is greater than the end.
     * - If the end of the range is out of bounds (i.e. `end > len()`).
     * - If the range ends are not on char boundaries.
     */
    public function remove(start:Int, end:Int):Void {
        var error = tryRemove(start, end);
        if (error != null)
            throw new RopeyException(error);
    }

    /**
     * Rust's `remove(start..)`.
     */
    public inline function removeFrom(start:Int):Void {
        remove(start, len());
    }

    /**
     * Converts a "disconnected slice" into a proper rope, in preparation for
     * edits.
     */
    function trimDisconnectedSlice():Void {
        var trimRangeStart0 = 0;
        var trimRangeStart1 = rangeStart;
        var trimRangeEnd0 = rangeEnd;
        var trimRangeEnd1 = rootInfo.bytes;

        // Note: unlike with normal removal, we don't have to worry about crlf
        // splits because we know we're trimming off the ends, not removing a
        // section in the middle.
        removeCoreImpl(trimRangeEnd0, trimRangeEnd1);
        removeCoreImpl(trimRangeStart0, trimRangeStart1);

        rangeStart = 0;
        rangeEnd = rootInfo.bytes;
    }

    //---------------------------------------------------------
    // Misc. internal methods.

    /**
     * Iteratively replaces the root node with its child if it only has
     * one child.
     */
    @:allow(ropey)
    function pullUpSingularNodes():Void {
        while ((!root.isLeaf) && root.childCount() == 1) {
            var child = (cast root : Children).nodes[0];
            child.rc++;
            var oldRoot = root;
            root = child;
            Node.release(oldRoot);
        }
    }

    //---------------------------------------------------------
    // Debugging and testing helpers.

    /**
     * NOT PART OF THE PUBLIC API.
     */
    public function assertInvariants():Void {
        assertEqualLeafDepth();
        assertNoEmptyInternal();
        assertNoEmptyNonRootLeaf();
        assertNoCrlfSplits();
        assertAccurateTextInfo();
        assertAccurateUnbalanceFlags();
    }

    public function assertEqualLeafDepth():Void {
        root.assertEqualLeafDepth();
    }

    public function assertNoEmptyInternal():Void {
        root.assertNoEmptyInternal();
    }

    public function assertNoEmptyNonRootLeaf():Void {
        if (root.isLeaf) {
            // The root is allowed to be empty if it's a leaf.
            return;
        }
        root.assertNoEmptyLeaf();
    }

    public function assertNoCrlfSplits():Void {
        var lastEndsWithCr = false;
        var chunks = chunks();
        while (chunks.nextRaw()) {
            var b = chunks.rawBytes;
            var s = chunks.rawStart;
            var e = chunks.rawEnd;
            if (e == s)
                continue;
            if (lastEndsWithCr && startsWithLf(b, s, e)) {
                throw 'CRLF split found.';
            }
            lastEndsWithCr = endsWithCr(b, s, e);
        }
    }

    public function assertAccurateTextInfo():Void {
        if (!rootInfo.equals(root.assertAccurateTextInfo()))
            throw 'assertion failed: self.root_info == self.root.assert_accurate_text_info()';
    }

    public function assertAccurateUnbalanceFlags():Void {
        root.assertAccurateUnbalanceFlags();
    }

    /**
     * NOT PART OF THE PUBLIC API.
     *
     * Attempts to fully rebalance the tree within `maxIterations`.
     *
     * Returns whether it fully rebalanced the tree, and stores the actual
     * number of iterations done in `lastRebalanceIterations`.
     */
    public function attemptFullRebalance(maxIterations:Int):Bool {
        var iterCount = 0;

        while (root.isSubtreeUnbalanced()) {
            if (iterCount >= maxIterations) {
                lastRebalanceIterations = iterCount;
                return false;
            }

            root = root.partialRebalance();
            pullUpSingularNodes();
            iterCount++;
        }

        lastRebalanceIterations = iterCount;
        return true;
    }

    public var lastRebalanceIterations(default, null):Int = 0;

    //=============================================================
    // Non-panicking versions.

    /**
     * Non-panicking version of `insert()`.
     *
     * On failure this leaves the rope untouched and returns the cause of the
     * failure (null on success).
     */
    public function tryInsert(byteIdx:Int, text:String):Null<Error> {
        var bytes = Utf8.encode(text);
        return tryInsertBytes(byteIdx, bytes, 0, bytes.length);
    }

    /**
     * Non-panicking version of `insertChar()`.
     */
    public function tryInsertChar(byteIdx:Int, ch:Int):Null<Error> {
        var bytes = Utf8.encodeChar(ch);
        return tryInsertBytes(byteIdx, bytes, 0, bytes.length);
    }

    /**
     * Non-panicking version of `insertBytes()`.
     */
    public function tryInsertBytes(byteIdx:Int, text:Bytes, start:Int, end:Int):Null<Error> {
        if (byteIdx < 0 || byteIdx > len()) {
            return OutOfBounds;
        }

        // The `Node` insertion method already checks if the byte index is
        // a non-char boundary and returns the appropriate error, but that
        // method never gets called if the text is empty.  So we need to check
        // that here.
        //
        // This port checks it up front in every case: in Rust the node
        // insertion fails before modifying anything, which gives the same
        // result.
        if (!isCharBoundary(byteIdx)) {
            return NonCharBoundary;
        }

        // If this is a "disconnected slice", rather than a normal rope, then
        // we need to first trim it to a normal rope before proceeding with
        // editing.
        if (rangeStart != 0 || rangeEnd != rootInfo.bytes) {
            trimDisconnectedSlice();
        }

        // We have two cases here:
        //
        // 1. The insertion text is small enough to fit in a single node.
        // 2. The insertion text is larger than a single node can hold.
        //
        // Case #2 is handled by splitting the insertion text into node-sized
        // chunks and repeatedly inserting them, case #1 is just a special case
        // that naturally falls out of the handling of case #2.
        //
        // Additionally, we handle a starting LF specially, to avoid creating
        // split CRLF pairs.
        var startingLf = if (startsWithLf(text, start, end)) {
            // Take out the starting LF for special handling later.
            start++;
            true;
        }
        else {
            false;
        }
        while (end > start) {
            // Split a chunk off from the end of the text.
            // We do this from the end instead of the front so that the repeated
            // insertions can keep re-using the same insertion point.
            //
            // NOTE: the chunks are at most `MAX_TEXT_SIZE - 4` rather than
            // just `MAX_TEXT_SIZE` to guarantee that nodes can split into
            // node-sized chunks even in the face of multi-byte chars and
            // CRLF pairs that may prevent splits at certain byte indices.
            var textLen = end - start;
            var maxLen = MAX_TEXT_SIZE - 4;
            var splitIdx = findAppropriateSplitCeil(textLen - (maxLen < textLen ? maxLen : textLen), text, start, end);
            var insStart = start + splitIdx;
            var insEnd = end;
            end = start + splitIdx;

            // Do the insertion.
            insertCoreImpl(byteIdx, text, insStart, insEnd, false);
        }

        if (startingLf) {
            // Insert the starting LF with bias_left = true.  This ensures
            // that it gets inserted to the left of any chunk boundary, which
            // prevents by construction creating any split CRLF pairs.
            insertCoreImpl(byteIdx, LF_BYTES, 0, 1, true);
        }

        // Do a rebalancing step.
        root = root.partialRebalance();
        pullUpSingularNodes();

        return null;
    }

    /**
     * Non-panicking version of `remove()`.
     *
     * On failure this leaves the rope untouched and returns the cause of the
     * failure (null on success).
     */
    public function tryRemove(startIdx:Int, endIdx:Int):Null<Error> {
        if (startIdx > endIdx) {
            return InvalidRange;
        }

        if (startIdx < 0 || endIdx > len()) {
            return OutOfBounds;
        }

        // Unlike with insertion, for removal we have to check if the
        // indices are char boundaries ahead of time, because the nature
        // of the removal code means it might do partial removals before it
        // discovers that one of the ends isn't a char boundary.
        if (!isCharBoundary(startIdx) || !isCharBoundary(endIdx)) {
            return NonCharBoundary;
        }

        // If this is a "disconnected slice", rather than a normal rope,
        // then we need to first trim it to a normal rope before proceeding
        // with editing.
        if (rangeStart != 0 || rangeEnd != rootInfo.bytes) {
            trimDisconnectedSlice();
        }

        // Do the actual removal.
        var createdBoundary = removeCoreImpl(startIdx, endIdx);

        if (createdBoundary) {
            fixPotentialCrlfSplit(startIdx);
        }

        // Do a rebalancing step.
        root = root.partialRebalance();
        pullUpSingularNodes();

        return null;
    }

    /**
     * Rust's `try_remove(start..)`.
     */
    public inline function tryRemoveFrom(start:Int):Null<Error> {
        return tryRemove(start, len());
    }

    //---------------------------------------------------------

    static final LF_BYTES:Bytes = Bytes.ofString('\n');

    /**
     * The core insertion procedure, without any checks (like the `text` length
     * being small enough to handle with a single insertion), tree rebalancing,
     * CRLF split handling, etc.
     */
    function insertCoreImpl(byteIdx:Int, text:Bytes, start:Int, end:Int, biasLeft:Bool):Void {
        // Do the insertion.
        var result = new InsertResult();
        root.insertAtByteIdx(byteIdx, text, start, end, biasLeft, rootInfo, result);
        root = result.node;
        rootInfo = result.info;

        // Handle root split.
        if (result.right != null) {
            var leftNode = root;
            var children = new Children();
            root = children;

            children.push(rootInfo, leftNode);
            children.push(result.rightInfo, result.right);
            rootInfo = children.combinedTextInfo();
        }

        rangeEnd = rootInfo.bytes;
    }

    /**
     * The core removal procedure, without any checks (like the range being
     * well-formed), tree rebalancing, CRLF split handling, etc.
     *
     * Returns whether a fresh boundary was created.
     */
    function removeCoreImpl(start:Int, end:Int):Bool {
        // Special case: if we're removing everything, just replace with a
        // fresh new rope.  This is to ensure the invariant that an empty
        // rope is always composed of a single empty leaf, which is not
        // ensured by the general removal code.
        if (start == 0 && end == rootInfo.bytes) {
            Node.release(root);
            root = new Text();
            rootInfo = TextInfo.empty();
            rangeStart = 0;
            rangeEnd = 0;
            return false;
        }

        var result = new RemoveResult();
        root.removeByteRange(start, end, rootInfo, result);
        root = result.node;
        rootInfo = result.info;
        rangeEnd = rootInfo.bytes;

        return result.createdBoundary;
    }

    function fixPotentialCrlfSplit(byteIdx:Int):Void {
        if (byteIdx == 0 || byteIdx >= len()) {
            return;
        }

        if (byte(byteIdx - 1) == 0x0D && byte(byteIdx) == 0x0A) {
            // First remove the LF.
            removeCoreImpl(byteIdx, byteIdx + 1);

            // Then insert it again with a left bias, so it ends up in the same
            // chunk as the CR.
            insertCoreImpl(byteIdx, LF_BYTES, 0, 1, true);
        }
    }

}

private typedef InsertResult = ropey.tree.Node.InsertResult;
private typedef RemoveResult = ropey.tree.Node.RemoveResult;
