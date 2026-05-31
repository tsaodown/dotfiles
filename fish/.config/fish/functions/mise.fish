# Lazy mise activation shim. As an autoloaded function this only *defines* the
# function at startup (no execution), so a box without the mise binary no longer
# errors with "command 'mise' not found" the way a bare top-level
# `eval $(mise activate fish)` did. On the first real `mise` call it erases
# itself, sources mise's activation (which redefines `mise`), then hands off.
function mise --wraps mise --description 'lazy mise activation'
    command -q mise; or return 0
    functions --erase mise
    command mise activate fish | source
    mise $argv
end
