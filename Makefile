DOTFILES           := $(shell pwd)
TARGET             := $(HOME)
STOW               := stow --target=$(TARGET) --dir=$(DOTFILES)
OS                 := $(shell uname -s)

FOLDED             := zsh fish tmux kitty
UNFOLDED           := vscode claude

USER_BIN           := $(HOME)/.local/bin

# git-stack lives as a submodule at ./git-stack (canonical), but during the
# transition we also fall back to the legacy ./bin/git-stack source file so
# bin-link keeps working before the submodule is initialized.
GIT_STACK_SRC := $(shell \
  if [ -e $(DOTFILES)/git-stack/bin/git-stack ]; then \
    echo $(DOTFILES)/git-stack/bin/git-stack; \
  elif [ -e $(DOTFILES)/bin/git-stack ]; then \
    echo $(DOTFILES)/bin/git-stack; \
  fi)

PLIST_LABEL        := com.tsaodown.dotfiles-watcher
PLIST_TMPL         := $(DOTFILES)/launchd/$(PLIST_LABEL).plist.tmpl
PLIST_OUT          := $(HOME)/Library/LaunchAgents/$(PLIST_LABEL).plist

SERVICE_TMPL       := $(DOTFILES)/systemd/dotfiles-watcher.service.tmpl
SERVICE_OUT        := $(HOME)/.config/systemd/user/dotfiles-watcher.service

WATCHER_DIR        := $(shell $(DOTFILES)/bin/dotfiles-watcher-paths state-dir)
LOG_FILE           := $(shell $(DOTFILES)/bin/dotfiles-watcher-paths log)
HALT_FILE          := $(WATCHER_DIR)/halt
HELD_GITLINK_FILE  := $(WATCHER_DIR)/held-gitlinks

DEBOUNCE_SECS      ?= 180
PULL_INTERVAL_SECS ?= 21600
JOBS               ?= 4
# set SUBMODULE_TESTS=0 to skip the git-stack submodule's own tests (it has its own CI)
SUBMODULE_TESTS    ?= 1

# Set the tmux pane title for the current target. No-op outside tmux.
# Use as the first recipe line: $(call tmux_title,my title)
tmux_title = @[ -n "$$TMUX" ] && printf '\033]2;$(1)\007' || true

.PHONY: install stow unstow restow check check-stow help test \
        bin-link bin-unlink submodules seed-universal patch-tide-prompt \
        watcher-install watcher-uninstall watcher-start watcher-stop \
        watcher-status watcher-logs watcher-resume watcher-pause watcher-sync \
        watcher-pull

help:
	@echo "make install            interactive bootstrap (deps + stow + watcher)"
	@echo "make stow               just symlink packages"
	@echo "make unstow             remove all symlinks"
	@echo "make restow             clean stale links and re-link"
	@echo "make check              dry-run; show what would change"
	@echo "make submodules         initialize/update git submodules (e.g. git-stack)"
	@echo "make seed-universal     refresh fish/.config/fish/seed-universal.fish from this machine's tide config (dry run; pass APPLY=1 to write)"
	@echo "make patch-tide-prompt  re-apply the local tide prompt patch (run after a manual 'fisher update'; idempotent)"
	@echo "make bin-link           symlink user-facing bin tools into ~/.local/bin"
	@echo "make bin-unlink         remove the symlinks created by bin-link"
	@echo "make watcher-install    install daemon (DEBOUNCE_SECS=$(DEBOUNCE_SECS) PULL_INTERVAL_SECS=$(PULL_INTERVAL_SECS))"
	@echo "make watcher-uninstall  remove daemon"
	@echo "make watcher-{start,stop,status,logs}"
	@echo "make watcher-pause      stop auto-sync (creates halt sentinel)"
	@echo "make watcher-resume     resolve conflict + resume auto-sync"
	@echo "make watcher-sync       force an immediate sync now (works while paused; signals the daemon)"
	@echo "make watcher-pull       force an immediate ff-pull (bypasses daily interval)"
	@echo "make test               run bats tests under tests/"

test:
	$(call tmux_title,dotfiles tests)
	@$(DOTFILES)/bin/dotfiles-deps check test
	@rc=0; \
	 PARALLEL='--line-buffer' bats --jobs $(JOBS) tests/ || rc=1; \
	 if [ "$(SUBMODULE_TESTS)" = 1 ] && [ -e $(DOTFILES)/git-stack/Makefile ]; then \
	   echo ""; \
	   echo "--- git-stack submodule tests ---"; \
	   $(MAKE) -C $(DOTFILES)/git-stack test JOBS=$(JOBS) || rc=1; \
	 fi; \
	 exit $$rc

install:
	$(call tmux_title,dotfiles install)
	@$(DOTFILES)/bin/dotfiles-install

stow: check-stow
	$(call tmux_title,stow)
	$(STOW) $(FOLDED)
	$(STOW) --no-folding $(UNFOLDED)

unstow: check-stow
	$(call tmux_title,unstow)
	$(STOW) -D $(FOLDED)
	$(STOW) --no-folding -D $(UNFOLDED)

restow: check-stow
	$(call tmux_title,restow)
	$(STOW) -R $(FOLDED)
	$(STOW) --no-folding -R $(UNFOLDED)

check: check-stow
	$(call tmux_title,stow check)
	$(STOW) -nv $(FOLDED)
	$(STOW) --no-folding -nv $(UNFOLDED)

check-stow:
	@$(DOTFILES)/bin/dotfiles-deps check core

submodules:
	$(call tmux_title,submodules)
	@git -C $(DOTFILES) submodule update --init --recursive

seed-universal:
	$(call tmux_title,seed-universal)
	@$(DOTFILES)/bin/dotfiles-seed-universal $(if $(filter 1,$(APPLY)),--apply)

patch-tide-prompt:
	$(call tmux_title,patch-tide-prompt)
	@$(DOTFILES)/bin/dotfiles-tide-prompt-patch

bin-link:
	$(call tmux_title,bin-link)
	@mkdir -p $(USER_BIN)
	@if [ -z "$(GIT_STACK_SRC)" ]; then \
	  echo "git-stack source not found. Run 'make submodules' to init the submodule."; \
	  exit 1; \
	fi
	@ln -snf $(GIT_STACK_SRC) $(USER_BIN)/git-stack
	@echo "linked $(USER_BIN)/git-stack -> $(GIT_STACK_SRC)"

bin-unlink:
	$(call tmux_title,bin-unlink)
	@if [ -L $(USER_BIN)/git-stack ]; then \
	  case "$$(readlink $(USER_BIN)/git-stack)" in \
	    $(DOTFILES)/git-stack/bin/git-stack|$(DOTFILES)/bin/git-stack) \
	      rm $(USER_BIN)/git-stack; \
	      echo "unlinked $(USER_BIN)/git-stack" ;; \
	  esac; \
	fi

watcher-install:
	$(call tmux_title,watcher install)
	@$(DOTFILES)/bin/dotfiles-deps check watcher
ifeq ($(OS),Darwin)
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
	@chmod +x $(DOTFILES)/bin/dotfiles-watcher
	@mkdir -p $(HOME)/.config/systemd/user $(HOME)/.local/share/dotfiles/watcher
	@sed -e 's|__DOTFILES__|$(DOTFILES)|g' \
	     -e 's|__HOME__|$(HOME)|g' \
	     -e 's|__DEBOUNCE__|$(DEBOUNCE_SECS)|g' \
	     -e 's|__PULL_INTERVAL__|$(PULL_INTERVAL_SECS)|g' \
	     $(SERVICE_TMPL) > $(SERVICE_OUT)
	@systemctl --user daemon-reload
	@systemctl --user enable --now dotfiles-watcher
endif
	@echo "watcher installed (debounce=$(DEBOUNCE_SECS)s, scheduled-pull-slot=$(PULL_INTERVAL_SECS)s)"

watcher-uninstall:
	$(call tmux_title,watcher uninstall)
ifeq ($(OS),Darwin)
	@launchctl bootout gui/$(shell id -u) $(PLIST_OUT) 2>/dev/null || true
	@rm -f $(PLIST_OUT)
else
	@systemctl --user disable --now dotfiles-watcher 2>/dev/null || true
	@rm -f $(SERVICE_OUT)
	@systemctl --user daemon-reload
endif
	@echo "watcher uninstalled"

watcher-start:
	$(call tmux_title,watcher start)
ifeq ($(OS),Darwin)
	@if launchctl print gui/$(shell id -u)/$(PLIST_LABEL) >/dev/null 2>&1; then \
	  launchctl kickstart -k gui/$(shell id -u)/$(PLIST_LABEL); \
	else \
	  launchctl bootstrap gui/$(shell id -u) $(PLIST_OUT); \
	fi
else
	@systemctl --user start dotfiles-watcher
endif

watcher-stop:
	$(call tmux_title,watcher stop)
ifeq ($(OS),Darwin)
	@launchctl bootout gui/$(shell id -u) $(PLIST_OUT) 2>/dev/null || true
else
	@systemctl --user stop dotfiles-watcher
endif

watcher-status:
	$(call tmux_title,watcher status)
ifeq ($(OS),Darwin)
	@launchctl print gui/$(shell id -u)/$(PLIST_LABEL) 2>/dev/null | head -20 || echo "not loaded"
else
	@systemctl --user status dotfiles-watcher 2>/dev/null | head -20 || echo "not loaded"
endif
	@test -f "$(HALT_FILE)" && echo "STATE: HALTED — see $(HALT_FILE)" || echo "STATE: active"
	@test -f "$(HELD_GITLINK_FILE)" && \
	  awk -F'\t' '{printf "HOLDING: %s gitlink — %s not on its remote (push it to unblock)\n", $$1, substr($$2,1,7)}' \
	    "$(HELD_GITLINK_FILE)" || true

watcher-logs:
	$(call tmux_title,watcher logs)
	@$(DOTFILES)/bin/dotfiles-watcher-logs

watcher-pause:
	$(call tmux_title,watcher pause)
	@mkdir -p "$(WATCHER_DIR)"
	@echo "manual pause" > "$(HALT_FILE)"
	@echo "watcher paused"

watcher-resume:
	$(call tmux_title,watcher resume)
	@rm -f "$(HALT_FILE)" "$(WATCHER_DIR)/consecutive-resyncs"
	@echo "watcher resumed"

watcher-sync:
	$(call tmux_title,watcher sync)
ifeq ($(OS),Darwin)
	@pid=$$(launchctl print gui/$$(id -u)/$(PLIST_LABEL) 2>/dev/null | awk '/ pid = /{print $$3; exit}'); \
	[ -z "$$pid" ] && pid=$$(pgrep -f 'bin/dotfiles-watcher$$' | head -1); \
	if [ -z "$$pid" ]; then echo "watcher not running — start it with 'make watcher-start'"; exit 1; fi; \
	kill -USR2 "$$pid" && echo "sync requested — committing now (see 'make watcher-logs')"
else
	@pid=$$(systemctl --user show -p MainPID --value dotfiles-watcher 2>/dev/null); \
	{ [ "$$pid" = "0" ] || [ -z "$$pid" ]; } && pid=$$(pgrep -f 'bin/dotfiles-watcher$$' | head -1); \
	if [ -z "$$pid" ]; then echo "watcher not running — start it with 'make watcher-start'"; exit 1; fi; \
	kill -USR2 "$$pid" && echo "sync requested — committing now (see 'make watcher-logs')"
endif

watcher-pull:
	$(call tmux_title,watcher pull)
	@mkdir -p "$(WATCHER_DIR)"
	@echo 0 > "$(WATCHER_DIR)/last-pull"
	@echo "pull triggered — will ff-pull within 30s"
