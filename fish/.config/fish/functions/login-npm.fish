function login-npm -d "Refresh CodeArtifact auth token (context-aware: project or @datavant scope)"
    set -l ca_host datavant-283241578630.d.codeartifact.us-east-1.amazonaws.com
    set -l git_root (git rev-parse --show-toplevel 2>/dev/null)

    # Walk from CWD up to the git root looking for a .npmrc that routes through CodeArtifact.
    set -l npmrc_dir ""
    set -l dir (pwd)
    while true
        if test -f "$dir/.npmrc"; and grep -q "$ca_host" "$dir/.npmrc"
            set npmrc_dir $dir
            break
        end
        if test "$dir" = "/" -o \( -n "$git_root" -a "$dir" = "$git_root" \)
            break
        end
        set dir (dirname $dir)
    end

    if test -n "$npmrc_dir"
        # Found a project .npmrc — refresh the token there, leaving ~/.npmrc alone.
        set -l token (AWS_PROFILE=prod aws codeartifact get-authorization-token \
            --domain datavant --domain-owner 283241578630 --region us-east-1 \
            --query authorizationToken --output text)
        if test -z "$token"
            echo "login-npm: failed to retrieve CodeArtifact token" >&2
            return 1
        end
        pushd "$npmrc_dir" >/dev/null
        npm config set --location=project "//$ca_host/npm/npm/:_authToken" "$token"
        set -l rc $status
        popd >/dev/null
        if test $rc -eq 0
            echo "login-npm: refreshed token in $npmrc_dir/.npmrc"
        end
        return $rc
    else
        # Refresh only the @datavant-scoped registry's token in ~/.npmrc;
        # --namespace prevents `aws codeartifact login` from overwriting the default registry.
        # Run from $HOME so `npm config set` (called internally) doesn't see a workspace root.
        pushd $HOME >/dev/null
        AWS_PROFILE=prod aws codeartifact login --tool npm --namespace @datavant \
            --repository npm --domain datavant --domain-owner 283241578630 --region us-east-1
        set -l rc $status
        popd >/dev/null
        return $rc
    end
end
