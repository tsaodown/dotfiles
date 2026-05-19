function claude --description 'wrap claude code with a default session display name'
    # only set a default name if the user didn't already set one
    if not set --query CLAUDE_CODE_SESSION_NAME
        and not contains -- -n $argv
        and not contains -- --name $argv
        and not string match -q -- '--name=*' $argv
        set -lx CLAUDE_CODE_SESSION_NAME (basename (pwd))
    end
    command claude $argv
end
