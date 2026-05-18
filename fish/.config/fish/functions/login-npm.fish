function login-npm -d "Refresh CodeArtifact auth token (context-aware: project or @datavant scope)"
    set -l ca_host datavant-283241578630.d.codeartifact.us-east-1.amazonaws.com
    set -l project_root (git rev-parse --show-toplevel 2>/dev/null)

    if test -n "$project_root" -a -f "$project_root/.npmrc"; and grep -q "$ca_host" "$project_root/.npmrc"
        # Inside a repo whose .npmrc routes everything through CodeArtifact —
        # refresh the token in that project's .npmrc, leaving ~/.npmrc alone.
        set -l token (AWS_PROFILE=prod aws codeartifact get-authorization-token \
            --domain datavant --domain-owner 283241578630 --region us-east-1 \
            --query authorizationToken --output text)
        if test -z "$token"
            echo "login-npm: failed to retrieve CodeArtifact token" >&2
            return 1
        end
        pushd "$project_root" >/dev/null
        npm config set --location=project "//$ca_host/npm/npm/:_authToken" "$token"
        set -l rc $status
        popd >/dev/null
        if test $rc -eq 0
            echo "login-npm: refreshed token in $project_root/.npmrc"
        end
        return $rc
    else
        # Refresh only the @datavant-scoped registry's token in ~/.npmrc;
        # --namespace prevents `aws codeartifact login` from overwriting the default registry.
        AWS_PROFILE=prod aws codeartifact login --tool npm --namespace @datavant \
            --repository npm --domain datavant --domain-owner 283241578630 --region us-east-1
    end
end
