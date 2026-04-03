if status is-interactive
    # Commands to run in interactive sessions can go here
end

alias opencode="$HOME/utveckling_git/opencode-docker/start-cli.sh ."

function ssh --wraps=ssh --description "ssh with temporary terminal background color"
    printf '\033]11;#8B4000\007'

    function __ssh_reset_bg --on-event fish_exit --inherit-variable status
        printf '\033]11;#232627\007'
        functions --erase __ssh_reset_bg 2>/dev/null
    end

    function __ssh_reset_bg_cancel --on-event fish_cancel
        printf '\033]11;#232627\007'
        functions --erase __ssh_reset_bg_cancel 2>/dev/null
    end

    command ssh $argv
    set -l exit_code $status

    printf '\033]11;#232627\007'

    functions --erase __ssh_reset_bg 2>/dev/null
    functions --erase __ssh_reset_bg_cancel 2>/dev/null

    return $exit_code
end

set -gx PNPM_HOME "$HOME/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end

set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"

fish_add_path ~/.local/bin

# pnpm
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
