DOTFILES           := $(shell pwd)
TARGET             := $(HOME)
STOW               := stow --target=$(TARGET) --dir=$(DOTFILES)

FOLDED             := zsh fish tmux kitty
UNFOLDED           := cursor vscode claude

PLIST_LABEL        := com.tsaodown.dotfiles-watcher
PLIST_TMPL         := $(DOTFILES)/launchd/$(PLIST_LABEL).plist.tmpl
PLIST_OUT          := $(HOME)/Library/LaunchAgents/$(PLIST_LABEL).plist
HALT_FILE          := $(HOME)/Library/Application Support/dotfiles-watcher/halt
DEBOUNCE_SECS      ?= 180
PULL_INTERVAL_SECS ?= 86400

.PHONY: install stow unstow restow check check-stow help \
        watcher-install watcher-uninstall watcher-start watcher-stop \
        watcher-status watcher-logs watcher-resume watcher-pause

help:
	@echo "make install            interactive bootstrap (deps + stow + watcher)"
	@echo "make stow               just symlink packages"
	@echo "make unstow             remove all symlinks"
	@echo "make restow             clean stale links and re-link"
	@echo "make check              dry-run; show what would change"
	@echo "make watcher-install    install launchd agent (DEBOUNCE_SECS=$(DEBOUNCE_SECS) PULL_INTERVAL_SECS=$(PULL_INTERVAL_SECS))"
	@echo "make watcher-uninstall  remove launchd agent"
	@echo "make watcher-{start,stop,status,logs}"
	@echo "make watcher-pause      stop auto-sync (creates halt sentinel)"
	@echo "make watcher-resume     resolve conflict + resume auto-sync"

install:
	@$(DOTFILES)/bin/dotfiles-install

stow: check-stow
	$(STOW) $(FOLDED)
	$(STOW) --no-folding $(UNFOLDED)

unstow: check-stow
	$(STOW) -D $(FOLDED)
	$(STOW) --no-folding -D $(UNFOLDED)

restow: check-stow
	$(STOW) -R $(FOLDED)
	$(STOW) --no-folding -R $(UNFOLDED)

check: check-stow
	$(STOW) -nv $(FOLDED)
	$(STOW) --no-folding -nv $(UNFOLDED)

check-stow:
	@command -v stow >/dev/null 2>&1 || { echo "stow not found. brew install stow"; exit 1; }

watcher-install:
	@command -v fswatch >/dev/null 2>&1 || { echo "fswatch not found. brew install fswatch"; exit 1; }
	@chmod +x $(DOTFILES)/bin/dotfiles-watcher
	@mkdir -p $(HOME)/Library/LaunchAgents $(HOME)/Library/Logs
	@sed -e 's|__DOTFILES__|$(DOTFILES)|g' \
	     -e 's|__HOME__|$(HOME)|g' \
	     -e 's|__DEBOUNCE__|$(DEBOUNCE_SECS)|g' \
	     -e 's|__PULL_INTERVAL__|$(PULL_INTERVAL_SECS)|g' \
	     $(PLIST_TMPL) > $(PLIST_OUT)
	@launchctl bootout gui/$(shell id -u) $(PLIST_OUT) 2>/dev/null || true
	@launchctl bootstrap gui/$(shell id -u) $(PLIST_OUT)
	@echo "watcher installed (debounce=$(DEBOUNCE_SECS)s, daily-pull=$(PULL_INTERVAL_SECS)s)"

watcher-uninstall:
	@launchctl bootout gui/$(shell id -u) $(PLIST_OUT) 2>/dev/null || true
	@rm -f $(PLIST_OUT)
	@echo "watcher uninstalled"

watcher-start:
	@launchctl kickstart -k gui/$(shell id -u)/$(PLIST_LABEL)

watcher-stop:
	@launchctl bootout gui/$(shell id -u) $(PLIST_OUT) 2>/dev/null || true

watcher-status:
	@launchctl print gui/$(shell id -u)/$(PLIST_LABEL) 2>/dev/null | head -20 || echo "not loaded"
	@test -f "$(HALT_FILE)" && echo "STATE: HALTED — see $(HALT_FILE)" || echo "STATE: active"

watcher-logs:
	@tail -F $(HOME)/Library/Logs/dotfiles-watcher.log

watcher-pause:
	@mkdir -p "$(dir $(HALT_FILE))"
	@echo "manual pause" > "$(HALT_FILE)"
	@echo "watcher paused"

watcher-resume:
	@rm -f "$(HALT_FILE)"
	@echo "watcher resumed"
