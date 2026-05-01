function zls
    set -l alias_dir ~/.zoxide-aliases

    if test -d $alias_dir
        echo "📌 Zoxide aliases:"
        ls -l $alias_dir
    else
        echo "No aliases have been created yet."
    end
end
