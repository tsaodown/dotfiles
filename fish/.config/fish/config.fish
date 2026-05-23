if status is-interactive
    # Commands to run in interactive sessions can go here

    zoxide init --cmd cd fish | source
    pyenv init - fish | source

    if not set -q TMUX
        # Start tmux detached first so the config sources and continuum's
        # auto-restore can populate sessions before we attach. Attaching with
        # `new-session -A -s main` directly races the bg restore and ends up
        # with a fresh empty `main` instead of the restored one.
        if not tmux ls >/dev/null 2>&1
            tmux new-session -d -s __init >/dev/null
            # Heal a dangling resurrect `last` symlink: a save-script race can
            # leave it pointing at a deleted file, in which case continuum's
            # auto-restore silently does nothing.
            set -l has_save 0
            for d in $HOME/.local/share/tmux/resurrect $HOME/.tmux/resurrect
                set -l last $d/last
                if test -L $last; and not test -e $last
                    set -l newest (find $d -maxdepth 1 -name 'tmux_resurrect_*.txt' 2>/dev/null | sort | tail -n 1)
                    if test -n "$newest"
                        ln -sf (basename $newest) $last
                    end
                end
                if test -L $last; and test -e $last
                    set has_save 1
                end
            end
            if test $has_save -eq 1
                for i in (seq 1 25)
                    if tmux has-session -t main 2>/dev/null
                        break
                    end
                    sleep 0.2
                end
            end
            tmux kill-session -t __init 2>/dev/null
        end
        if tmux has-session -t main 2>/dev/null
            exec tmux attach -t main
        else
            exec tmux new-session -s main
        end
    end

    if functions -q nvm_auto_use
        nvm_auto_use
    end

    set -gx LESS -R -Q

    fish_add_path $HOME/bin
    fish_add_path $HOME/.local/bin

    if test (uname -s) = Darwin
        if command -q /usr/libexec/java_home
            set -gx JAVA_HOME (/usr/libexec/java_home -v 21 2>/dev/null)
            if test -n "$JAVA_HOME"
                fish_add_path --prepend $JAVA_HOME/bin
            end
        end
    else if test -n "$JAVA_HOME"
        fish_add_path --prepend $JAVA_HOME/bin
    end
end


# per-machine overrides
if test -f ~/.config/fish/config.local.fish
    source ~/.config/fish/config.local.fish
end
