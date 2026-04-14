# Legacy compatibility entrypoint for installs that still symlink this file.
# New installs keep ~/.config/fish/config.fish local and use tracked conf.d snippets.

source (status dirname)/conf.d/10-system-config-base.fish
source (status dirname)/conf.d/20-node-tools.fish

if test -f "$HOME/.config/fish/config.local.fish"
    source "$HOME/.config/fish/config.local.fish"
end
