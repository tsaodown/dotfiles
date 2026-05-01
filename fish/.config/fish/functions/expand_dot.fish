function expand_dot --description 'Expand repeated ... to ../.. etc.'
    set -l buffer (commandline --current-buffer)
    set -l cursor (commandline --cursor)
    
    # Insert the dot normally first
    commandline --insert .

    # Get new buffer after insertion
    set -l new_buffer (commandline --current-buffer)
    
    # Match trailing dots at the cursor
    if test (string match -r '\.*$' $new_buffer)
        set -l match (string match -r '\.*$' $new_buffer)
        set -l dotcount (string length -- $match)

        # Only expand when we have 3 or more dots
        if test $dotcount -ge 3
            set -l replacement (string repeat --count=(math $dotcount - 1) '../')
            # Remove trailing dots and replace with ../.. etc.
            set -l prefix (string sub --start 1 --length=(math (string length $new_buffer) - $dotcount) $new_buffer)
            commandline --replace "$prefix$replacement"
        end
    end
end

# Bind to . key in insert mode
bind . expand_dot
