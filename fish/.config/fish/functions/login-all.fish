function login-all -d "Login to all DV AWS accounts & setup pip CodeArtifact"
    pushd ~/code/connect 1>&2 /dev/null && make aws-auth-pip && popd 1>&2
end
