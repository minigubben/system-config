set -gx FNM_DIR "$HOME/.local/share/fnm"
if not contains -- $FNM_DIR $PATH
    set -gx PATH "$FNM_DIR" $PATH
end

if test -x "$FNM_DIR/fnm"
    fnm env --use-on-cd --shell fish | source
end

set -gx PNPM_HOME "$HOME/.local/share/pnpm"
if not contains -- $PNPM_HOME $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end
