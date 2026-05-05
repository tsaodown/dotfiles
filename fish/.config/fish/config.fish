if status is-interactive
    # Commands to run in interactive sessions can go here

    zoxide init --cmd cd fish | source
    pyenv init - fish | source

    if not set -q TMUX
        exec tmux new-session -A -s main
    end

    if functions -q nvm_auto_use
        nvm_auto_use
    end

    fish_add_path $HOME/bin
    fish_add_path $HOME/.local/bin

    set -gx JAVA_HOME (/usr/libexec/java_home -v 21)
    fish_add_path --prepend $JAVA_HOME/bin
end


# per-machine overrides
if test -f ~/.config/fish/config.local.fish
    source ~/.config/fish/config.local.fish
end
