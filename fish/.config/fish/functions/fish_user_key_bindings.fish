fish_vi_key_bindings

bind -M insert -m default ctrl-c backward-char force-repaint

bind -M insert ctrl-x,ctrl-x 'commandline -r ""' clear fish_prompt
bind -M default ctrl-x,ctrl-x 'commandline -r ""' clear fish_prompt

bind -M insert ctrl-x 'commandline -r ""'
bind -M default ctrl-x 'commandline -r ""'

bind --mode insert ctrl-space accept-autosuggestion
bind --mode default ctrl-space accept-autosuggestion
