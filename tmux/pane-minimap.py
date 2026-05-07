#!/usr/bin/env python3
"""One-row minimap of the current tmux window's pane layout.

Output is intended for tmux status-right via `#(...)`.

Layout grammar (from tmux's window_layout format variable):
  layout   := <checksum> "," node
  node     := dims ("," <pane_id_int> | "{" children "}" | "[" children "]")
  dims     := <int> "x" <int> "," <int> "," <int>
  children := node ("," node)+

`{}` panes are arranged left-to-right (we render them joined by │).
`[]` panes are arranged top-to-bottom (we render them joined by ─).
Nested splits get parenthesized so the structure stays unambiguous.

The integer at each leaf is tmux's global `pane_id` (the number after
`%`), not the per-window `pane_index`. We map it to `pane_index` via
`list-panes` so what the user sees in the bar matches the indices they
use to navigate.

The active pane is wrapped in #[reverse]…#[noreverse] — tmux interprets
these style escapes inside #() output when assembling the status line.
"""
import re
import subprocess
import sys


_DIMS = re.compile(r"\d+x\d+,\d+,\d+")
_CKSUM = re.compile(r"^[0-9a-f]+,")


def fetch():
    """Return (layout_str, id_to_index, active_index).

    id_to_index maps the integer pane_id (as it appears in the layout
    string) to the display-friendly pane_index.
    active_index is the pane_index of the currently active pane.
    """
    layout = subprocess.check_output(
        ["tmux", "display-message", "-p", "#{window_layout}"],
        text=True,
    ).rstrip("\n")
    panes = subprocess.check_output(
        ["tmux", "list-panes", "-F", "#{pane_id}\t#{pane_index}\t#{pane_active}"],
        text=True,
    ).strip().splitlines()
    id_to_index = {}
    active_index = None
    for line in panes:
        pid, idx, act = line.split("\t")
        pid_int = int(pid.lstrip("%"))
        idx_int = int(idx)
        id_to_index[pid_int] = idx_int
        if act == "1":
            active_index = idx_int
    return layout, id_to_index, active_index


def parse(s):
    s = _CKSUM.sub("", s, count=1)
    node, _ = _parse_node(s, 0)
    return node


def _parse_node(s, i):
    m = _DIMS.match(s, i)
    if not m:
        raise ValueError(f"bad layout near {s[i:i+30]!r}")
    i = m.end()
    if i >= len(s):
        return ("leaf", None), i
    c = s[i]
    if c == ",":
        i += 1
        j = i
        while j < len(s) and s[j].isdigit():
            j += 1
        return ("leaf", int(s[i:j])), j
    if c in "{[":
        close = "}" if c == "{" else "]"
        kind = "h" if c == "{" else "v"
        i += 1
        kids = []
        while True:
            kid, i = _parse_node(s, i)
            kids.append(kid)
            if i < len(s) and s[i] == ",":
                i += 1
                continue
            break
        if i >= len(s) or s[i] != close:
            raise ValueError(f"unclosed {c} near {s[i:i+30]!r}")
        return (kind, kids), i + 1
    return ("leaf", None), i


def render(node, id_to_index, active_index, top=True):
    kind, payload = node
    if kind == "leaf":
        idx = id_to_index.get(payload, payload)
        s = str(idx)
        return f"#[reverse]{s}#[noreverse]" if idx == active_index else s
    sep = "│" if kind == "h" else "─"
    inner = sep.join(
        render(c, id_to_index, active_index, top=False) for c in payload
    )
    return inner if top else f"({inner})"


def main():
    try:
        layout, id_to_index, active_index = fetch()
    except subprocess.CalledProcessError:
        return
    if not layout:
        return
    try:
        tree = parse(layout)
    except ValueError:
        return
    sys.stdout.write(f"[{render(tree, id_to_index, active_index)}]")


if __name__ == "__main__":
    main()
