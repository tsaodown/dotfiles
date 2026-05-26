function login-python -d "Refresh CodeArtifact auth token for pip and poetry"
    set -l ca_host datavant-283241578630.d.codeartifact.us-east-1.amazonaws.com
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)
    set -l did_something 0

    # Walk up from $PWD to the git root looking for the given filename.
    function __login_python_find_up --no-scope-shadowing
        set -l filename $argv[1]
        set -l dir $PWD
        while true
            if test -f "$dir/$filename"
                echo "$dir/$filename"
                return 0
            end
            if test "$dir" = "$git_root" -o "$dir" = /
                return 1
            end
            set dir (dirname $dir)
        end
    end

    # --- pip / pip.conf ---
    set -l pip_conf (__login_python_find_up pip.conf)
    if test -n "$pip_conf"; and grep -q "$ca_host" "$pip_conf"
        set -l token (AWS_PROFILE=prod aws codeartifact get-authorization-token \
            --domain datavant --domain-owner 283241578630 --region us-east-1 \
            --query authorizationToken --output text)
        if test -z "$token"
            echo "login-python: failed to retrieve CodeArtifact token" >&2
            return 1
        end
        set -l index_url "https://aws:$token@$ca_host/pypi/eng/simple/"
        PIP_CONFIG_FILE="$pip_conf" pip config set global.index-url "$index_url"
        if test $status -eq 0
            echo "login-python: refreshed token in $pip_conf"
            set did_something 1
        end
    else
        AWS_PROFILE=prod aws codeartifact login --tool pip \
            --repository eng --domain datavant --domain-owner 283241578630 --region us-east-1
        and set did_something 1
    end

    # --- poetry ---
    set -l pyproject (__login_python_find_up pyproject.toml)
    if test -n "$pyproject"; and grep -q "$ca_host" "$pyproject"
        set -l token (AWS_PROFILE=prod aws codeartifact get-authorization-token \
            --domain datavant --domain-owner 283241578630 --region us-east-1 \
            --query authorizationToken --output text)
        if test -z "$token"
            echo "login-python: failed to retrieve CodeArtifact token" >&2
            return 1
        end
        set -l sources (python3 -c "
import tomllib
with open('$pyproject', 'rb') as f:
    data = tomllib.load(f)
for src in data.get('tool', {}).get('poetry', {}).get('source', []):
    if '$ca_host' in src.get('url', ''):
        print(src['name'])
" 2>/dev/null)
        for src in $sources
            PYTHON_KEYRING_BACKEND=keyring.backends.fail.Keyring poetry config http-basic.$src aws "$token"
            and echo "login-python: refreshed poetry credentials for source '$src'"
            and set did_something 1
        end
    end

    functions --erase __login_python_find_up

    if test $did_something -eq 0
        echo "login-python: no CodeArtifact config found in tree; refreshed global pip config only"
    end
end
