# ~/.config/fish/functions/nvm_auto_use.fish

function nvm_auto_use --on-variable PWD
    # List of directory roots to scope activation (customize as needed)
    set -l allowed_root ~/code

    # Check if current directory is within any of the allowed roots
    for root in $allowed_root
        if string match -q "$root*" $PWD
            set -l search_dir $PWD

            # Walk up the directory tree to find the nearest .nvmrc
            while test "$search_dir" != "/"
                if test -f "$search_dir/.nvmrc"
                    set -l node_version (string trim (cat "$search_dir/.nvmrc"))

                    # Install if not already available
                    nvm list $node_version >/dev/null 2>&1
                    set -l exists $status
                    if test $exists -ne 0
                        echo "Needs Node $node_version. Installing now..."
                        nvm install $node_version >/dev/null 2>&1
                    end

                    # Use the version
                    set -l current_node_version (nvm current | string match -r --groups-only '^v(\d+)' | string replace -r '^v' '')
                    if test $current_node_version != $node_version
                        nvm use $node_version >/dev/null 2>&1
                    end

                    return
                end

                set search_dir (dirname $search_dir)
            end

            # No .nvmrc found — fallback to latest installed version
	    nvm list latest >/dev/null 2>&1
	    set -l exists $status
	    if test $exists -ne 0
		echo "Installing latest node version..."
		nvm install latest >/dev/null 2>&1
	    end

	    nvm use latest >/dev/null 2>&1

            return  # Don't search again if not in allowed scope
        end
    end
end
