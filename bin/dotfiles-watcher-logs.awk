# Colorize dotfiles-watcher log lines. Run by dotfiles-watcher-logs as the
# tail -F filter; also run directly by tests/dotfiles-watcher-logs.bats.
#
# Lines carry an explicit "[level]" tag (see log_format in dotfiles-watcher-lib)
# and are colored by a lookup on that tag — no grep-matching the message prose.
# Timestamped lines without a tag (pre-tag history, or lines from an old watcher
# process that hasn't restarted onto tagged output yet) are dimmed, not colored.
BEGIN {
  DIM = "\033[2m"; RST = "\033[0m";
  RED = "\033[31m"; GRN = "\033[32m"; YEL = "\033[33m";
  CYN = "\033[36m"; MAG = "\033[35m"; GRY = "\033[90m";
  color["error"]    = RED;
  color["warn"]     = YEL;
  color["ok"]       = GRN;
  color["info"]     = CYN;
  color["trace"]    = GRY;
  color["stopping"] = MAG;
}
{
  if (match($0, /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} /)) {
    ts = substr($0, 1, 19);
    body = substr($0, 20);   # leading space + "[level] message" (or legacy prose)
    c = "";
    if (match(body, /^ \[(error|warn|ok|info|trace|stopping)\] /)) {
      lvl = body; sub(/^ \[/, "", lvl); sub(/\].*/, "", lvl);
      c = color[lvl];
    }
    if (c == "") {
      printf "%s%s%s%s\n", DIM, ts, RST, body;
    } else {
      printf "%s%s%s%s%s%s\n", DIM, ts, RST, c, body, RST;
    }
  } else {
    # Lines without our timestamp prefix (e.g. raw git stderr appended via
    # `>>"$LOG" 2>&1`) — dim them so structured lines stand out.
    printf "%s%s%s\n", DIM, $0, RST;
  }
  fflush();
}
