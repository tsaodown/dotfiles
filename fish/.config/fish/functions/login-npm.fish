function login-npm -d "Login to prod AWS ECR"
    AWS_PROFILE=prod aws codeartifact login --tool npm --repository npm --domain datavant --domain-owner 283241578630 --region us-east-1
end
