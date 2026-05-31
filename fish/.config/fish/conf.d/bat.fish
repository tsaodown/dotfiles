# On Debian/Ubuntu apt installs bat's binary as `batcat` (name clash with
# bacula's bat). Alias bat→batcat only when the real `bat` is absent but
# `batcat` is present, so macOS (which ships the real `bat`) is untouched.
# `command -q` checks external commands only, so it isn't fooled by the
# function we define here.
if not command -q bat; and command -q batcat
    function bat --wraps batcat --description 'bat (Debian/Ubuntu batcat shim)'
        batcat $argv
    end
end
