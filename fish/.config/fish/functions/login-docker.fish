function login-docker -d "Setup docker ECR"
    set -l env staging  # default

    if test (count $argv) -ge 1
        set env (string lower $argv[1])
    end

    set -l registry ''
    switch $env
        case staging
            echo "🔐 Logging in staging Docker ECR"
            set registry 164638511672.dkr.ecr-fips.us-east-1.amazonaws.com
        case prod
            echo "🔐 Logging in prod Docker ECR"
            set registry 283241578630.dkr.ecr-fips.us-east-1.amazonaws.com
        case '*'
            echo "❌ Invalid environment: '$env'"
            echo "Usage: login-docker [staging|prod]"
            return 1
    end

    AWS_PROFILE=$env aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $registry
end
