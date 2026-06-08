if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

export EDITOR=vim

export CODE_ROOT=$HOME/code
export CODEBASE_ROOT=${CODE_ROOT}/codebase
export CONNECT_ROOT=${CODE_ROOT}/connect
export IDSB_ROOT=${CODE_ROOT}/idsb


export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$PYENV_ROOT/shims:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

export PATH="$HOME/.local/bin:$PATH"

connect(){
    pushd $CONNECT_ROOT
}

idsb(){
    pushd $IDSB_ROOT
}

portal(){
    pushd $IDSB_ROOT/portal/idsb-portal
}

pconn(){
    pushd $IDSB_ROOT/provider_connections
}

db_copying(){
    pushd $IDSB_ROOT/worker_pod/scripts/db_copying
}

rcs(){
    pushd $IDSB_ROOT/worker_pod/src/retrieval-configurator
}

login-all(){
    connect 1>&2 /dev/null && make aws-auth-pip && popd
}

helm-login(){
    AWS_PROFILE=staging aws ecr get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin 164638511672.dkr.ecr-fips.us-east-1.amazonaws.com
}

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

[[ "$(uname -s)" == "Darwin" ]] && export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"

#########################
##### GIT COMMANDS
#########################
# gp() {
#     git push
# }

# gup() {
#     git fetch --prune
#     git pull -r --stat
# }

# gcob() {
#     if [ -z "$1" ]; then
#         echo "Usage: gcob <branch_name> [upstream_branch]"
#         return 1
#     fi
#     git checkout -b "$@"
# }

# gc() {
#     if [ -z "$1" ]; then
#         echo "Usage: gcm [commit_message]"
#         return 1
#     fi

#     if [ -n "$1" ]; then
#         git commit -m "$1"
#     else
#         git commit
#     fi
# }

gst() {
    git status -sb --show-stash
}

# glg() {
#     git log --oneline --graph --date=relative
# }

# glgg() {
#     git log --oneline --graph --date=relative --stat
# }

# glggg() {
#     git log --pretty=medium --abbrev-commit --graph --date=relative --stat
# }

# per-machine overrides
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
export NODE_EXTRA_CA_CERTS="/Users/Shared/ca-bundle.crt"
