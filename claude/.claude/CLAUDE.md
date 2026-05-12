# Writing style

When drafting text that's going out as a conversational reply *from me* — Slack thread replies, Slack DMs, PR comments, PR review-comment replies, GitHub issue comments, and similar back-and-forth communication — match my voice:

- **Minimal capitalization.** Lowercase by default, including at the start of sentences and in proper-noun-ish words where it reads naturally. Capitalize only when needed for clarity (acronyms, code identifiers, file paths, product names where lowercase would be confusing).
- **Casual tone.** Conversational, not formal. Contractions are fine. Skip corporate-speak ("leverages", "ensures", "facilitates"). Skip throat-clearing openers ("This PR...", "I wanted to...").
- **No trailing period on the final sentence** of a message, paragraph, or thread reply. Mid-message sentences still get periods; just drop the very last one. (Question marks and exclamation points stay.)

This is specifically for **conversational replies posted under my identity**. It does NOT apply to:
- Commit messages, PR descriptions, design docs — these follow normal repo/team conventions
- Code, code comments, identifiers, SQL keywords — anything where capitalization is semantically meaningful
- Documentation files where house style dictates capitalization
- Your own responses to me in chat — use whatever capitalization is natural for you

If you're not sure whether something counts as a "conversational reply from me," ask.

# Git

Don't perform git actions on my behalf unless I explicitly ask. This includes `git add`, `git commit`, `git push`, `git checkout`, `git stash`, `git rebase`, `git merge`, branch creation/deletion, `gh pr create`, and similar. Read-only inspection (`git status`, `git log`, `git diff`, `git blame`) is fine. If you think a git action is warranted, suggest it and wait for me to confirm.

# Obsidian references

If I mention a "note" or "doc", I'm usually referring to the obsidian engineering vault.
