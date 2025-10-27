if status is-interactive
    # Commands to run in interactive sessions can go here
    atuin init fish | source
    source $HOME/.local/bin/env.fish
    set -gx EDITOR hx
    source "$HOME/.cargo/env.fish"
end
fish_add_path /home/salman/.pixi/bin
