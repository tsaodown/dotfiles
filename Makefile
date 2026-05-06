DOTFILES           := $(shell pwd)
TARGET             := $(HOME)
STOW               := stow --target=$(TARGET) --dir=$(DOTFILES)
OS                 := $(shell uname -s)

FOLDED             := zsh fish tmux kitty
UNFOLDED           := cursor vscode claude

PLIST_LABEL        := com.tsaodown.dotfiles-watcher
PLIST_TMPL         := $(DOTFILES)/launchd/$(PLIST_LABEL).plist.tmpl
PLIST_OUT          := $(HOME)/Library/LaunchAgents/$(PLIST_LABEL).plist

SERVICE_TMPL       := $(DOTFILES)/systemd/dotfiles-watcher.service.tmpl
SERVICE_OUT        := $(HOME)/.config/systemd/user/dotfiles-watcher.service

ifeq ($(OS),Darwin)
  HALT_FILE        := $(HOME)/Library/Application Support/dotfiles-watcher/halt
  LOG_FILE         := $(HOME)/Library/Logs/dotfiles-watcher.log
else
  HALT_FILE        := $(HOME)/.local/share/dotfiles/watcher/halt
  LOG_FILE         := $(HOME)/.local/share/dotfiles/watcher.log
endif

DEBOUNCE_SECS      ?= 180
PULL_INTERVAL_SECS ?= 86400

.PHONY: install stow unstow restow check check-stow help \
        watcher-install watcher-uninstall watcher-start watcher-stop \
        watcher-status watcher-logs watcher-resume watcher-pause watcher-sync \
        wsl-autostart-install wsl-autostart-uninstall

help:
	@echo "make install            interactive bootstrap (deps + stow + watcher)"
	@echo "make stow               just symlink packages"
	@echo "make unstow             remove all symlinks"
	@echo "make restow             clean stale links and re-link"
	@echo "make check              dry-run; show what would change"
	@echo "make watcher-install    install daemon (DEBOUNCE_SECS=$(DEBOUNCE_SECS) PULL_INTERVAL_SECS=$(PULL_INTERVAL_SECS))"
	@echo "make watcher-uninstall  remove daemon"
	@echo "make watcher-{start,stop,status,logs}"
	@echo "make watcher-pause      stop auto-sync (creates halt sentinel)"
	@echo "make watcher-resume     resolve conflict + resume auto-sync"
	@echo "make watcher-sync       force an immediate sync (bypasses debounce)"
	@echo "make wsl-autostart-install    register Windows scheduled task to start WSL silently at logon (WSL only)"
	@echo "make wsl-autostart-uninstall  remove that scheduled task and the launcher VBScript"

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
	@command -v stow >/dev/null 2>&1 || { echo "stow not found. Install: $$([ "$$(uname -s)" = Darwin ] && echo 'brew install stow' || echo 'sudo apt-get install stow')"; exit 1; }

watcher-install:
ifeq ($(OS),Darwin)
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
else
	@command -v fswatch >/dev/null 2>&1 || command -v inotifywait >/dev/null 2>&1 || \
	  { echo "Neither fswatch nor inotifywait found. sudo apt-get install inotify-tools"; exit 1; }
	@chmod +x $(DOTFILES)/bin/dotfiles-watcher
	@mkdir -p $(HOME)/.config/systemd/user $(HOME)/.local/share/dotfiles/watcher
	@sed -e 's|__DOTFILES__|$(DOTFILES)|g' \
	     -e 's|__HOME__|$(HOME)|g' \
	     -e 's|__DEBOUNCE__|$(DEBOUNCE_SECS)|g' \
	     -e 's|__PULL_INTERVAL__|$(PULL_INTERVAL_SECS)|g' \
	     $(SERVICE_TMPL) > $(SERVICE_OUT)
	@systemctl --user daemon-reload
	@systemctl --user enable --now dotfiles-watcher
	@$(DOTFILES)/bin/dotfiles-wsl-autostart install
endif
	@echo "watcher installed (debounce=$(DEBOUNCE_SECS)s, daily-pull=$(PULL_INTERVAL_SECS)s)"

watcher-uninstall:
ifeq ($(OS),Darwin)
	@launchctl bootout gui/$(shell id -u) $(PLIST_OUT) 2>/dev/null || true
	@rm -f $(PLIST_OUT)
else
	@systemctl --user disable --now dotfiles-watcher 2>/dev/null || true
	@rm -f $(SERVICE_OUT)
	@systemctl --user daemon-reload
	@grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null && \
	  echo "WSL autostart task left in place; run 'make wsl-autostart-uninstall' to remove it" || true
endif
	@echo "watcher uninstalled"

watcher-start:
ifeq ($(OS),Darwin)
	@launchctl kickstart -k gui/$(shell id -u)/$(PLIST_LABEL)
else
	@systemctl --user start dotfiles-watcher
endif

watcher-stop:
ifeq ($(OS),Darwin)
	@launchctl bootout gui/$(shell id -u) $(PLIST_OUT) 2>/dev/null || true
else
	@systemctl --user stop dotfiles-watcher
endif

watcher-status:
ifeq ($(OS),Darwin)
	@launchctl print gui/$(shell id -u)/$(PLIST_LABEL) 2>/dev/null | head -20 || echo "not loaded"
else
	@systemctl --user status dotfiles-watcher 2>/dev/null | head -20 || echo "not loaded"
endif
	@test -f "$(HALT_FILE)" && echo "STATE: HALTED — see $(HALT_FILE)" || echo "STATE: active"

watcher-logs:
	@tail -F $(LOG_FILE)

watcher-pause:
	@mkdir -p "$(dir $(HALT_FILE))"
	@echo "manual pause" > "$(HALT_FILE)"
	@echo "watcher paused"

watcher-resume:
	@rm -f "$(HALT_FILE)"
	@echo "watcher resumed"

watcher-sync:
	@if [ -f "$(HALT_FILE)" ]; then \
	  echo "watcher is HALTED — run 'make watcher-resume' first (halt file: $(HALT_FILE))"; \
	  exit 1; \
	fi
	@echo $$(( $$(date +%s) - 999 )) > "$(dir $(HALT_FILE))last-change"
	@echo "sync triggered — will commit within 30s"

wsl-autostart-install:
	@$(DOTFILES)/bin/dotfiles-wsl-autostart install

wsl-autostart-uninstall:
	@$(DOTFILES)/bin/dotfiles-wsl-autostart uninstall
