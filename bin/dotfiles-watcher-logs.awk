# Colorize dotfiles-watcher log lines. Run by dotfiles-watcher-logs as the
# tail -F filter; also run directly by tests/dotfiles-watcher-logs.bats.
#
# New lines carry an explicit "[level]" tag (see log_format in
# dotfiles-watcher-lib) and are colored by a lookup on that tag — no prose
# matching. Lines written before the tag existed (and the long tail of
# historical log content) fall back to keying on the message text. The fallback
# only ever sees untagged lines, so it doesn't recouple coloring to the wording
# of newly-emitted messages.
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
    } else if (body ~ /HALT:|ERROR|fetch failed|push failed|rebase conflict|rolling sync|unmerged/) {
      c = RED;
    } else if (body ~ /skipped|skipping|still dirty|another instance/) {
      # Yellow before green so "ff-pull skipped (... unpushed ...)" cannot fall
      # through to the green "pushed" rule via the "unpushed" substring.
      c = YEL;
    } else if (body ~ /committed:|pushed|working tree clean|advanced HEAD/) {
      c = GRN;
    } else if (body ~ /change detected|debounce window|sync started|drain complete|watcher started|woke from sleep|restarting to pick up|no changes to pull/) {
      c = CYN;
    } else if (body ~ /watcher stopping/) {
      c = MAG;
    } else if (body ~ /time to sync:/) {
      c = GRY;
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
