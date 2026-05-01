function zunalias
    if test (count $argv) -ne 1
        echo "Usage: zunalias <alias-name>"
        return 1
    end

    set -l alias_path ~/.zoxide-aliases/$argv[1]

    if test -L $alias_path
        zoxide remove $alias_path
        rm $alias_path
        echo "🗑 Removed alias '$argv[1]'"
    else
        echo "❌ Alias '$argv[1]' does not exist"
        return 1
    end
end
