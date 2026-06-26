#!/usr/bin/env python3
"""Compute a tmux layout string that makes the active pane dominate.

Why this exists: soft-zoom's resize-pane approach (soft-zoom.sh apply_shrink)
can't reach panes buried in a same-orientation nested group that is the
window's first child — the freed space lands on an unrelated sibling and the
active pane stays a sliver. tmux's resize-pane only acts within a pane's
deepest same-orientation group; no sequence of resizes crosses an intervening
opposite-orientation group reliably. The robust fix is to rewrite the layout
string directly: maximise the active pane, sliver every other pane to 1 cell
in its split dimension, recompute all container sizes/offsets, and re-checksum.

Usage:
  soft-zoom-relayout.py <window_layout> <active_pane_number>
prints the new layout string (suitable for `tmux select-layout <string>`).
"""
import sys


class Node:
    __slots__ = ("w", "h", "x", "y", "kind", "children", "pane")

    def __init__(self, w, h, x, y):
        self.w, self.h, self.x, self.y = w, h, x, y
        self.kind = "leaf"      # "leaf" | "h" (left-right {}) | "v" (top-bottom [])
        self.children = []
        self.pane = None        # pane number for leaves


def parse(s):
    """Parse a tmux layout string (without the leading 'csum,') into a tree."""
    pos = 0

    def parse_node():
        nonlocal pos
        # WxH,x,y
        def num():
            nonlocal pos
            start = pos
            while pos < len(s) and s[pos].isdigit():
                pos += 1
            return int(s[start:pos])
        w = num(); assert s[pos] == "x"; pos += 1
        h = num(); assert s[pos] == ","; pos += 1
        x = num(); assert s[pos] == ","; pos += 1
        y = num()
        node = Node(w, h, x, y)
        if pos < len(s) and s[pos] in "{[":
            opener = s[pos]
            closer = "}" if opener == "{" else "]"
            node.kind = "h" if opener == "{" else "v"
            pos += 1  # consume opener
            while True:
                node.children.append(parse_node())
                assert s[pos] in ",}]", f"unexpected {s[pos]!r} at {pos}"
                if s[pos] == ",":
                    pos += 1
                    continue
                # closer
                assert s[pos] == closer
                pos += 1
                break
        else:
            # leaf: ',paneid'
            assert s[pos] == ","; pos += 1
            node.pane = num()
        return node

    root = parse_node()
    assert pos == len(s), f"trailing input at {pos}: {s[pos:]!r}"
    return root


def contains(node, pane):
    if node.kind == "leaf":
        return node.pane == pane
    return any(contains(c, pane) for c in node.children)


def child_at_top(node, at_top):
    """Which children sit at the window's top border. With pane-border-status top,
    a leaf at the window top spends its first row on the border-status line, so it
    needs layout height 2 for 1 content row; interior leaves get their border in
    the shared inter-pane separator and need only height 1. The top edge
    propagates to ALL children of a horizontal split (they share the parent's top),
    but only to the FIRST child of a vertical split (lower children sit below a
    sibling). Width is never reduced by a border, so at_top affects height only."""
    horizontal = node.kind == "h"
    return [at_top if horizontal else (at_top and i == 0)
            for i in range(len(node.children))]


def min_extent(node, at_top):
    """Smallest (w, h) this subtree can occupy without any pane dropping below
    1 *content* cell. A vertical split of k panes needs at least k rows + (k-1)
    borders; a horizontal split likewise in width. Border-aware: a leaf at the
    window's top edge (at_top) needs layout height 2 for 1 content row."""
    if node.kind == "leaf":
        return (1, 2 if at_top else 1)
    cats = child_at_top(node, at_top)
    child_mins = [min_extent(c, cats[i]) for i, c in enumerate(node.children)]
    borders = len(node.children) - 1
    ws = [m[0] for m in child_mins]
    hs = [m[1] for m in child_mins]
    if node.kind == "h":   # children side by side: widths add, heights max
        return (sum(ws) + borders, max(hs))
    return (max(ws), sum(hs) + borders)  # vertical: heights add, widths max


def assign_sizes(node, w, h, active, at_top):
    """Top-down: set w/h so the active pane's subtree dominates while every
    non-active sibling shrinks to its *structural minimum* in the split
    dimension (not 1 — a sibling that is itself a same-orientation split can't
    fit in 1 cell; forcing it produces 0-size panes that crash tmux). The
    active-path child claims whatever space the minimised siblings leave.

    Safe because we re-layout at the window's own size: the active-path child
    always ends up >= its original size (siblings only shrink), so it never
    underflows its own minimum, and the cross dimension is inherited from an
    ancestor that was already >= the subtree's minimum.

    at_top threads the window-top-border flag down so a slivered top leaf gets
    layout height 2 (1 content row) instead of 1 (0 content rows -> ┬ glitch)."""
    node.w, node.h = w, h
    if node.kind == "leaf":
        return
    n = len(node.children)
    borders = n - 1
    horizontal = node.kind == "h"
    span = w if horizontal else h                 # split-dimension extent
    cross = h if horizontal else w                # shared cross dimension
    cats = child_at_top(node, at_top)
    # each child's minimum in the split dimension (border-aware)
    mins = [min_extent(c, cats[i])[0 if horizontal else 1]
            for i, c in enumerate(node.children)]

    if contains(node, active):
        p = next(i for i, c in enumerate(node.children) if contains(c, active))
        sizes = list(mins)
        sizes[p] = span - borders - (sum(mins) - mins[p])  # active claims the rest
    else:
        # non-active subtree: hand each child its minimum, give the slack to the
        # first child so the totals still add up exactly.
        sizes = list(mins)
        sizes[0] += span - borders - sum(mins)

    for i, (c, sz) in enumerate(zip(node.children, sizes)):
        if horizontal:
            assign_sizes(c, sz, cross, active, cats[i])
        else:
            assign_sizes(c, cross, sz, active, cats[i])


def even_split(avail, mins):
    """Divide `avail` cells among len(mins) children as evenly as possible,
    giving any child whose equal share would fall below its structural minimum
    exactly its minimum and re-evening the rest. Returns sizes summing to avail.
    Most groups have mins below the equal share, so this is just an even split;
    the clamp only matters for a child that is itself a deep same-orientation
    nest (its min exceeds an equal slice)."""
    n = len(mins)
    sizes = [None] * n
    pending = list(range(n))
    space = avail
    while pending:
        base, rem = divmod(space, len(pending))
        # children whose even share is below their minimum get pinned to it
        pinned = [i for j, i in enumerate(pending)
                  if mins[i] > base + (1 if j < rem else 0)]
        if not pinned:
            for j, i in enumerate(pending):
                sizes[i] = base + (1 if j < rem else 0)
            break
        for i in pinned:
            sizes[i] = mins[i]
            space -= mins[i]
        pending = [i for i in pending if i not in pinned]
    return sizes


def even_sizes(node, w, h, at_top):
    """Top-down: split every container's space evenly among its children at
    every nesting level, preserving the tree structure. Used to un-zoom: tmux's
    `select-layout -E` only evens a pane's immediate group, so a nested layout's
    root/ancestor groups never get balanced; this reaches every level. Border-
    aware via at_top so an even split never floors a top leaf at 0 content rows."""
    node.w, node.h = w, h
    if node.kind == "leaf":
        return
    borders = len(node.children) - 1
    horizontal = node.kind == "h"
    span = w if horizontal else h
    cross = h if horizontal else w
    cats = child_at_top(node, at_top)
    mins = [min_extent(c, cats[i])[0 if horizontal else 1]
            for i, c in enumerate(node.children)]
    sizes = even_split(span - borders, mins)
    for i, (c, sz) in enumerate(zip(node.children, sizes)):
        if horizontal:
            even_sizes(c, sz, cross, cats[i])
        else:
            even_sizes(c, cross, sz, cats[i])


def assign_offsets(node, x, y):
    node.x, node.y = x, y
    if node.kind == "leaf":
        return
    horizontal = node.kind == "h"
    cx, cy = x, y
    for c in node.children:
        assign_offsets(c, cx, cy)
        if horizontal:
            cx += c.w + 1   # +1 border between children
        else:
            cy += c.h + 1


def emit(node):
    head = f"{node.w}x{node.h},{node.x},{node.y}"
    if node.kind == "leaf":
        return f"{head},{node.pane}"
    inner = ",".join(emit(c) for c in node.children)
    if node.kind == "h":
        return f"{head}{{{inner}}}"
    return f"{head}[{inner}]"


def validate(node):
    """Raise if the tree is geometrically inconsistent — every pane >= 1 cell,
    children exactly tile their parent (sizes + borders == parent span, cross
    dimension equal). A checksum-valid but geometry-invalid string can crash
    the tmux server, so we refuse to emit one.

    Two distinct guards: the tiling checks below are wedge-safety (a mis-tiled
    string crashes the server); the per-leaf content check is glitch-safety (a
    0-content top pane is geometrically valid but paints the ┬ artifact). The
    content check derives at_top from the *actual* assigned offset (node.y == 0),
    making it an independent cross-check on the at_top threading in assign_sizes/
    even_sizes — if those ever disagree with reality, this raises offline rather
    than emitting a glitch live."""
    if node.w < 1 or node.h < 1:
        raise ValueError(f"sub-unit pane {node.w}x{node.h}")
    if node.kind == "leaf":
        content_h = node.h - (1 if node.y == 0 else 0)  # top border eats a row
        if content_h < 1 or node.w < 1:
            raise ValueError(
                f"pane {node.pane} content {node.w}x{content_h} < 1 cell (y={node.y})")
        return
    n = len(node.children)
    borders = n - 1
    horizontal = node.kind == "h"
    span = node.w if horizontal else node.h
    cross = node.h if horizontal else node.w
    got = sum((c.w if horizontal else c.h) for c in node.children) + borders
    if got != span:
        raise ValueError(f"{node.kind} span {got} != {span}")
    for c in node.children:
        if (c.h if horizontal else c.w) != cross:
            raise ValueError(f"{node.kind} cross mismatch {c.w}x{c.h} != {cross}")
        validate(c)


def checksum(body):
    csum = 0
    for ch in body:
        csum = (csum >> 1) + ((csum & 1) << 15)
        csum = (csum + ord(ch)) & 0xFFFF
    return f"{csum:04x}"


def relayout(layout, active):
    """active is a pane number to zoom, or None to evenly split every group."""
    csum_hex, body = layout.split(",", 1)
    root = parse(body)
    at_top = root.y == 0   # window root sits at the top border; threads downward
    if active is None:
        even_sizes(root, root.w, root.h, at_top)
    else:
        assign_sizes(root, root.w, root.h, active, at_top)
    assign_offsets(root, root.x, root.y)
    validate(root)
    new_body = emit(root)
    return f"{checksum(new_body)},{new_body}"


if __name__ == "__main__":
    layout = sys.argv[1]
    arg = sys.argv[2]
    active = None if arg == "even" else int(arg.lstrip("%"))
    print(relayout(layout, active))
