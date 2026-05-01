function zalias
    if test (count $argv) -ne 2
        echo "Usage: zalias <alias-name> <target-directory>"
        return 1
    end

    set -l name $argv[1]
    set -l target (realpath $argv[2])
    set -l alias_dir ~/.zoxide-aliases
    set -l alias_path $alias_dir/$name

    if not test -d $target
        echo "❌ Error: '$target' is not a valid directory"
        return 1
    end

    # Create alias directory if it doesn't exist
    if not test -d $alias_dir
        mkdir -p $alias_dir
    end

    # Create or update the symlink
    ln -sf $target $alias_path
    zoxide add $alias_path
    echo "✅ Alias '$name' → $target created and added to zoxide"
end
